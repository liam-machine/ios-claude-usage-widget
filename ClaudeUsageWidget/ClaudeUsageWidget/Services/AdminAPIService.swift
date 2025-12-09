import Foundation
import os.log

class AdminAPIService {
    static let shared = AdminAPIService()

    // MARK: - Constants
    private static let apiVersion = "2023-06-01"

    private static var baseURL: URL {
        guard let url = URL(string: "https://api.anthropic.com/v1/organizations/usage_report/claude_code") else {
            fatalError("Invalid admin API URL")
        }
        return url
    }

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.jamesdowzard.ClaudeUsageWidget", category: "AdminAPIService")
    private let keychainService = KeychainService.shared

    private init() {}

    // MARK: - Admin API Key Management

    func hasValidAdminKey() -> Bool {
        return keychainService.getAdminAPIKey() != nil
    }

    func setAdminKey(_ key: String) -> Bool {
        return keychainService.saveAdminAPIKey(key)
    }

    func deleteAdminKey() {
        keychainService.deleteAdminAPIKey()
    }

    // MARK: - Fetch Team Usage

    /// Fetch team usage for a specific date
    func fetchTeamUsage(for date: Date) async throws -> AdminTeamUsageResponse {
        guard let adminKey = keychainService.getAdminAPIKey() else {
            throw AdminAPIError.keyNotFound
        }

        let dateString = formatDate(date)
        var allMembers: [TeamMemberUsage] = []
        var nextPage: String? = nil

        repeat {
            let response = try await fetchPage(startingAt: dateString, page: nextPage, adminKey: adminKey)
            allMembers.append(contentsOf: response.data)
            nextPage = response.hasMore ? response.page : nil
        } while nextPage != nil

        return AdminTeamUsageResponse(data: allMembers, hasMore: false, page: nil)
    }

    /// Fetch team usage for a date range
    func fetchTeamUsageRange(from startDate: Date, to endDate: Date) async throws -> [TeamMemberUsage] {
        guard let adminKey = keychainService.getAdminAPIKey() else {
            throw AdminAPIError.keyNotFound
        }

        var allMembers: [String: TeamMemberUsage] = [:]
        var currentDate = startDate

        // Fetch data for each day in the range
        while currentDate <= endDate {
            let dateString = formatDate(currentDate)
            var nextPage: String? = nil

            repeat {
                let response = try await fetchPage(startingAt: dateString, page: nextPage, adminKey: adminKey)

                // Aggregate usage by member email
                for member in response.data {
                    if var existing = allMembers[member.memberEmail] {
                        // Aggregate usage across days
                        existing.requestsCount += member.requestsCount
                        existing.inputTokensCount += member.inputTokensCount
                        existing.outputTokensCount += member.outputTokensCount
                        allMembers[member.memberEmail] = existing
                    } else {
                        allMembers[member.memberEmail] = member
                    }
                }

                nextPage = response.hasMore ? response.page : nil
            } while nextPage != nil

            // Move to next day
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
        }

        return Array(allMembers.values).sorted { $0.memberEmail < $1.memberEmail }
    }

    // MARK: - Private Methods

    private func fetchPage(startingAt: String, page: String?, adminKey: String, limit: Int = 1000) async throws -> AdminTeamUsageResponse {
        var urlComponents = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!

        var queryItems = [
            URLQueryItem(name: "starting_at", value: startingAt),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let page = page {
            queryItems.append(URLQueryItem(name: "page", value: page))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw AdminAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger.info("Fetching team usage: starting_at=\(startingAt), page=\(page ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let teamResponse = try decoder.decode(AdminTeamUsageResponse.self, from: data)
                logger.info("Fetched \(teamResponse.data.count) team members for \(startingAt)")
                return teamResponse
            } catch {
                logger.error("Decoding error: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response data: \(responseString)")
                }
                throw AdminAPIError.decodingError(error)
            }
        case 401:
            throw AdminAPIError.unauthorized
        case 403:
            throw AdminAPIError.forbidden
        case 429:
            throw AdminAPIError.rateLimited
        default:
            logger.error("HTTP Status: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "nil"
            logger.error("Response: \(responseString)")
            throw AdminAPIError.httpError(httpResponse.statusCode, responseString)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Models

struct AdminTeamUsageResponse: Codable {
    let data: [TeamMemberUsage]
    let hasMore: Bool
    let page: String?
}

struct TeamMemberUsage: Codable {
    let memberEmail: String
    var requestsCount: Int
    var inputTokensCount: Int
    var outputTokensCount: Int

    var totalTokens: Int {
        inputTokensCount + outputTokensCount
    }
}

// MARK: - Errors

enum AdminAPIError: LocalizedError {
    case keyNotFound
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case forbidden
    case rateLimited
    case httpError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "Admin API key not found - please configure in settings"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Admin API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - invalid API key"
        case .forbidden:
            return "Forbidden - insufficient permissions"
        case .rateLimited:
            return "Rate limit exceeded - try again later"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
