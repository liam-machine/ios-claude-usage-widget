import SwiftUI

struct UsageProgressView: View {
    let title: String
    let usage: UsagePeriod
    let showTimeUntilReset: Bool

    init(title: String, usage: UsagePeriod, showTimeUntilReset: Bool = true) {
        self.title = title
        self.usage = usage
        self.showTimeUntilReset = showTimeUntilReset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(usage.utilizationPercentage)%")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
            }

            ProgressView(value: usage.utilization, total: 100)
                .progressViewStyle(UsageProgressStyle(color: progressColor))

            HStack {
                if showTimeUntilReset {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Resets in \(usage.timeUntilReset)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Resets \(usage.resetDateFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var progressColor: Color {
        let percentage = usage.utilization
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct UsageProgressStyle: ProgressViewStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0), height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    UsageProgressView(
        title: "5-Hour Limit",
        usage: UsagePeriod(utilization: 45, resetsAt: "2024-12-09T18:00:00Z")
    )
    .frame(width: 280)
    .padding()
}
