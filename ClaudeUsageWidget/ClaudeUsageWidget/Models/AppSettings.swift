import Foundation
import SwiftUI

enum UsageMode: String, CaseIterable, Codable {
    case personal = "personal"
    case team = "team"
    case both = "both"

    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .team: return "Team Dashboard"
        case .both: return "Both"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "👤"
        case .team: return "👥"
        case .both: return "🔄"
        }
    }

    var description: String {
        switch self {
        case .personal:
            return "Track your own Claude Code usage"
        case .team:
            return "Track your organization's usage"
        case .both:
            return "Toggle between personal & team"
        }
    }

    var details: String {
        switch self {
        case .personal:
            return "• Auto-imports from Claude Code"
        case .team:
            return "• Requires Admin API key"
        case .both:
            return ""
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("usageMode") var mode: UsageMode = .personal
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("showTeamView") var showTeamView: Bool = false  // for "both" mode toggle
    @AppStorage("adminApiKey") private var adminApiKeyStorage: String = ""

    private init() {}

    // Secure storage for Admin API key (should use Keychain in production)
    var adminApiKey: String {
        get { adminApiKeyStorage }
        set { adminApiKeyStorage = newValue }
    }

    var hasAdminKey: Bool {
        !adminApiKey.isEmpty
    }

    func clearAdminKey() {
        adminApiKey = ""
    }

    func completeSetup(mode: UsageMode, adminKey: String? = nil) {
        self.mode = mode
        if let key = adminKey {
            self.adminApiKey = key
        }
        self.hasCompletedSetup = true
    }

    func resetSetup() {
        hasCompletedSetup = false
        mode = .personal
        showTeamView = false
        clearAdminKey()
    }
}
