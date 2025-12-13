import Foundation
import os.log

class UsageAPIService {
    static let shared = UsageAPIService()

    // MARK: - Constants
    private static let apiVersion = "oauth-2025-04-20"
    private static let userAgent = "claude-code/2.0.31"

    private static var usageURL: URL {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            fatalError("Invalid usage URL")
        }
        return url
    }

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.jamesdowzard.ClaudeUsageWidget", category: "UsageAPIService")
    private let keychainService = KeychainService.shared

    private init() {}

    /// Fetch usage for a specific account (preferred method)
    /// Automatically attempts to refresh expired tokens
    func fetchUsage(for account: Account) async throws -> UsageData {
        // Use async token service that attempts refresh if expired
        guard let token = await TokenService.shared.getValidTokenAsync(for: account) else {
            // Token refresh failed or no credentials - check why
            if TokenService.shared.isTokenExpiredOrMissing(for: account) {
                if KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) != nil {
                    // Had credentials but refresh failed
                    throw UsageError.tokenExpired
                }
            }
            throw UsageError.tokenNotFound
        }

        return try await fetchUsageWithToken(token)
    }

    func fetchUsage(withToken token: String? = nil) async throws -> UsageData {
        guard let effectiveToken = token ?? keychainService.getEffectiveToken() else {
            throw UsageError.tokenNotFound
        }
        return try await fetchUsageWithToken(effectiveToken)
    }

    private func fetchUsageWithToken(_ token: String) async throws -> UsageData {

        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(UsageData.self, from: data)
            } catch {
                logger.error("Decoding error: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response data: \(responseString)")
                }
                throw UsageError.invalidResponse
            }
        case 401:
            throw UsageError.unauthorized
        case 403:
            // Check if it's a scope error
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("scope") {
                throw UsageError.insufficientScope
            }
            throw UsageError.unauthorized
        default:
            logger.error("HTTP Status: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "nil"
            logger.error("Response: \(responseString)")
            // Check for permission/scope errors in response body
            if responseString.contains("scope") || responseString.contains("permission") {
                throw UsageError.insufficientScope
            }
            throw UsageError.invalidResponse
        }
    }
}
