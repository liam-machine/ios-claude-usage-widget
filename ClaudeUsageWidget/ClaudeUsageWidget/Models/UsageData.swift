import Foundation

struct UsageData: Codable {
    let fiveHour: UsagePeriod
    let sevenDay: UsagePeriod
    let sevenDayOpus: UsagePeriod?
    let sevenDaySonnet: UsagePeriod?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

struct UsagePeriod: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        guard let resetsAt = resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var timeUntilReset: String {
        guard let resetDate = resetDate else { return "Unknown" }

        let now = Date()
        let interval = resetDate.timeIntervalSince(now)

        if interval <= 0 {
            return "Resetting..."
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var resetDateFormatted: String {
        guard let resetDate = resetDate else { return "Unknown" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: resetDate)
    }

    var resetDayTime12hr: String {
        guard let resetDate = resetDate else { return "Unknown" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mma"
        return formatter.string(from: resetDate).lowercased()
    }

    var daysHoursUntilReset: String {
        guard let resetDate = resetDate else { return "Unknown" }

        let now = Date()
        let interval = resetDate.timeIntervalSince(now)

        if interval <= 0 {
            return "Resetting..."
        }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            return "\(hours)h"
        }
    }

    var utilizationPercentage: Int {
        Int(utilization)
    }
}

enum UsageError: LocalizedError {
    case tokenNotFound
    case tokenExpired
    case invalidResponse
    case networkError(Error)
    case unauthorized
    case insufficientScope

    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "No token configured for this account"
        case .tokenExpired:
            return "Token expired and refresh failed - click Import to re-authenticate"
        case .invalidResponse:
            return "Invalid response from API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - token may have expired"
        case .insufficientScope:
            return "Token missing required scope. Run 'claude setup-token' in Terminal to generate a new token with usage access."
        }
    }

    var requiresReimport: Bool {
        switch self {
        case .tokenNotFound, .tokenExpired, .unauthorized:
            return true
        default:
            return false
        }
    }
}
