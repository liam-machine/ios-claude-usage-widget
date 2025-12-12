import Foundation
import os.log

/// Service for managing OAuth tokens with expiry detection and automatic refresh
/// Uses file-based storage to avoid keychain prompts
class TokenService {
    static let shared = TokenService()

    private let logger = Logger(subsystem: "com.jamesdowzard.ClaudeUsageWidget", category: "TokenService")
    private let fileCredentials = FileCredentialService.shared

    // Anthropic OAuth configuration
    private static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    private static let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private init() {}

    /// Get a valid access token for an account, attempting refresh if expired
    func getValidToken(for account: Account) -> String? {
        // Use file-based credentials
        if let token = fileCredentials.getValidToken(forAccountId: account.id.uuidString) {
            return token
        }

        // Token expired or not found
        return nil
    }

    /// Asynchronously get a valid token, attempting refresh if expired
    func getValidTokenAsync(for account: Account) async -> String? {
        let accountId = account.id.uuidString

        // Check if we have a valid token
        if let token = fileCredentials.getValidToken(forAccountId: accountId) {
            return token
        }

        // Token expired - try to refresh
        if let storedRefreshToken = fileCredentials.getRefreshToken(forAccountId: accountId) {
            logger.info("Token expired for account \(account.name), attempting refresh...")
            if let newCredentials = await refreshToken(for: account, using: storedRefreshToken) {
                return newCredentials.accessToken
            }
            logger.warning("Token refresh failed for account \(account.name)")
        }

        return nil
    }

    /// Refresh the access token using the refresh token
    func refreshToken(for account: Account, using refreshToken: String) async -> OAuthCredentials? {
        logger.info("Refreshing token for account: \(account.name)")

        let parameters: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId
        ]

        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type during token refresh")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Token refresh failed with status \(httpResponse.statusCode): \(responseString)")
                }
                return nil
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                logger.error("Failed to parse token refresh response")
                return nil
            }

            // Get expiry - default to 1 hour if not provided
            let expiresIn = json["expires_in"] as? Int ?? 3600
            let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

            // Use new refresh token if provided, otherwise keep the old one
            let newRefreshToken = json["refresh_token"] as? String ?? refreshToken

            let newCredentials = OAuthCredentials(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                expiresAt: expiresAt
            )

            // Save updated credentials to file
            let saved = fileCredentials.updateAccountToken(
                accountId: account.id.uuidString,
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                expiresAt: expiresAt.timeIntervalSince1970
            )

            if saved {
                logger.info("Token refreshed successfully for account \(account.name), expires at \(expiresAt)")
            } else {
                logger.error("Failed to save refreshed credentials to file")
            }

            return newCredentials

        } catch {
            logger.error("Token refresh error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if token needs refresh (expired or expiring soon)
    func needsRefresh(for account: Account) -> Bool {
        return fileCredentials.isTokenExpired(forAccountId: account.id.uuidString)
    }

    /// Get the refresh token for an account (if available)
    func getRefreshToken(for account: Account) -> String? {
        return fileCredentials.getRefreshToken(forAccountId: account.id.uuidString)
    }

    /// Check if an account's token is expired or missing
    func isTokenExpiredOrMissing(for account: Account) -> Bool {
        let accountId = account.id.uuidString
        guard let storedAccount = fileCredentials.getAccount(byId: accountId) else {
            return true  // No credentials at all
        }
        return fileCredentials.isTokenExpired(forAccountId: accountId)
    }

    /// Get time until token expires (for display)
    func timeUntilExpiry(for account: Account) -> TimeInterval? {
        guard let storedAccount = fileCredentials.getAccount(byId: account.id.uuidString) else {
            return nil
        }
        let expiresAt = Date(timeIntervalSince1970: storedAccount.expiresAt)
        return expiresAt.timeIntervalSinceNow
    }

    /// Import credentials from Claude Code's keychain for the given account
    /// Note: This still uses keychain to READ from Claude Code, but saves to file
    func importFromClaudeCode(for account: Account) -> Bool {
        guard let credentials = KeychainService.shared.getClaudeCodeCredentials() else {
            return false
        }

        // Save to file-based storage
        let saved = fileCredentials.updateAccountToken(
            accountId: account.id.uuidString,
            accessToken: credentials.accessToken,
            refreshToken: credentials.refreshToken,
            expiresAt: credentials.expiresAt.timeIntervalSince1970
        )

        return saved
    }

    /// Format expiry time for display
    func expiryDescription(for account: Account) -> String? {
        guard let timeRemaining = timeUntilExpiry(for: account) else {
            return nil
        }

        if timeRemaining <= 0 {
            return "Expired"
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60

        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        } else {
            return "Expires in \(minutes)m"
        }
    }
}
