import SwiftUI

struct TeamDashboardView: View {
    let teamData: TeamUsageData?
    let isLoading: Bool
    let error: UsageError?
    let onRefresh: () -> Void
    let onSettings: () -> Void

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    var body: some View {
        VStack(spacing: 0) {
            if let error = error {
                errorView(error)
            } else if let data = teamData {
                teamUsageView(data)
            } else if isLoading {
                loadingView
            } else {
                emptyView
            }
        }
        .frame(width: 380)
        .background(retroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(retroBorder, lineWidth: 2)
        )
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

            Button("Retry") {
                onRefresh()
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(retroGray)
        }
        .padding()
    }

    private func teamUsageView(_ data: TeamUsageData) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Team Usage - Today")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(retroGray)
                Spacer()
                Button(action: onRefresh) {
                    Text("↻")
                        .font(.system(.body, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(retroGray)
                .accessibilityLabel("Refresh team usage data")

                Button(action: onSettings) {
                    Text("⚙")
                        .font(.system(.body, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(retroGray)
                .accessibilityLabel("Open settings")
            }
            .padding()

            Divider()
                .background(retroBorder)

            // Team Total
            HStack {
                Text("Team Total: \(data.formattedTotalTokens)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray)
                Spacer()
                Text(data.formattedTotalCost)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray)
            }
            .padding()

            Divider()
                .background(retroBorder)

            // Team Members
            ForEach(data.sortedMembers) { member in
                TeamMemberRow(member: member, teamTotal: data.totalTokens, color: retroGray)

                if member.id != data.sortedMembers.last?.id {
                    Divider()
                        .background(retroBorder)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(retroGray)

            Text("Loading team data...")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)
        }
        .padding(40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("No team data available")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray.opacity(0.7))
        }
        .padding(40)
    }
}

struct TeamMemberRow: View {
    let member: TeamMember
    let teamTotal: Int
    let color: Color

    private let totalBlocks = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name
            Text("👤 \(member.displayName)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
                .accessibilityLabel("Team member \(member.displayName)")

            // Stats
            HStack(spacing: 8) {
                Text("\(member.formattedTokens) tokens")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))

                Text("•")
                    .foregroundColor(color.opacity(0.5))

                Text("\(member.editCount) edits")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))

                Text("•")
                    .foregroundColor(color.opacity(0.5))

                Text("\(member.prCount) \(member.prCount == 1 ? "PR" : "PRs")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(member.formattedTokens) tokens, \(member.editCount) edits, \(member.prCount) pull requests")

            // Progress bar with percentage
            HStack(spacing: 4) {
                let filledBlocks = Int(Double(member.tokenCount) / Double(teamTotal) * Double(totalBlocks))

                ForEach(0..<totalBlocks, id: \.self) { index in
                    Rectangle()
                        .fill(index < filledBlocks ? color : color.opacity(0.2))
                        .frame(width: 10, height: 10)
                }

                Text("(\(member.percentageOfTeam(teamTotal))%)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color.opacity(0.6))
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(member.percentageOfTeam(teamTotal)) percent of team usage")
        }
        .padding()
    }
}

// MARK: - Data Models

struct TeamUsageData: Codable {
    let totalTokens: Int
    let totalCost: Double
    let members: [TeamMember]

    var formattedTotalTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000.0)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000.0)
        } else {
            return "\(totalTokens)"
        }
    }

    var formattedTotalCost: String {
        return String(format: "$%.2f", totalCost)
    }

    var sortedMembers: [TeamMember] {
        members.sorted { $0.tokenCount > $1.tokenCount }
    }
}

struct TeamMember: Codable, Identifiable {
    let id: String
    let email: String
    let tokenCount: Int
    let editCount: Int
    let prCount: Int

    var displayName: String {
        // Extract name from email (e.g., "dana.pavey@jhg.com.au" -> "Dana Pavey")
        let username = email.split(separator: "@").first ?? ""
        let nameParts = username.split(separator: ".")
        return nameParts
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var formattedTokens: String {
        if tokenCount >= 1_000_000 {
            return String(format: "%.0fK", Double(tokenCount) / 1_000.0)
        } else if tokenCount >= 1_000 {
            return String(format: "%.0fK", Double(tokenCount) / 1_000.0)
        } else {
            return "\(tokenCount)"
        }
    }

    func percentageOfTeam(_ teamTotal: Int) -> Int {
        guard teamTotal > 0 else { return 0 }
        return Int((Double(tokenCount) / Double(teamTotal)) * 100.0)
    }
}

#Preview {
    // Sample data for preview
    let sampleData = TeamUsageData(
        totalTokens: 2_400_000,
        totalCost: 45.23,
        members: [
            TeamMember(id: "1", email: "dana.pavey@jhg.com.au", tokenCount: 523_000, editCount: 45, prCount: 4),
            TeamMember(id: "2", email: "liam.wynne@jhg.com.au", tokenCount: 412_000, editCount: 32, prCount: 2),
            TeamMember(id: "3", email: "james.dowzard@jhg.com.au", tokenCount: 289_000, editCount: 28, prCount: 1),
            TeamMember(id: "4", email: "juan.avilamolina@jhg.com.au", tokenCount: 856_000, editCount: 67, prCount: 8),
            TeamMember(id: "5", email: "anna.kravtsova@jhg.com.au", tokenCount: 320_000, editCount: 25, prCount: 3)
        ]
    )

    TeamDashboardView(
        teamData: sampleData,
        isLoading: false,
        error: nil,
        onRefresh: {},
        onSettings: {}
    )
}
