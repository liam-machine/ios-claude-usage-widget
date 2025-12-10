import XCTest
@testable import ClaudeUsageWidget

@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - UsageViewModel Tests

    func testViewModelInitialState() async {
        let viewModel = UsageViewModel()

        XCTAssertNil(viewModel.usageData)
        XCTAssertNil(viewModel.error)
        XCTAssertNil(viewModel.teamUsageData)
        XCTAssertNil(viewModel.teamError)
        XCTAssertEqual(viewModel.lastUpdatedText, "Never")
    }

    func testStatusColorForLowUsage() async {
        let viewModel = UsageViewModel()

        // Without data, should be secondary color
        XCTAssertEqual(viewModel.statusColor, .secondary)
    }

    func testRefreshIntervalUpdate() async {
        let viewModel = UsageViewModel()
        let originalInterval = viewModel.refreshInterval

        viewModel.updateRefreshInterval(10)
        XCTAssertEqual(viewModel.refreshInterval, 10)

        // Restore original
        viewModel.updateRefreshInterval(originalInterval)
    }

    func testLastUpdatedTextFormatting() async {
        let viewModel = UsageViewModel()

        // Initial state should show "Never"
        XCTAssertEqual(viewModel.lastUpdatedText, "Never")
    }

    func testCurrentAccountNameWithNoAccount() async {
        let viewModel = UsageViewModel()

        // When no account selected, should show "Unknown" or first account name
        XCTAssertFalse(viewModel.currentAccountName.isEmpty)
    }
}
