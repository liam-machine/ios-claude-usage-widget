import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: AppSettings
    @State private var showingSettings = false
    @State private var showingTokenInput = false
    @State private var manualToken = ""
    @State private var newAccountName = ""
    @State private var newAccountIcon = "🏠"

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    var body: some View {
        VStack(spacing: 0) {
            // Show appropriate view based on mode
            if shouldShowTeamView {
                teamView
            } else {
                personalView
            }
        }
        .frame(width: shouldShowTeamView ? 380 : 280)
        .background(retroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(retroBorder, lineWidth: 2)
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingTokenInput) {
            tokenInputSheet
        }
    }

    // Determine which view to show
    private var shouldShowTeamView: Bool {
        switch settings.mode {
        case .personal:
            return false
        case .team:
            return true
        case .both:
            return settings.showTeamView
        }
    }

    // MARK: - Team View

    private var teamView: some View {
        VStack(spacing: 0) {
            // Mode toggle header (for both mode)
            if settings.mode == .both {
                modeToggleHeader
            }

            TeamDashboardView(
                teamData: viewModel.teamUsageData,
                isLoading: viewModel.isLoadingTeam,
                error: viewModel.teamError,
                onRefresh: { viewModel.refreshTeam() },
                onSettings: { showingSettings = true }
            )
        }
    }

    // MARK: - Personal View

    private var personalView: some View {
        VStack(spacing: 0) {
            if viewModel.accountManager.accounts.isEmpty {
                onboardingView
            } else if !viewModel.hasToken {
                tokenRequiredView
            } else if let error = viewModel.error {
                errorView(error)
            } else if let usage = viewModel.usageData {
                usageView(usage)
            } else if viewModel.isLoading {
                loadingView
            } else {
                emptyView
            }
        }
    }

    // MARK: - Mode Toggle Header

    private var modeToggleHeader: some View {
        HStack {
            Text("View:")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.6))

            Menu {
                Button(action: {
                    settings.showTeamView = false
                    viewModel.refresh()
                }) {
                    HStack {
                        Text("👤 Personal")
                        if !settings.showTeamView {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button(action: {
                    settings.showTeamView = true
                    viewModel.refreshTeam()
                }) {
                    HStack {
                        Text("👥 Team")
                        if settings.showTeamView {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(settings.showTeamView ? "👥 Team" : "👤 Personal")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(retroGray)
                    Text("▾")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(retroBorder.opacity(0.3))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Toggle between personal and team view")

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("×")
                    .font(.system(.body, design: .monospaced))
            }
            .buttonStyle(.plain)
            .foregroundColor(retroGray)
            .accessibilityLabel("Quit application")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(retroBackground)
        .overlay(
            Rectangle()
                .fill(retroBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var tokenRequiredView: some View {
        VStack(spacing: 12) {
            // Account toggle (only show if there are accounts)
            if !viewModel.accountManager.accounts.isEmpty {
                accountToggle
            }

            Text("[ TOKEN REQUIRED ]")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.orange)

            Text("No token for \(viewModel.currentAccountName)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)

            Text("Enter token from 'claude' CLI")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Enter Token") {
                    showingTokenInput = true
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(retroGray)

                Button("Import from Claude") {
                    _ = viewModel.importCredentialsFromClaudeCode()
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.7))
            }
        }
        .padding()
    }

    private func errorView(_ error: UsageError) -> some View {
        VStack(spacing: 12) {
            // Account toggle (only show if there are multiple accounts)
            if viewModel.accountManager.accounts.count > 1 {
                accountToggle
            }

            Text("[ ERROR ]")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.red)

            Text(error.localizedDescription)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack {
                Button("Retry") {
                    viewModel.refresh()
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(retroGray)

                // Show import button for errors that require re-authentication
                if error.requiresReimport {
                    Button("Import from Claude") {
                        _ = viewModel.importCredentialsFromClaudeCode()
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.7))
                }
            }

            if error.requiresReimport {
                Text("Log into this account in Claude CLI, then click Import")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func usageView(_ usage: UsageData) -> some View {
        VStack(spacing: 0) {
            // Header with account selector
            HStack {
                Text("Claude Code Usage")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)
                Spacer()
                // Account toggle (only show if there are multiple accounts)
                if viewModel.accountManager.accounts.count > 1 {
                    accountToggle
                }
            }
            .padding()

            Divider()
                .background(retroBorder)

            // 5-Hour Limit
            RetroUsageRow(
                title: "5-Hour Limit",
                percentage: Int(usage.fiveHour.utilization),
                subtitle: "Resets in \(usage.fiveHour.timeUntilReset)",
                color: retroGray
            )

            Divider()
                .background(retroBorder)

            // 7-Day Limit
            RetroUsageRow(
                title: "7-Day Limit",
                percentage: Int(usage.sevenDay.utilization),
                subtitle: "Resets in \(usage.sevenDay.daysHoursUntilReset) (\(usage.sevenDay.resetDayTime12hr))",
                color: retroGray
            )

            Divider()
                .background(retroBorder)

            // Footer
            VStack(spacing: 4) {
                HStack {
                    Text("Last updated: \(viewModel.lastUpdatedText)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))

                    Spacer()

                    Button(action: { viewModel.refresh() }) {
                        Text("↻ Refresh")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(retroGray)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh usage data")
                    .accessibilityHint("Fetches the latest usage statistics from Claude API")

                    Button(action: { showingSettings = true }) {
                        Text("⚙ Settings")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(retroGray)
                    .accessibilityLabel("Open settings")
                    .accessibilityHint("Opens the settings panel to manage accounts and preferences")

                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Text("×")
                            .font(.system(.body, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(retroGray)
                    .accessibilityLabel("Quit application")
                    .accessibilityHint("Closes the Claude Usage Widget application")
                }

                // Token expiry info
                if let expiryText = viewModel.tokenExpiryDescription {
                    HStack {
                        Text("Token: \(expiryText)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(expiryText == "Expired" ? .red : retroGray.opacity(0.5))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Text("Loading...")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)
        }
        .padding(40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("No data available")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
        }
        .padding(40)
    }

    private var onboardingView: some View {
        VStack(spacing: 16) {
            Text("[ WELCOME ]")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(retroGray)

            Text("Claude Code Usage Widget")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.8))

            Text("Add your first account to get started")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.6))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("Account Name", text: $newAccountName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 4) {
                    ForEach(Account.suggestedIcons.prefix(5), id: \.self) { icon in
                        Button(action: {
                            newAccountIcon = icon
                        }) {
                            Text(icon)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .background(newAccountIcon == icon ? retroGray : retroBorder.opacity(0.3))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Add Account") {
                    if !newAccountName.isEmpty {
                        let account = viewModel.accountManager.addAccount(name: newAccountName, icon: newAccountIcon)
                        viewModel.accountManager.completeOnboarding()
                        viewModel.selectAccount(account)
                        newAccountName = ""
                        newAccountIcon = "🏠"
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(newAccountName.isEmpty ? retroGray.opacity(0.5) : retroGray)
                .disabled(newAccountName.isEmpty)

                Button("Quick Setup") {
                    // Add common Personal/Work accounts
                    let personal = viewModel.accountManager.addAccount(name: "Personal", icon: "🏠")
                    _ = viewModel.accountManager.addAccount(name: "Work", icon: "💼")
                    viewModel.accountManager.completeOnboarding()
                    viewModel.selectAccount(personal)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.7))
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
                    .font(.system(.caption, design: .monospaced))
            }
            .buttonStyle(.plain)
            .foregroundColor(retroGray.opacity(0.6))
        }
        .padding()
    }

    private var accountToggle: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.accountManager.accounts) { account in
                Button(action: {
                    viewModel.selectAccount(account)
                }) {
                    Text(account.icon)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(account.id == viewModel.selectedAccount?.id ? retroGray : retroBorder.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help(account.name)
                .accessibilityLabel("Switch to \(account.name)")
                .accessibilityHint("Switches the active Claude account to view usage data")
            }
        }
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(retroBorder, lineWidth: 1))
    }

    private var tokenInputSheet: some View {
        VStack(spacing: 16) {
            Text("Enter OAuth Token")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(retroGray)

            Text("For account: \(viewModel.currentAccountName)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)

            Text("Run 'claude logout' then 'claude login' to get a new token")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
                .multilineTextAlignment(.center)

            SecureField("OAuth Token", text: $manualToken)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack {
                Button("Cancel") {
                    manualToken = ""
                    showingTokenInput = false
                }

                Button("Save") {
                    if !manualToken.isEmpty, let account = viewModel.selectedAccount {
                        viewModel.accountManager.updateToken(for: account, token: manualToken)
                        manualToken = ""
                        showingTokenInput = false
                        viewModel.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualToken.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .background(retroBackground)
    }
}

struct RetroUsageRow: View {
    let title: String
    let percentage: Int
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(color)
                Spacer()
                Text("\(percentage)%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(color)
            }

            // ASCII-style progress bar
            RetroProgressBar(percentage: percentage, color: color)

            Text(subtitle)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(color.opacity(0.6))
        }
        .padding()
    }
}

struct RetroProgressBar: View {
    let percentage: Int
    let color: Color

    private let totalBlocks = 20

    var body: some View {
        HStack(spacing: 2) {
            let filledBlocks = Int(Double(percentage) / 100.0 * Double(totalBlocks))

            ForEach(0..<totalBlocks, id: \.self) { index in
                Rectangle()
                    .fill(index < filledBlocks ? color : color.opacity(0.2))
                    .frame(width: 10, height: 14)
            }
        }
    }
}

#Preview {
    MenuBarView(viewModel: UsageViewModel(), settings: AppSettings.shared)
}
