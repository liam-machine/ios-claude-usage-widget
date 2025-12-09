import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var settings = AppSettings.shared
    @State private var showingSetup = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel, settings: settings)
                .onAppear {
                    // Show setup if not completed
                    showingSetup = !settings.hasCompletedSetup
                }
                .sheet(isPresented: $showingSetup) {
                    SetupView(settings: settings)
                        .onDisappear {
                            // Refresh data after setup completes
                            if settings.hasCompletedSetup {
                                viewModel.refresh()
                            }
                        }
                }
        } label: {
            MenuBarLabel(viewModel: viewModel, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            Image("ClaudeIcon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
            Text(usageText)
                .font(.system(.body, design: .monospaced))
        }
        .foregroundColor(.primary)
    }

    private var usageText: String {
        // Show team data in menu bar when in team mode (or team view in both mode)
        if settings.mode == .team || (settings.mode == .both && settings.showTeamView) {
            guard let teamData = viewModel.teamUsageData else {
                return "—"
            }
            return teamData.formattedTotalTokens
        } else {
            // Personal usage
            guard let usage = viewModel.usageData?.fiveHour else {
                return "—%"
            }
            return "\(Int(usage.utilization))%"
        }
    }
}
