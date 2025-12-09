import Foundation
import Security
import os.log

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "Claude Code-credentials"
    private let logger = OSLog(subsystem: "com.jamesdowzard.ClaudeUsageWidget", category: "KeychainService")

    private init() {}

    // MARK: - Claude Code Keychain Access

    func getOAuthToken() -> String? {
        // First try the environment variable
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"] {
            return envToken
        }

        // Then try the Keychain
        return getTokenFromKeychain()
    }

    /// Get full OAuth credentials from Claude Code's keychain
    func getClaudeCodeCredentials() -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let claudeAiOauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = claudeAiOauth["accessToken"] as? String,
              let refreshToken = claudeAiOauth["refreshToken"] as? String,
              let expiresAt = claudeAiOauth["expiresAt"] as? Int64 else {
            return nil
        }

        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAtMs: expiresAt)
    }

    private func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        // Try to parse as JSON first (Claude Code stores credentials as JSON)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try claudeAiOauth.accessToken (current format)
            if let claudeAiOauth = json["claudeAiOauth"] as? [String: Any],
               let accessToken = claudeAiOauth["accessToken"] as? String {
                return accessToken
            }
            // Try oauth_token (legacy format)
            if let token = json["oauth_token"] as? String {
                return token
            }
        }

        // Fall back to treating it as a plain string
        return String(data: data, encoding: .utf8)
    }

    func saveManualToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else {
            os_log("Failed to encode token as UTF-8 data", log: logger, type: .error)
            return false
        }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClaudeUsageWidget-token"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClaudeUsageWidget-token",
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            os_log("Failed to save manual token to keychain: %{public}d", log: logger, type: .error, status)
            return false
        }
        return true
    }

    func getManualToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClaudeUsageWidget-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteManualToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ClaudeUsageWidget-token"
        ]
        SecItemDelete(query as CFDictionary)
    }

    func getEffectiveToken() -> String? {
        // Priority: Manual token > Environment variable > Keychain
        if let manualToken = getManualToken(), !manualToken.isEmpty {
            return manualToken
        }
        return getOAuthToken()
    }

    // MARK: - Multi-Account Token Management (Single Keychain Item)

    private let allTokensServiceName = "ClaudeUsageWidget-tokens"
    private let allCredentialsServiceName = "ClaudeUsageWidget-credentials"

    private func getAllTokens() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allTokensServiceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let tokens = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return tokens
    }

    private func saveAllTokens(_ tokens: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(tokens) else {
            os_log("Failed to encode tokens dictionary to JSON", log: logger, type: .error)
            return false
        }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allTokensServiceName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allTokensServiceName,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            os_log("Failed to save tokens to keychain: %{public}d", log: logger, type: .error, status)
            return false
        }
        return true
    }

    func saveToken(_ token: String, forAccountId accountId: String) -> Bool {
        var tokens = getAllTokens()
        tokens[accountId] = token
        return saveAllTokens(tokens)
    }

    func getToken(forAccountId accountId: String) -> String? {
        let tokens = getAllTokens()
        return tokens[accountId]
    }

    func deleteToken(forAccountId accountId: String) {
        var tokens = getAllTokens()
        tokens.removeValue(forKey: accountId)
        _ = saveAllTokens(tokens)
    }

    // MARK: - Full Credentials Management (with refresh tokens)

    private func getAllCredentials() -> [String: OAuthCredentials] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allCredentialsServiceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode([String: OAuthCredentials].self, from: data) else {
            return [:]
        }

        return credentials
    }

    private func saveAllCredentials(_ credentials: [String: OAuthCredentials]) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else {
            os_log("Failed to encode credentials dictionary to JSON", log: logger, type: .error)
            return false
        }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allCredentialsServiceName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: allCredentialsServiceName,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            os_log("Failed to save credentials to keychain: %{public}d", log: logger, type: .error, status)
            return false
        }
        return true
    }

    func saveCredentials(_ credentials: OAuthCredentials, forAccountId accountId: String) -> Bool {
        var allCreds = getAllCredentials()
        allCreds[accountId] = credentials
        return saveAllCredentials(allCreds)
    }

    func getCredentials(forAccountId accountId: String) -> OAuthCredentials? {
        let allCreds = getAllCredentials()
        return allCreds[accountId]
    }

    func updateAccessToken(_ accessToken: String, expiresAt: Date, forAccountId accountId: String) -> Bool {
        var allCreds = getAllCredentials()
        guard var creds = allCreds[accountId] else { return false }
        creds.accessToken = accessToken
        creds.expiresAt = expiresAt
        allCreds[accountId] = creds
        return saveAllCredentials(allCreds)
    }

    func deleteCredentials(forAccountId accountId: String) {
        var allCreds = getAllCredentials()
        allCreds.removeValue(forKey: accountId)
        _ = saveAllCredentials(allCreds)
        // Also clean up legacy token storage
        deleteToken(forAccountId: accountId)
    }
}
