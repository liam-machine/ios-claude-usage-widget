import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "Claude Code-credentials"

    private init() {}

    func getOAuthToken() -> String? {
        // First try the environment variable
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"] {
            return envToken
        }

        // Then try the Keychain
        return getTokenFromKeychain()
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
        let data = token.data(using: .utf8)!

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
        return status == errSecSuccess
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
}
