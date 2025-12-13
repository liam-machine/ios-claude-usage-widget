import Foundation

// MARK: - OAuth Credentials

struct OAuthCredentials: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    var isExpired: Bool {
        // Consider expired 5 minutes before actual expiry for safety
        return Date() >= expiresAt.addingTimeInterval(-300)
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    // Initialize from Claude Code keychain format (expiresAt is milliseconds since epoch)
    init(accessToken: String, refreshToken: String, expiresAtMs: Int64) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = Date(timeIntervalSince1970: Double(expiresAtMs) / 1000.0)
    }
}

// MARK: - Account

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String  // Emoji icon for the account
    var token: String  // Legacy - kept for backwards compatibility

    init(id: UUID = UUID(), name: String, icon: String = "👤", token: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.token = token
    }

    // Suggested icons for common account types
    static let suggestedIcons = ["🏠", "💼", "🎮", "🔬", "📚", "🎨", "💻", "🚀", "⭐", "🌙"]
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()

    private let fileCredentials = FileCredentialService.shared

    @Published var accounts: [Account] = []
    @Published var selectedAccountId: UUID?

    var selectedAccount: Account? {
        guard let id = selectedAccountId else { return accounts.first }
        return accounts.first { $0.id == id }
    }

    // Always completed if we have accounts in file
    var hasCompletedOnboarding: Bool {
        return !accounts.isEmpty
    }

    var needsOnboarding: Bool {
        return accounts.isEmpty
    }

    private init() {
        loadAccounts()
    }

    func loadAccounts() {
        // Load from file-based credentials
        let storedAccounts = fileCredentials.getAllAccounts()
        accounts = storedAccounts.map { stored in
            Account(
                id: UUID(uuidString: stored.id) ?? UUID(),
                name: stored.name,
                icon: stored.icon,
                token: ""  // Tokens are managed separately in file
            )
        }

        // Load selected account
        if let selectedId = fileCredentials.getSelectedAccountId(),
           let uuid = UUID(uuidString: selectedId) {
            selectedAccountId = uuid
        } else {
            selectedAccountId = accounts.first?.id
        }
    }

    func saveAccounts() {
        // Accounts are saved via FileCredentialService
        // This is called for compatibility but actual saving happens in add/remove/update methods
    }

    func completeOnboarding() {
        // No-op - onboarding is complete when accounts exist
    }

    func selectAccount(_ account: Account) {
        selectedAccountId = account.id
        fileCredentials.setSelectedAccountId(account.id.uuidString)
        objectWillChange.send()
    }

    // MARK: - Account CRUD Operations

    @discardableResult
    func addAccount(name: String, icon: String = "👤") -> Account {
        // Add to file storage with empty credentials (will need import)
        let stored = fileCredentials.addAccount(
            name: name,
            icon: icon,
            accessToken: "",
            refreshToken: "",
            expiresAt: 0
        )

        let account = Account(
            id: UUID(uuidString: stored.id) ?? UUID(),
            name: name,
            icon: icon
        )
        accounts.append(account)

        // Select the new account if it's the first one
        if accounts.count == 1 {
            selectAccount(account)
        }

        objectWillChange.send()
        return account
    }

    func removeAccount(_ account: Account) {
        // Remove from file storage
        fileCredentials.removeAccount(byId: account.id.uuidString)

        // Remove from list
        accounts.removeAll { $0.id == account.id }

        // If we deleted the selected account, select another
        if selectedAccountId == account.id {
            selectedAccountId = accounts.first?.id
            if let id = selectedAccountId {
                fileCredentials.setSelectedAccountId(id.uuidString)
            }
        }

        objectWillChange.send()
    }

    func updateAccount(_ account: Account, name: String? = nil, icon: String? = nil) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            if let name = name {
                accounts[index].name = name
            }
            if let icon = icon {
                accounts[index].icon = icon
            }
            // Persist to file storage
            _ = fileCredentials.updateAccountInfo(
                accountId: account.id.uuidString,
                name: name,
                icon: icon
            )
            objectWillChange.send()
        }
    }

    func updateToken(for account: Account, token: String) {
        // Tokens are managed by FileCredentialService, not here
        // This method is kept for compatibility but does nothing
    }

    func getToken(for account: Account) -> String? {
        // Use file-based credentials
        return fileCredentials.getValidToken(forAccountId: account.id.uuidString)
    }

    // Legacy method for backwards compatibility
    func renameAccount(_ account: Account, to newName: String) {
        updateAccount(account, name: newName)
    }
}
