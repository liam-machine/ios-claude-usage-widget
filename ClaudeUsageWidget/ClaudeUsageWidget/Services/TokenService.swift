import Foundation

/// Service for managing OAuth tokens with expiry detection
class TokenService {
    static let shared = TokenService()

    private init() {}

    /// Get a valid access token for an account, checking expiry first
    func getValidToken(for account: Account) -> String? {
        // First check if we have full credentials with expiry info
        if let credentials = KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) {
            if !credentials.isExpired {
                return credentials.accessToken
            }
            // Token expired - return nil so UI can prompt for re-import
            return nil
        }

        // Fall back to legacy token storage (no expiry info)
        return AccountManager.shared.getToken(for: account)
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
