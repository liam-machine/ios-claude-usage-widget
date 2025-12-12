import Foundation
import os.log

/// Service for managing OAuth tokens with expiry detection and automatic refresh
class TokenService {
    static let shared = TokenService()

    private let logger = Logger(subsystem: "com.jamesdowzard.ClaudeUsageWidget", category: "TokenService")

    // Anthropic OAuth configuration
    private static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    private static let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private init() {}

    /// Get a valid access token for an account, attempting refresh if expired
    func getValidToken(for account: Account) -> String? {
        // First check if we have full credentials with expiry info
        if let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) {
            if !credentials.isExpired {
                return credentials.accessToken
            }
            // Token expired - don't return nil yet, let caller handle async refresh
            return nil
        }

        // Fall back to legacy token storage (no expiry info)
        return AccountManager.shared.getToken(for: account)
    }

    /// Asynchronously get a valid token, attempting refresh if expired
    func getValidTokenAsync(for account: Account) async -> String? {
        if let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) {
            if !credentials.isExpired {
                return credentials.accessToken
            }

            // Token expired - try to refresh
            logger.info("Token expired for account \(account.name), attempting refresh...")
            if let newCredentials = await refreshToken(for: account, using: credentials.refreshToken) {
                return newCredentials.accessToken
            }

            // Refresh failed
            logger.warning("Token refresh failed for account \(account.name)")
            return nil
        }

        // Fall back to legacy token storage (no expiry info)
        return AccountManager.shared.getToken(for: account)
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

            // Save updated credentials
            let saved = KeychainService.shared.saveCredentials(newCredentials, forAccountId: account.id.uuidString)
            if saved {
                logger.info("Token refreshed successfully for account \(account.name), expires at \(expiresAt)")
                // Also update legacy token storage
                AccountManager.shared.updateToken(for: account, token: accessToken)
            } else {
                logger.error("Failed to save refreshed credentials to keychain")
            }

            return newCredentials

        } catch {
            logger.error("Token refresh error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if token needs refresh (expired or expiring soon)
    func needsRefresh(for account: Account) -> Bool {
        guard let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) else {
            return false // No credentials to refresh
        }
        return credentials.isExpired
    }

    /// Get the refresh token for an account (if available)
    func getRefreshToken(for account: Account) -> String? {
        return KeychainService.shared.getCredentials(forAccountId: account.id.uuidString)?.refreshToken
    }

    /// Check if an account's token is expired or missing
    func isTokenExpiredOrMissing(for account: Account) -> Bool {
        if let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) {
            return credentials.isExpired
        }
        // No credentials stored - check if we have a legacy token
        return AccountManager.shared.getToken(for: account) == nil
    }

    /// Get time until token expires (for display)
    func timeUntilExpiry(for account: Account) -> TimeInterval? {
        guard let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) else {
            return nil
        }
        return credentials.expiresAt.timeIntervalSinceNow
    }

    /// Import credentials from Claude Code's keychain for the given account
    func importFromClaudeCode(for account: Account) -> Bool {
        guard let credentials = KeychainService.shared.getClaudeCodeCredentials() else {
            return false
        }

        // Save full credentials
        let saved = KeychainService.shared.saveCredentials(credentials, forAccountId: account.id.uuidString)

        // Also update legacy token storage for backwards compatibility
        if saved {
            AccountManager.shared.updateToken(for: account, token: credentials.accessToken)
        }

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
