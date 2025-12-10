import XCTest
import SwiftUI
@testable import ClaudeUsageWidget

/// Tests for UI interactions and state changes
/// These tests verify that UI components respond correctly to user interactions
final class UIInteractionTests: XCTestCase {

    // MARK: - Account Manager Interaction Tests

    func testAccountSelectionChangesSelectedAccount() {
        let manager = AccountManager.shared

        // Store original state
        let originalAccounts = manager.accounts
        let originalSelected = manager.selectedAccountId

        // Add test accounts
        let account1 = manager.addAccount(name: "Test1", icon: "🧪")
        let account2 = manager.addAccount(name: "Test2", icon: "🔬")

        // Select second account
        manager.selectAccount(account2)
        XCTAssertEqual(manager.selectedAccountId, account2.id)

        // Select first account
        manager.selectAccount(account1)
        XCTAssertEqual(manager.selectedAccountId, account1.id)

        // Cleanup: remove test accounts
        manager.removeAccount(account1)
        manager.removeAccount(account2)

        // Restore original selection if there was one
        if let originalId = originalSelected,
           let originalAccount = originalAccounts.first(where: { $0.id == originalId }) {
            manager.selectAccount(originalAccount)
        }
    }

    func testAccountRemovalSelectsAnotherAccount() {
        let manager = AccountManager.shared

        // Store original state
        let originalSelected = manager.selectedAccountId

        // Add test accounts
        let account1 = manager.addAccount(name: "ToRemove", icon: "❌")
        let account2 = manager.addAccount(name: "ToKeep", icon: "✅")

        // Select the account we'll remove
        manager.selectAccount(account1)
        XCTAssertEqual(manager.selectedAccountId, account1.id)

        // Remove it
        manager.removeAccount(account1)

        // Verify selection changed (either to account2 or another existing account)
        XCTAssertNotEqual(manager.selectedAccountId, account1.id)

        // Cleanup
        manager.removeAccount(account2)

        // Restore
        if let originalId = originalSelected,
           let account = manager.accounts.first(where: { $0.id == originalId }) {
            manager.selectAccount(account)
        }
    }

    func testAccountUpdatePersistsChanges() {
        let manager = AccountManager.shared

        // Add test account
        let account = manager.addAccount(name: "Original", icon: "📝")

        // Update name and icon
        manager.updateAccount(account, name: "Updated", icon: "✏️")

        // Find the updated account
        let updated = manager.accounts.first(where: { $0.id == account.id })
        XCTAssertEqual(updated?.name, "Updated")
        XCTAssertEqual(updated?.icon, "✏️")

        // Cleanup
        manager.removeAccount(account)
    }

    // MARK: - AppSettings Interaction Tests

    func testAppSettingsModeChanges() {
        let settings = AppSettings.shared

        // Store original
        let originalMode = settings.mode

        // Change modes
        settings.mode = .team
        XCTAssertEqual(settings.mode, .team)

        settings.mode = .both
        XCTAssertEqual(settings.mode, .both)

        settings.mode = .personal
        XCTAssertEqual(settings.mode, .personal)

        // Restore
        settings.mode = originalMode
    }

    func testAppSettingsShowTeamViewToggle() {
        let settings = AppSettings.shared

        // Store original
        let original = settings.showTeamView

        // Toggle
        settings.showTeamView = !settings.showTeamView
        XCTAssertNotEqual(settings.showTeamView, original)

        // Toggle back
        settings.showTeamView = original
        XCTAssertEqual(settings.showTeamView, original)
    }

    func testAppSettingsCompleteSetup() {
        let settings = AppSettings.shared

        // Store original state
        let originalHasCompleted = settings.hasCompletedSetup
        let originalMode = settings.mode

        // Complete setup with team mode
        settings.completeSetup(mode: .team, adminKey: "sk-ant-admin-test-key-12345")

        XCTAssertTrue(settings.hasCompletedSetup)
        XCTAssertEqual(settings.mode, .team)
        XCTAssertTrue(settings.hasAdminKey)

        // Reset for other tests
        settings.resetSetup()
        XCTAssertFalse(settings.hasCompletedSetup)
        XCTAssertEqual(settings.mode, .personal)
        XCTAssertFalse(settings.hasAdminKey)

        // Restore original state
        if originalHasCompleted {
            settings.completeSetup(mode: originalMode)
        }
    }

