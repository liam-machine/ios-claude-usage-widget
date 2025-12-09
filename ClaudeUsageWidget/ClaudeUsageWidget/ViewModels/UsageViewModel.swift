import Foundation
import Combine
import SwiftUI

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
    }

    func fetchUsage() async {
        isLoading = true
        error = nil

        // Get token for selected account
        let token: String?
        if let account = selectedAccount {
            token = accountManager.getToken(for: account)
        } else {
            token = nil
        }

        do {
            usageData = try await apiService.fetchUsage(withToken: token)
            lastUpdated = Date()
        } catch let usageError as UsageError {
            error = usageError
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
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
            self?.refresh()
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
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: lastUpdated)
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
