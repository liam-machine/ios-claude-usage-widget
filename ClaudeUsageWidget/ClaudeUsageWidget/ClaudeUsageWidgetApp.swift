import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

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
        guard let usage = viewModel.usageData?.fiveHour else {
            return "—%"
        }
        return "\(Int(usage.utilization))%"
    }
}