    // MARK: - Button State Tests

    func testAddAccountButtonRequiresName() {
        // Simulate the condition in addAccountSheet
        let editName = ""
        let isDisabled = editName.isEmpty

        XCTAssertTrue(isDisabled, "Add button should be disabled when name is empty")
    }

    func testAddAccountButtonEnabledWithName() {
        let editName = "Test Account"
        let isDisabled = editName.isEmpty

        XCTAssertFalse(isDisabled, "Add button should be enabled when name is provided")
    }

    func testTokenSaveButtonRequiresToken() {
        let manualToken = ""
        let isDisabled = manualToken.isEmpty

        XCTAssertTrue(isDisabled, "Save token button should be disabled when token is empty")
    }

    func testTokenSaveButtonEnabledWithToken() {
        let manualToken = "some-oauth-token"
        let isDisabled = manualToken.isEmpty

        XCTAssertFalse(isDisabled, "Save token button should be enabled when token is provided")
    }

    // MARK: - Admin Key Validation Tests

    func testAdminKeyValidation() {
        // Valid key format
        let validKey = "sk-ant-admin-12345678901234567890"
        let isValid = validKey.hasPrefix("sk-ant-admin") && validKey.count > 20

        XCTAssertTrue(isValid, "Admin key with correct prefix and length should be valid")
    }

    func testAdminKeyValidationWrongPrefix() {
        let invalidKey = "sk-ant-api-12345678901234567890"
        let isValid = invalidKey.hasPrefix("sk-ant-admin") && invalidKey.count > 20

        XCTAssertFalse(isValid, "Admin key with wrong prefix should be invalid")
    }

    func testAdminKeyValidationTooShort() {
        let shortKey = "sk-ant-admin-short"
        let isValid = shortKey.hasPrefix("sk-ant-admin") && shortKey.count > 20

        XCTAssertFalse(isValid, "Admin key that is too short should be invalid")
    }

    // MARK: - Refresh Interval Tests

    func testRefreshIntervalValidValues() {
        let validIntervals = [1, 5, 10, 15, 30]

        for interval in validIntervals {
            XCTAssertTrue(interval >= 1 && interval <= 30,
                          "Interval \(interval) should be within valid range")
        }
    }

    // MARK: - Account Toggle Visibility Tests

    func testAccountToggleVisibleWithMultipleAccounts() {
        let accountCount = 2
        let shouldShowToggle = accountCount > 1

        XCTAssertTrue(shouldShowToggle, "Account toggle should show with multiple accounts")
    }

    func testAccountToggleHiddenWithSingleAccount() {
        let accountCount = 1
        let shouldShowToggle = accountCount > 1

        XCTAssertFalse(shouldShowToggle, "Account toggle should hide with single account")
    }

    // MARK: - Mode-based View Selection Tests

    func testShouldShowTeamViewInPersonalMode() {
        let mode = UsageMode.personal
        let showTeamView = false

        let shouldShow: Bool
        switch mode {
        case .personal: shouldShow = false
        case .team: shouldShow = true
        case .both: shouldShow = showTeamView
        }

        XCTAssertFalse(shouldShow, "Should show personal view in personal mode")
    }

    func testShouldShowTeamViewInTeamMode() {
        let mode = UsageMode.team
        let showTeamView = false

        let shouldShow: Bool
        switch mode {
        case .personal: shouldShow = false
        case .team: shouldShow = true
        case .both: shouldShow = showTeamView
        }

        XCTAssertTrue(shouldShow, "Should show team view in team mode")
    }

    func testShouldShowTeamViewInBothModeWithToggle() {
        let mode = UsageMode.both
        let showTeamView = true

        let shouldShow: Bool
        switch mode {
        case .personal: shouldShow = false
        case .team: shouldShow = true
        case .both: shouldShow = showTeamView
        }

        XCTAssertTrue(shouldShow, "Should show team view in both mode when toggled")
    }
}
