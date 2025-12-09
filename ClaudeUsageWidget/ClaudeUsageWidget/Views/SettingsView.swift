import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingTokenInput = false
    @State private var showingAccountEditor = false
    @State private var showingAddAccount = false
    @State private var manualToken = ""
    @State private var editingAccount: Account?
    @State private var editName = ""
    @State private var editIcon = ""
    @State private var showDeleteConfirmation = false
    @State private var accountToDelete: Account?

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section {
                    ForEach(viewModel.accountManager.accounts) { account in
                        HStack {
                            Text(account.icon)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(account.name)
                                    .fontWeight(.medium)
                                if viewModel.accountManager.getToken(for: account) != nil {
                                    Text("Token configured")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("No token")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            if account.id == viewModel.selectedAccount?.id {
                                Image(systemName: "checkmark.circle.fill")
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
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectAccount(account)
                        }
                    }

                    Button(action: {
                        editName = ""
                        editIcon = Account.suggestedIcons.first ?? "👤"
                        showingAddAccount = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Account")
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Accounts")
                } footer: {
                    Text("Click an account to select it. Use the menu to edit or delete.")
                        .font(.caption)
                }

                Section {
                    Picker("Refresh Interval", selection: $viewModel.refreshInterval) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .onChange(of: viewModel.refreshInterval) { newValue in
                        viewModel.updateRefreshInterval(newValue)
                    }
                } header: {
                    Text("Auto-Refresh")
                }

                Section {
                    Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                        .onChange(of: viewModel.launchAtLogin) { newValue in
                            setLaunchAtLogin(newValue)
                        }
                } header: {
                    Text("Startup")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 400, height: 550)
        .sheet(isPresented: $showingTokenInput) {
            tokenInputSheet
        }
        .sheet(isPresented: $showingAccountEditor) {
            accountEditorSheet
        }
        .sheet(isPresented: $showingAddAccount) {
            addAccountSheet
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation, presenting: accountToDelete) { account in
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.accountManager.removeAccount(account)
                accountToDelete = nil
                viewModel.refresh()
            }
        } message: { account in
            Text("Are you sure you want to delete \"\(account.name)\"? This will also remove its stored token.")
        }
    }

    private var tokenInputSheet: some View {
        let accountName = editingAccount?.name ?? viewModel.currentAccountName
        return VStack(spacing: 16) {
            Text("Enter OAuth Token")
                .font(.headline)

            Text("For account: \(accountName)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Get your token by running 'claude setup-token' in the terminal.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("OAuth Token", text: $manualToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    manualToken = ""
                    editingAccount = nil
                    showingTokenInput = false
                }

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
                .buttonStyle(.borderedProminent)
                .disabled(manualToken.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private var accountEditorSheet: some View {
        VStack(spacing: 16) {
            Text("Edit Account")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Account Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                iconPicker
            }

            HStack {
                Button("Cancel") {
                    editingAccount = nil
                    showingAccountEditor = false
                }

                Button("Save") {
                    if !editName.isEmpty, let account = editingAccount {
                        viewModel.accountManager.updateAccount(account, name: editName, icon: editIcon)
                        editingAccount = nil
                        showingAccountEditor = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private var addAccountSheet: some View {
        VStack(spacing: 16) {
            Text("Add Account")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Account Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                iconPicker
            }

            HStack {
                Button("Cancel") {
                    showingAddAccount = false
                }

                Button("Add") {
                    if !editName.isEmpty {
                        let account = viewModel.accountManager.addAccount(name: editName, icon: editIcon)
                        viewModel.selectAccount(account)
                        showingAddAccount = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
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
                        .background(editIcon == icon ? Color.accentColor.opacity(0.3) : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
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
    SettingsView(viewModel: UsageViewModel())
}
