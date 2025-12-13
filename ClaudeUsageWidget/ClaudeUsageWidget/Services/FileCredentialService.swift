import Foundation
import os.log

/// File-based credential storage - no keychain prompts
class FileCredentialService {
    static let shared = FileCredentialService()

    private let logger = Logger(subsystem: "com.liamwynne.ClaudeUsageWidget", category: "FileCredentialService")
    private let configDir: URL
    private let credentialsFile: URL

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDir = homeDir.appendingPathComponent(".config/claude-usage-widget")
        credentialsFile = configDir.appendingPathComponent("credentials.json")

        // Ensure config directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    // MARK: - Data Structures

    struct StoredCredentials: Codable {
        var accounts: [StoredAccount]
        var selectedAccountId: String?
    }

    struct StoredAccount: Codable {
        var id: String
        var name: String
        var icon: String
        var accessToken: String
        var refreshToken: String
        var expiresAt: Double  // Unix timestamp in seconds
    }

    // MARK: - Read/Write

    func loadCredentials() -> StoredCredentials? {
        guard FileManager.default.fileExists(atPath: credentialsFile.path) else {
            logger.info("No credentials file found at \(self.credentialsFile.path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: credentialsFile)
            let credentials = try JSONDecoder().decode(StoredCredentials.self, from: data)
            logger.info("Loaded \(credentials.accounts.count) accounts from file")
            return credentials
        } catch {
            logger.error("Failed to load credentials: \(error.localizedDescription)")
            return nil
        }
    }

    func saveCredentials(_ credentials: StoredCredentials) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(credentials)
            try data.write(to: credentialsFile, options: .atomic)

            // Set restrictive permissions (owner read/write only)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsFile.path)

            logger.info("Saved \(credentials.accounts.count) accounts to file")
            return true
        } catch {
            logger.error("Failed to save credentials: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Account Operations

    func getAccount(byId id: String) -> StoredAccount? {
        return loadCredentials()?.accounts.first { $0.id == id }
    }

    func getAllAccounts() -> [StoredAccount] {
        return loadCredentials()?.accounts ?? []
    }

    func getSelectedAccountId() -> String? {
        return loadCredentials()?.selectedAccountId
    }

    func setSelectedAccountId(_ id: String) {
        guard var credentials = loadCredentials() else { return }
        credentials.selectedAccountId = id
        _ = saveCredentials(credentials)
    }

    func updateAccountToken(accountId: String, accessToken: String, refreshToken: String, expiresAt: Double) -> Bool {
        guard var credentials = loadCredentials() else { return false }

        if let index = credentials.accounts.firstIndex(where: { $0.id == accountId }) {
            credentials.accounts[index].accessToken = accessToken
            credentials.accounts[index].refreshToken = refreshToken
            credentials.accounts[index].expiresAt = expiresAt
            return saveCredentials(credentials)
        }
        return false
    }

    func updateAccountInfo(accountId: String, name: String?, icon: String?) -> Bool {
        guard var credentials = loadCredentials() else { return false }

        if let index = credentials.accounts.firstIndex(where: { $0.id == accountId }) {
            if let name = name {
                credentials.accounts[index].name = name
            }
            if let icon = icon {
                credentials.accounts[index].icon = icon
            }
            return saveCredentials(credentials)
        }
        return false
    }

    func addAccount(name: String, icon: String, accessToken: String, refreshToken: String, expiresAt: Double) -> StoredAccount {
        var credentials = loadCredentials() ?? StoredCredentials(accounts: [], selectedAccountId: nil)

        let newAccount = StoredAccount(
            id: UUID().uuidString.uppercased(),
            name: name,
            icon: icon,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )

        credentials.accounts.append(newAccount)
        if credentials.selectedAccountId == nil {
            credentials.selectedAccountId = newAccount.id
        }

        _ = saveCredentials(credentials)
        return newAccount
    }

    func removeAccount(byId id: String) {
        guard var credentials = loadCredentials() else { return }
        credentials.accounts.removeAll { $0.id == id }
        if credentials.selectedAccountId == id {
            credentials.selectedAccountId = credentials.accounts.first?.id
        }
        _ = saveCredentials(credentials)
    }

    // MARK: - Token Helpers

    func getValidToken(forAccountId id: String) -> String? {
        guard let account = getAccount(byId: id) else { return nil }

        // Check if token is expired (with 5 min buffer)
        let now = Date().timeIntervalSince1970
        if account.expiresAt < now + 300 {
            return nil  // Token expired or expiring soon
        }

        return account.accessToken
    }

    func isTokenExpired(forAccountId id: String) -> Bool {
        guard let account = getAccount(byId: id) else { return true }
        let now = Date().timeIntervalSince1970
        return account.expiresAt < now + 300
    }

    func getRefreshToken(forAccountId id: String) -> String? {
        return getAccount(byId: id)?.refreshToken
    }

    // MARK: - Import from Claude Code

    func importFromClaudeCodeConfig() -> Bool {
        // Try to read from Claude Code's config file location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let claudeConfigPath = homeDir.appendingPathComponent(".claude/credentials.json")

        // Claude Code primarily uses keychain, but we can try file-based fallback
        // For now, return false - user should use the refresh mechanism
        return false
    }
}
