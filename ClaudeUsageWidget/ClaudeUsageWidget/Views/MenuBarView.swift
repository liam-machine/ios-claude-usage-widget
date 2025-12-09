import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showingSettings = false
    @State private var showingTokenInput = false
    @State private var manualToken = ""

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.hasToken {
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
        .frame(width: 280)
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

    private var tokenRequiredView: some View {
        VStack(spacing: 12) {
            Text("[ ERROR ]")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.red)

            Text("OAuth Token Required")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)

            Text("Run 'claude logout' then 'claude login' in terminal")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Enter Token Manually") {
                showingTokenInput = true
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(retroGray)
        }
        .padding()
    }

    private func errorView(_ error: UsageError) -> some View {
        VStack(spacing: 12) {
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

                if case .unauthorized = error {
                    Button("Update Token") {
                        showingTokenInput = true
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(retroGray)
                }
            }
        }
        .padding()
    }

    private func usageView(_ usage: UsageData) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Claude Code Usage")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)
                Spacer()
                Image("LiamIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(retroGray.opacity(0.5), lineWidth: 1))
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

                Button(action: { showingSettings = true }) {
                    Text("⚙ Settings")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(retroGray)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("×")
                        .font(.system(.body, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(retroGray)
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

    private var tokenInputSheet: some View {
        VStack(spacing: 16) {
            Text("Enter OAuth Token")
                .font(.system(.headline, design: .monospaced))
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
    MenuBarView(viewModel: UsageViewModel())
}
