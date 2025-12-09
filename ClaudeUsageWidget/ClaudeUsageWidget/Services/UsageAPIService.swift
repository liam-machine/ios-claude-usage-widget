import Foundation

class UsageAPIService {
    static let shared = UsageAPIService()

    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let keychainService = KeychainService.shared

    private init() {}

    /// Fetch usage for a specific account (preferred method)
    func fetchUsage(for account: Account) async throws -> UsageData {
        // Use TokenService to get a valid token
        guard let token = TokenService.shared.getValidToken(for: account) else {
            // Check if token is expired vs missing
            if TokenService.shared.isTokenExpiredOrMissing(for: account) {
                if KeychainService.shared.getCredentials(forAccountId: account.id.uuidString) != nil {
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

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.0.31", forHTTPHeaderField: "User-Agent")
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
                print("Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
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
            print("HTTP Status: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "nil"
            print("Response: \(responseString)")
            // Check for permission/scope errors in response body
            if responseString.contains("scope") || responseString.contains("permission") {
                throw UsageError.insufficientScope
            }
            throw UsageError.invalidResponse
        }
    }
}
