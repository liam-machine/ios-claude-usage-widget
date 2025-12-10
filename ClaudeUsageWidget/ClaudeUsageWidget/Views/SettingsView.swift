import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    var onClose: () -> Void

    @State private var showingTokenInput = false
    @State private var showingAccountEditor = false
    @State private var showingAddAccount = false
    @State private var manualToken = ""
    @State private var editingAccount: Account?
    @State private var editName = ""
    @State private var editIcon = ""
    @State private var showDeleteConfirmation = false
    @State private var accountToDelete: Account?

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    // Calculate dynamic height based on number of accounts
    private var dynamicHeight: CGFloat {
        let baseHeight: CGFloat = 240 // Header + Startup + padding + back button (removed Refresh section)
        let accountRowHeight: CGFloat = 52 // Height per account row
        let addButtonHeight: CGFloat = 44 // Add Account button
        let sectionHeaderFooterHeight: CGFloat = 60 // Section header + footer
        let accountCount = max(viewModel.accountManager.accounts.count, 1)

        let accountsHeight = CGFloat(accountCount) * accountRowHeight + addButtonHeight + sectionHeaderFooterHeight
        let totalHeight = baseHeight + accountsHeight

        // Clamp between min and max heights
        return min(max(totalHeight, 300), 550)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        Text("←")
                        Text("Back")
                    }
                    .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(retroGray)

                Spacer()

                Text("Settings")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)

                Spacer()

                // Invisible spacer to center title
                HStack(spacing: 4) {
                    Text("←")
                    Text("Back")
                }
                .font(.system(.caption, design: .monospaced))
                .opacity(0)
            }
            .padding()
            .background(retroBackground)
            .overlay(
                Rectangle()
                    .fill(retroBorder)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    // Accounts Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACCOUNTS")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(retroGray.opacity(0.6))
                            .padding(.horizontal, 4)

                        VStack(spacing: 1) {
                            ForEach(viewModel.accountManager.accounts) { account in
                                accountRow(account)
                            }

                            // Add Account button
                            Button(action: {
                                editName = ""
                                editIcon = Account.suggestedIcons.first ?? "👤"
                                showingAddAccount = true
                            }) {
                                HStack {
                                    Text("+")
                                        .font(.system(.title3, design: .monospaced))
                                        .foregroundColor(.green)
                                    Text("Add Account")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(retroGray)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(retroBorder.opacity(0.2))
                            }
                            .buttonStyle(.plain)
                        }
                        .background(retroBorder.opacity(0.3))
                        .cornerRadius(8)

                        Text("Click an account to select it. Use ••• to edit or delete.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(retroGray.opacity(0.5))
                            .padding(.horizontal, 4)
                    }

                    // Startup Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STARTUP")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(retroGray.opacity(0.6))
                            .padding(.horizontal, 4)

                        HStack {
                            Text("Launch at Login")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(retroGray)
                            Spacer()
                            Toggle("", isOn: $viewModel.launchAtLogin)
                                .toggleStyle(.switch)
                                .onChange(of: viewModel.launchAtLogin) { newValue in
                                    setLaunchAtLogin(newValue)
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(retroBorder.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 350, height: dynamicHeight)
        .background(retroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(retroBorder, lineWidth: 2)
        )
        .overlay {
            // Token Input Overlay
            if showingTokenInput {
                tokenInputOverlay
            }

            // Account Editor Overlay
            if showingAccountEditor {
                accountEditorOverlay
            }

            // Add Account Overlay
            if showingAddAccount {
                addAccountOverlay
            }

            // Delete Confirmation Overlay (replaces .alert() which breaks in MenuBarExtra)
            if showDeleteConfirmation, let account = accountToDelete {
                deleteConfirmationOverlay(account)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showingTokenInput)
        .animation(.easeInOut(duration: 0.15), value: showingAccountEditor)
        .animation(.easeInOut(duration: 0.15), value: showingAddAccount)
        .animation(.easeInOut(duration: 0.15), value: showDeleteConfirmation)
    }

    // MARK: - Account Row

    private func accountRow(_ account: Account) -> some View {
        HStack {
            Text(account.icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray)

                if viewModel.accountManager.getToken(for: account) != nil {
                    Text("Token configured")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green)
                } else {
                    Text("No token")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if account.id == viewModel.selectedAccount?.id {
                Text("✓")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
            }

            Menu {
                Button("Edit Account") {
                    editingAccount = account
                    editName = account.name
                    editIcon = account.icon
                    showingAccountEditor = true
                }
                Button("Update Token") {
                    editingAccount = account
                    showingTokenInput = true
                }
                Divider()
                Button("Delete", role: .destructive) {
                    accountToDelete = account
                    showDeleteConfirmation = true
                }
            } label: {
                Text("•••")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(account.id == viewModel.selectedAccount?.id ? retroBorder.opacity(0.4) : retroBorder.opacity(0.2))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectAccount(account)
        }
    }

    // MARK: - Overlays

    private var tokenInputOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .onTapGesture {
                    manualToken = ""
                    editingAccount = nil
                    showingTokenInput = false
                }

            VStack(spacing: 16) {
                Text("Enter OAuth Token")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)

                Text("For: \(editingAccount?.name ?? viewModel.currentAccountName)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.7))

                SecureField("OAuth Token", text: $manualToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Button("Cancel") {
                        manualToken = ""
                        editingAccount = nil
                        showingTokenInput = false
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(retroGray.opacity(0.5))

                    Button("Save") {
                        if !manualToken.isEmpty {
                            let targetAccount = editingAccount ?? viewModel.selectedAccount
                            if let account = targetAccount {
                                viewModel.accountManager.updateToken(for: account, token: manualToken)
                            }
                            manualToken = ""
                            editingAccount = nil
                            showingTokenInput = false
                            viewModel.refresh()
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(manualToken.isEmpty ? retroGray.opacity(0.3) : retroGray)
                    .disabled(manualToken.isEmpty)
                }
            }
            .padding(20)
            .background(retroBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(retroBorder, lineWidth: 2)
            )
            .padding(20)
        }
    }

    private var accountEditorOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .onTapGesture {
                    editingAccount = nil
                    showingAccountEditor = false
                }

            VStack(spacing: 16) {
                Text("Edit Account")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))
                    TextField("Account Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))
                    iconPicker
                }

                HStack {
                    Button("Cancel") {
                        editingAccount = nil
                        showingAccountEditor = false
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(retroGray.opacity(0.5))

                    Button("Save") {
                        if !editName.isEmpty, let account = editingAccount {
                            viewModel.accountManager.updateAccount(account, name: editName, icon: editIcon)
                            editingAccount = nil
                            showingAccountEditor = false
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(editName.isEmpty ? retroGray.opacity(0.3) : retroGray)
                    .disabled(editName.isEmpty)
                }
            }
            .padding(20)
            .background(retroBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(retroBorder, lineWidth: 2)
            )
            .padding(20)
        }
    }

    private var addAccountOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .onTapGesture {
                    showingAddAccount = false
                }

            VStack(spacing: 16) {
                Text("Add Account")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))
                    TextField("Account Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.6))
                    iconPicker
                }

                HStack {
                    Button("Cancel") {
                        showingAddAccount = false
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(retroGray.opacity(0.5))

                    Button("Add") {
                        if !editName.isEmpty {
                            let account = viewModel.accountManager.addAccount(name: editName, icon: editIcon)
                            viewModel.selectAccount(account)
                            showingAddAccount = false
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(editName.isEmpty ? retroGray.opacity(0.3) : retroGray)
                    .disabled(editName.isEmpty)
                }
            }
            .padding(20)
            .background(retroBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(retroBorder, lineWidth: 2)
            )
            .padding(20)
        }
    }

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 5), spacing: 8) {
            ForEach(Account.suggestedIcons, id: \.self) { icon in
                Button(action: {
                    editIcon = icon
                }) {
                    Text(icon)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .background(editIcon == icon ? retroGray.opacity(0.5) : retroBorder.opacity(0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Delete Confirmation Overlay

    private func deleteConfirmationOverlay(_ account: Account) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .onTapGesture {
                    // Dismiss on background tap
                    accountToDelete = nil
                    showDeleteConfirmation = false
                }

            VStack(spacing: 16) {
                // Warning icon
                Text("⚠️")
                    .font(.system(size: 40))

                Text("Delete Account?")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)

                Text("Are you sure you want to delete \"\(account.name)\"?")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.8))
                    .multilineTextAlignment(.center)

                Text("This will also remove its stored token.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.6))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        accountToDelete = nil
                        showDeleteConfirmation = false
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(retroGray.opacity(0.5))
                    .cornerRadius(4)

                    Button("Delete") {
                        viewModel.accountManager.removeAccount(account)
                        accountToDelete = nil
                        showDeleteConfirmation = false
                        viewModel.refresh()
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(4)
                }
            }
            .padding(24)
            .background(retroBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(retroBorder, lineWidth: 2)
            )
            .padding(20)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}

#Preview {
    SettingsView(viewModel: UsageViewModel(), onClose: {})
}
