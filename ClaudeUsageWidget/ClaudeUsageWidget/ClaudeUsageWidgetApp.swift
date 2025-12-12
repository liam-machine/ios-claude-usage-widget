import SwiftUI
import AppKit

@main
struct ClaudeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - all UI is managed by AppDelegate's NSPopover
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: UsageViewModel!
    private var settings: AppSettings!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize view model and settings
        viewModel = UsageViewModel()
        settings = AppSettings.shared

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusButton(button)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true

        // Set the SwiftUI content
        let contentView = MenuBarView(viewModel: viewModel, settings: settings)
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Setup timer to update status bar
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatusBar()
        }

        // Monitor for clicks outside to close popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func updateStatusBar() {
        Task { @MainActor in
            if let button = statusItem.button {
                updateStatusButton(button)
            }
        }
    }

    @MainActor
    private func updateStatusButton(_ button: NSStatusBarButton) {
        // Update icon
        if let image = NSImage(named: "ClaudeIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            button.image = image
        }

        // Update text
        let usageText: String
        if settings.mode == .team || (settings.mode == .both && settings.showTeamView) {
            usageText = viewModel.teamUsageData?.formattedTotalTokens ?? "—"
        } else {
            // Show both session (5hr) and weekly (7day) usage
            if let data = viewModel.usageData {
                let session = Int(data.fiveHour.utilization)
                let weekly = Int(data.sevenDay.utilization)
                usageText = "\(session)% · \(weekly)%"
            } else {
                usageText = "—% · —%"
            }
        }

        button.title = " \(usageText)"
        button.imagePosition = .imageLeft
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Refresh content before showing
                let contentView = MenuBarView(viewModel: viewModel, settings: settings)
                popover.contentViewController = NSHostingController(rootView: contentView)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Keep app active to prevent dismissal during interactions
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return false
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
            // Personal usage - show session and weekly
            guard let data = viewModel.usageData else {
                return "—% · —%"
            }
            let session = Int(data.fiveHour.utilization)
            let weekly = Int(data.sevenDay.utilization)
            return "\(session)% · \(weekly)%"
        }
    }
}
