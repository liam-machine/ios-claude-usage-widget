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

    private let accountsKey = "ClaudeUsageWidget-accounts"
    private let selectedAccountKey = "ClaudeUsageWidget-selectedAccount"
    private let hasCompletedOnboardingKey = "ClaudeUsageWidget-hasCompletedOnboarding"

    @Published var accounts: [Account] = []
    @Published var selectedAccountId: UUID?
    @Published var hasCompletedOnboarding: Bool = false

    var selectedAccount: Account? {
        guard let id = selectedAccountId else { return accounts.first }
        return accounts.first { $0.id == id }
    }

    var needsOnboarding: Bool {
        return !hasCompletedOnboarding && accounts.isEmpty
    }

    private init() {
        loadAccounts()
    }

    func loadAccounts() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)

        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            // Migration: add default icon if missing (for accounts created before icon support)
            accounts = decoded.map { account in
                if account.icon.isEmpty {
                    var updated = account
                    updated.icon = "👤"
                    return updated
                }
                return account
            }
        } else {
            // No accounts - don't create defaults, let user set up via onboarding
            accounts = []
        }

        if let idString = UserDefaults.standard.string(forKey: selectedAccountKey),
           let id = UUID(uuidString: idString) {
            selectedAccountId = id
        } else {
            selectedAccountId = accounts.first?.id
        }
    }

    func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }

    func selectAccount(_ account: Account) {
        selectedAccountId = account.id
        UserDefaults.standard.set(account.id.uuidString, forKey: selectedAccountKey)
        objectWillChange.send()
    }

    // MARK: - Account CRUD Operations

    @discardableResult
    func addAccount(name: String, icon: String = "👤") -> Account {
        let account = Account(name: name, icon: icon)
        accounts.append(account)
        saveAccounts()

        // Select the new account if it's the first one
        if accounts.count == 1 {
            selectAccount(account)
        }

        return account
    }

    func removeAccount(_ account: Account) {
        // Delete token from keychain
        KeychainService.shared.deleteToken(forAccountId: account.id.uuidString)

        // Remove from list
        accounts.removeAll { $0.id == account.id }
        saveAccounts()

        // If we deleted the selected account, select another
        if selectedAccountId == account.id {
            selectedAccountId = accounts.first?.id
            if let id = selectedAccountId {
                UserDefaults.standard.set(id.uuidString, forKey: selectedAccountKey)
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
            saveAccounts()
            objectWillChange.send()
        }
    }

    func updateToken(for account: Account, token: String) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].token = token
            saveAccounts()
            // Also save to keychain for security
            _ = KeychainService.shared.saveToken(token, forAccountId: account.id.uuidString)
        }
    }

    func getToken(for account: Account) -> String? {
        // First try keychain (more secure)
        if let token = KeychainService.shared.getToken(forAccountId: account.id.uuidString), !token.isEmpty {
            return token
        }
        // Fall back to stored token
        if let stored = accounts.first(where: { $0.id == account.id })?.token, !stored.isEmpty {
            return stored
        }
        return nil
    }

    // Legacy method for backwards compatibility
    func renameAccount(_ account: Account, to newName: String) {
        updateAccount(account, name: newName)
    }
}
