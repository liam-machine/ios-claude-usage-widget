import Foundation
import Combine
import SwiftUI
import AppKit

@MainActor
class UsageViewModel: ObservableObject {
    @Published var usageData: UsageData?
    @Published var isLoading = false
    @Published var error: UsageError?
    @Published var lastUpdated: Date?

    // Multi-account support
    @Published var accountManager = AccountManager.shared
    @Published var selectedAccount: Account?

    @AppStorage("refreshInterval") var refreshInterval: Int = 5 // minutes
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    private var refreshTimer: Timer?
    private let apiService = UsageAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    // Static DateFormatter to avoid creating it repeatedly
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        selectedAccount = accountManager.selectedAccount
        startAutoRefresh()
        Task {
            await fetchUsage()
        }

        // Listen for account changes
        accountManager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.selectedAccount = self?.accountManager.selectedAccount
            }
        }.store(in: &cancellables)

        // Setup app lifecycle observers for App Nap handling
        setupAppLifecycleObservers()
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        Task { @MainActor in
            startAutoRefresh()
        }
    }

    @objc private func appWillResignActive() {
        Task { @MainActor in
            stopAutoRefresh()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchUsage() async {
        isLoading = true
        error = nil

        guard let account = selectedAccount else {
            error = .tokenNotFound
            isLoading = false
            return
        }

        do {
            usageData = try await apiService.fetchUsage(for: account)
            lastUpdated = Date()
        } catch let usageError as UsageError {
            error = usageError
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    /// Import credentials from Claude Code for the selected account
    func importCredentialsFromClaudeCode() -> Bool {
        guard let account = selectedAccount else { return false }
        let success = TokenService.shared.importFromClaudeCode(for: account)
        if success {
            refresh()
        }
        return success
    }

    /// Get expiry description for current account
    var tokenExpiryDescription: String? {
        guard let account = selectedAccount else { return nil }
        return TokenService.shared.expiryDescription(for: account)
    }

    func selectAccount(_ account: Account) {
        accountManager.selectAccount(account)
        selectedAccount = account
        refresh()
    }

    func refresh() {
        Task {
            await fetchUsage()
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()

        let interval = TimeInterval(refreshInterval * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func updateRefreshInterval(_ minutes: Int) {
        refreshInterval = minutes
        startAutoRefresh()
    }

    var lastUpdatedText: String {
        guard let lastUpdated = lastUpdated else {
            return "Never"
        }

        let interval = Date().timeIntervalSince(lastUpdated)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else {
            return Self.timeFormatter.string(from: lastUpdated)
        }
    }

    var statusColor: Color {
        guard let usage = usageData?.fiveHour else {
            return .secondary
        }

        let percentage = usage.utilization
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .yellow
        } else {
            return .red
        }
    }

    var hasToken: Bool {
        if let account = selectedAccount {
            return accountManager.getToken(for: account) != nil
        }
        return KeychainService.shared.getEffectiveToken() != nil
    }

    var currentAccountName: String {
        selectedAccount?.name ?? "Unknown"
    }
}
