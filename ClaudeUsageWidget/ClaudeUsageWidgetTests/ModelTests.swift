import XCTest
@testable import ClaudeUsageWidget

final class ModelTests: XCTestCase {

    // MARK: - Account Tests

    func testAccountCreation() {
        let account = Account(name: "Test Account", icon: "🧪")

        XCTAssertEqual(account.name, "Test Account")
        XCTAssertEqual(account.icon, "🧪")
        XCTAssertNotNil(account.id)
    }

    func testAccountDefaultIcon() {
        let account = Account(name: "No Icon")

        XCTAssertEqual(account.icon, "👤")
    }

    func testAccountSuggestedIconsNotEmpty() {
        XCTAssertFalse(Account.suggestedIcons.isEmpty)
        XCTAssertEqual(Account.suggestedIcons.count, 10)
    }

    func testAccountEquality() {
        let id = UUID()
        let account1 = Account(id: id, name: "Test", icon: "🏠")
        let account2 = Account(id: id, name: "Test", icon: "🏠")

        XCTAssertEqual(account1, account2)
    }

    // MARK: - OAuthCredentials Tests

    func testOAuthCredentialsExpiry() {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let credentials = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: futureDate
        )

        XCTAssertFalse(credentials.isExpired)
    }

    func testOAuthCredentialsExpiredWithSafetyMargin() {
        // Token expires in 4 minutes (less than 5 minute safety margin)
        let nearFutureDate = Date().addingTimeInterval(240)
        let credentials = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: nearFutureDate
        )

        XCTAssertTrue(credentials.isExpired)
    }

    func testOAuthCredentialsFromMilliseconds() {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000) + 3600000 // 1 hour from now
        let credentials = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAtMs: nowMs
        )

        XCTAssertFalse(credentials.isExpired)
    }

    // MARK: - TeamUsageData Tests

    func testTeamUsageDataFormatting() {
        let data = TeamUsageData(
            totalTokens: 2_500_000,
            totalCost: 45.50,
            members: []
        )

        XCTAssertEqual(data.formattedTotalTokens, "2.5M")
        XCTAssertEqual(data.formattedTotalCost, "$45.50")
    }

    func testTeamUsageDataSmallTokens() {
        let data = TeamUsageData(
            totalTokens: 500,
            totalCost: 0.01,
            members: []
        )

        XCTAssertEqual(data.formattedTotalTokens, "500")
        XCTAssertEqual(data.formattedTotalCost, "$0.01")
    }

    func testTeamUsageDataKiloTokens() {
        let data = TeamUsageData(
            totalTokens: 50_000,
            totalCost: 1.25,
            members: []
        )

        XCTAssertEqual(data.formattedTotalTokens, "50.0K")
    }

    func testTeamMembersSorting() {
        let members = [
            TeamMember(id: "1", email: "low@test.com", tokenCount: 100, editCount: 0, prCount: 0),
            TeamMember(id: "2", email: "high@test.com", tokenCount: 1000, editCount: 0, prCount: 0),
            TeamMember(id: "3", email: "mid@test.com", tokenCount: 500, editCount: 0, prCount: 0)
        ]

        let data = TeamUsageData(totalTokens: 1600, totalCost: 0, members: members)

        XCTAssertEqual(data.sortedMembers[0].email, "high@test.com")
        XCTAssertEqual(data.sortedMembers[1].email, "mid@test.com")
        XCTAssertEqual(data.sortedMembers[2].email, "low@test.com")
    }

    // MARK: - TeamMember Tests

    func testTeamMemberDisplayName() {
        let member = TeamMember(
            id: "1",
            email: "dana.pavey@example.com",
            tokenCount: 1000,
            editCount: 5,
            prCount: 2
        )

        XCTAssertEqual(member.displayName, "Dana Pavey")
    }

    func testTeamMemberDisplayNameSingleWord() {
        let member = TeamMember(
            id: "1",
            email: "admin@example.com",
            tokenCount: 1000,
            editCount: 0,
            prCount: 0
        )

        XCTAssertEqual(member.displayName, "Admin")
    }

    func testTeamMemberPercentageOfTeam() {
        let member = TeamMember(
            id: "1",
            email: "test@example.com",
            tokenCount: 250,
            editCount: 0,
            prCount: 0
        )

        XCTAssertEqual(member.percentageOfTeam(1000), 25)
    }

    func testTeamMemberPercentageOfTeamZeroTotal() {
        let member = TeamMember(
            id: "1",
            email: "test@example.com",
            tokenCount: 250,
            editCount: 0,
            prCount: 0
        )

        XCTAssertEqual(member.percentageOfTeam(0), 0)
    }

    func testTeamMemberFormattedTokens() {
        let largeUsage = TeamMember(id: "1", email: "a@b.com", tokenCount: 523_000, editCount: 0, prCount: 0)
        let smallUsage = TeamMember(id: "2", email: "c@d.com", tokenCount: 500, editCount: 0, prCount: 0)

        XCTAssertEqual(largeUsage.formattedTokens, "523K")
        XCTAssertEqual(smallUsage.formattedTokens, "500")
    }

    // MARK: - UsageMode Tests

    func testUsageModeDisplayNames() {
        XCTAssertEqual(UsageMode.personal.displayName, "Personal")
        XCTAssertEqual(UsageMode.team.displayName, "Team Dashboard")
        XCTAssertEqual(UsageMode.both.displayName, "Both")
    }

    func testUsageModeIcons() {
        XCTAssertEqual(UsageMode.personal.icon, "👤")
        XCTAssertEqual(UsageMode.team.icon, "👥")
        XCTAssertEqual(UsageMode.both.icon, "🔄")
    }

    func testUsageModeAllCases() {
        XCTAssertEqual(UsageMode.allCases.count, 3)
    }
}
