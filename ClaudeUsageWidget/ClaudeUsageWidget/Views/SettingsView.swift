import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingTokenInput = false
    @State private var manualToken = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
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

                Section {
                    HStack {
                        Text("Token Status")
                        Spacer()
                        if viewModel.hasToken {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not Found", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }

                    Button("Update Token") {
                        showingTokenInput = true
                    }

                    if KeychainService.shared.getManualToken() != nil {
                        Button("Clear Manual Token", role: .destructive) {
                            KeychainService.shared.deleteManualToken()
                            viewModel.refresh()
                        }
                    }
                } header: {
                    Text("Authentication")
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
        .frame(width: 350, height: 380)
        .sheet(isPresented: $showingTokenInput) {
            tokenInputSheet
        }
    }

    private var tokenInputSheet: some View {
        VStack(spacing: 16) {
            Text("Enter OAuth Token")
                .font(.headline)

            Text("Get your token by running 'claude setup-token' in the terminal.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("OAuth Token", text: $manualToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    manualToken = ""
                    showingTokenInput = false
                }

                Button("Save") {
                    if !manualToken.isEmpty {
                        _ = KeychainService.shared.saveManualToken(manualToken)
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
        .frame(width: 300)
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
