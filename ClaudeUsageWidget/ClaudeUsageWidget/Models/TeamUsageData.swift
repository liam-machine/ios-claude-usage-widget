import Foundation

// MARK: - Team Usage Response

struct TeamUsageResponse: Codable {
    let data: [TeamUsageRecord]
    let hasMore: Bool
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

// MARK: - Team Usage Record

struct TeamUsageRecord: Codable, Identifiable {
    let id = UUID()
    let date: String
    let actor: Actor
    let organizationId: String
    let customerType: String
    let terminalType: String?
    let coreMetrics: CoreMetrics
    let toolActions: ToolActions
    let modelBreakdown: [ModelBreakdown]

    enum CodingKeys: String, CodingKey {
        case date
        case actor
        case organizationId = "organization_id"
        case customerType = "customer_type"
        case terminalType = "terminal_type"
        case coreMetrics = "core_metrics"
        case toolActions = "tool_actions"
        case modelBreakdown = "model_breakdown"
    }

    // MARK: - Computed Properties

    var displayName: String {
        let email = actor.emailAddress
        return email.components(separatedBy: "@").first ?? email
    }

    var totalTokens: Int {
        modelBreakdown.reduce(0) { total, model in
            total + model.tokens.totalTokens
        }
    }

    var totalCostInDollars: Double {
        let totalCents = modelBreakdown.reduce(0) { total, model in
            total + model.estimatedCost.amount
        }
        return Double(totalCents) / 100.0
    }

    var acceptanceRate: Double {
        let totalAccepted = toolActions.allAccepted
        let totalRejected = toolActions.allRejected
        let total = totalAccepted + totalRejected

        guard total > 0 else { return 0.0 }
        return Double(totalAccepted) / Double(total)
    }

    var acceptancePercentage: Int {
        Int(acceptanceRate * 100)
    }

    var recordDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: date) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: date)
    }

    var recordDateFormatted: String {
        guard let date = recordDate else { return date }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Actor

struct Actor: Codable {
    let type: String
    let emailAddress: String

    enum CodingKeys: String, CodingKey {
        case type
        case emailAddress = "email_address"
    }
}

// MARK: - Core Metrics

struct CoreMetrics: Codable {
    let numSessions: Int
    let linesOfCode: LinesOfCode
    let commitsByClaude: Int
    let pullRequestsByClaude: Int

    enum CodingKeys: String, CodingKey {
        case numSessions = "num_sessions"
        case linesOfCode = "lines_of_code"
        case commitsByClaude = "commits_by_claude_code"
        case pullRequestsByClaude = "pull_requests_by_claude_code"
    }
}

// MARK: - Lines of Code

struct LinesOfCode: Codable {
    let added: Int
    let removed: Int

    var net: Int {
        added - removed
    }
}

// MARK: - Tool Actions

struct ToolActions: Codable {
    let editTool: ToolMetrics
    let multiEditTool: ToolMetrics
    let writeTool: ToolMetrics
    let notebookEditTool: ToolMetrics

    enum CodingKeys: String, CodingKey {
        case editTool = "edit_tool"
        case multiEditTool = "multi_edit_tool"
        case writeTool = "write_tool"
        case notebookEditTool = "notebook_edit_tool"
    }

    // MARK: - Computed Properties

    var allAccepted: Int {
        editTool.accepted + multiEditTool.accepted + writeTool.accepted + notebookEditTool.accepted
    }

    var allRejected: Int {
        editTool.rejected + multiEditTool.rejected + writeTool.rejected + notebookEditTool.rejected
    }

    var totalActions: Int {
        allAccepted + allRejected
    }
}

// MARK: - Tool Metrics

struct ToolMetrics: Codable {
    let accepted: Int
    let rejected: Int

    var total: Int {
        accepted + rejected
    }

    var acceptanceRate: Double {
        guard total > 0 else { return 0.0 }
        return Double(accepted) / Double(total)
    }

    var acceptancePercentage: Int {
        Int(acceptanceRate * 100)
    }
}

// MARK: - Model Breakdown

struct ModelBreakdown: Codable {
    let model: String
    let tokens: TokenMetrics
    let estimatedCost: CostMetrics

    enum CodingKeys: String, CodingKey {
        case model
        case tokens
        case estimatedCost = "estimated_cost"
    }
}

// MARK: - Token Metrics

struct TokenMetrics: Codable {
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheCreation: Int

    enum CodingKeys: String, CodingKey {
        case input
        case output
        case cacheRead = "cache_read"
        case cacheCreation = "cache_creation"
    }

    var totalTokens: Int {
        input + output + cacheRead + cacheCreation
    }

    var cacheHitRate: Double {
        let allTokens = totalTokens
        guard allTokens > 0 else { return 0.0 }
        return Double(cacheRead) / Double(allTokens)
    }

    var cacheHitPercentage: Int {
        Int(cacheHitRate * 100)
    }
}

// MARK: - Cost Metrics

struct CostMetrics: Codable {
    let currency: String
    let amount: Int  // Amount in cents

    var amountInDollars: Double {
        Double(amount) / 100.0
    }
}
