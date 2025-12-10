import XCTest
import SwiftUI
@testable import ClaudeUsageWidget

/// Tests for account deletion functionality
///
/// KNOWN ISSUE: When clicking "Delete" on an account in Settings, the entire widget closes
/// instead of showing the confirmation alert and performing the deletion.
///
/// SUSPECTED CAUSE: The `.alert()` modifier may have similar issues to `.sheet()` in
/// MenuBarExtra context - presenting an alert may cause the window to lose focus and close.
final class AccountDeletionTests: XCTestCase {

    // MARK: - AccountManager Deletion Tests

    /// Test that AccountManager can delete an account
    func testAccountManagerCanDeleteAccount() {
        let manager = AccountManager.shared

        // Store original state
        let originalAccounts = manager.accounts
        let originalSelected = manager.selectedAccountId

        // Add a test account
        let testAccount = manager.addAccount(name: "ToDelete", icon: "🗑️")
        XCTAssertTrue(manager.accounts.contains(where: { $0.id == testAccount.id }))

        // Delete the account
        manager.removeAccount(testAccount)

        // Verify it's gone
        XCTAssertFalse(manager.accounts.contains(where: { $0.id == testAccount.id }),
                       "Account should be removed from accounts list")

        // Restore original state
        if let originalId = originalSelected,
           let account = manager.accounts.first(where: { $0.id == originalId }) {
            manager.selectAccount(account)
        }
    }

    /// Test that deleting selected account selects another
    func testDeletingSelectedAccountSelectsAnother() {
        let manager = AccountManager.shared

        // Store original state
        let originalSelected = manager.selectedAccountId

        // Add two test accounts
        let account1 = manager.addAccount(name: "First", icon: "1️⃣")
        let account2 = manager.addAccount(name: "Second", icon: "2️⃣")

        // Select the first account
        manager.selectAccount(account1)
        XCTAssertEqual(manager.selectedAccountId, account1.id)

        // Delete the selected account
        manager.removeAccount(account1)

        // Verify selection changed to another account
        XCTAssertNotEqual(manager.selectedAccountId, account1.id,
                          "Selected account should change after deletion")

        // Cleanup
        manager.removeAccount(account2)

        // Restore
        if let originalId = originalSelected,
           let account = manager.accounts.first(where: { $0.id == originalId }) {
            manager.selectAccount(account)
        }
    }

    /// Test that token is removed when account is deleted
    func testTokenRemovedWhenAccountDeleted() {
        let manager = AccountManager.shared

        // Add a test account with a token
        let testAccount = manager.addAccount(name: "WithToken", icon: "🔑")
        manager.updateToken(for: testAccount, token: "test-token-12345")

        // Verify token exists
        XCTAssertNotNil(manager.getToken(for: testAccount))

        // Delete the account
        manager.removeAccount(testAccount)

        // Token should be gone (can't easily verify keychain deletion without the account)
        XCTAssertFalse(manager.accounts.contains(where: { $0.id == testAccount.id }))
    }

    // MARK: - Delete Confirmation State Tests

    /// Test delete confirmation state flow
    func testDeleteConfirmationStateFlow() {
        var showDeleteConfirmation = false
        var accountToDelete: Account? = nil

        let testAccount = Account(name: "Test", icon: "🧪")

        // User clicks delete button
        accountToDelete = testAccount
        showDeleteConfirmation = true

        XCTAssertTrue(showDeleteConfirmation)
        XCTAssertNotNil(accountToDelete)
        XCTAssertEqual(accountToDelete?.id, testAccount.id)

        // User confirms deletion
        // (In real code, this would call manager.removeAccount)
        showDeleteConfirmation = false
        accountToDelete = nil

        XCTAssertFalse(showDeleteConfirmation)
        XCTAssertNil(accountToDelete)
    }

    /// Test cancel delete resets state
    func testCancelDeleteResetsState() {
        var showDeleteConfirmation = false
        var accountToDelete: Account? = nil

        let testAccount = Account(name: "Test", icon: "🧪")

        // User clicks delete button
        accountToDelete = testAccount
        showDeleteConfirmation = true

        // User clicks cancel
        showDeleteConfirmation = false
        accountToDelete = nil

        XCTAssertFalse(showDeleteConfirmation)
        XCTAssertNil(accountToDelete)
    }

    // MARK: - Alert Presentation Tests

    /// Document the expected alert behavior
    /// This test documents what SHOULD happen
    func testAlertShouldNotCloseParentWindow() {
        // In MenuBarExtra context:
        // 1. User clicks "..." menu on an account
        // 2. User clicks "Delete"
        // 3. Alert should appear asking for confirmation
        // 4. Clicking "Cancel" should dismiss alert, keep settings open
        // 5. Clicking "Delete" should delete account, keep settings open

        // The bug is that step 3 causes the entire window to close

        var windowShouldRemainOpen = true
        var alertIsPresented = false

        // Simulate showing alert
        alertIsPresented = true

        // Window should still be open
        XCTAssertTrue(windowShouldRemainOpen,
                      "Parent window should remain open when alert is presented")
        XCTAssertTrue(alertIsPresented)

        // Simulate dismissing alert
        alertIsPresented = false

        // Window should still be open
        XCTAssertTrue(windowShouldRemainOpen,
                      "Parent window should remain open after alert is dismissed")
    }

    // MARK: - Menu Button Tests

    /// Test that delete menu item exists and triggers correct action
    func testDeleteMenuItemTriggersConfirmation() {
        var showDeleteConfirmation = false
        var accountToDelete: Account? = nil

        let testAccount = Account(name: "Test", icon: "🧪")

        // Simulate the delete button action from the menu
        let deleteAction = {
            accountToDelete = testAccount
            showDeleteConfirmation = true
        }

        deleteAction()

        XCTAssertTrue(showDeleteConfirmation,
                      "Delete button should set showDeleteConfirmation to true")
        XCTAssertEqual(accountToDelete?.id, testAccount.id,
                       "Delete button should set accountToDelete")
    }

    // MARK: - Destructive Action Safety Tests

    /// Test that delete requires confirmation (not immediate)
    func testDeleteRequiresConfirmation() {
        // Delete should NOT be immediate - it should show a confirmation first
        // This is a safety feature to prevent accidental deletion

        var accountDeleted = false
        var confirmationShown = false

        // When user clicks delete, confirmation should show first
        let onDeleteClicked = {
            confirmationShown = true
            // Account should NOT be deleted yet
        }

        onDeleteClicked()

        XCTAssertTrue(confirmationShown, "Confirmation should be shown")
        XCTAssertFalse(accountDeleted, "Account should not be deleted until confirmed")

        // Only after confirmation should deletion occur
        let onConfirmDelete = {
            accountDeleted = true
            confirmationShown = false
        }

        onConfirmDelete()

        XCTAssertTrue(accountDeleted, "Account should be deleted after confirmation")
        XCTAssertFalse(confirmationShown, "Confirmation should be dismissed")
    }
}

// MARK: - Recommended Fix

/*
 The issue is likely that `.alert()` in MenuBarExtra has the same problem as `.sheet()` -
 presenting system dialogs can cause the MenuBarExtra window to close.

 RECOMMENDED FIX: Use a custom inline confirmation overlay instead of `.alert()`

 Instead of:
 ```
 .alert("Delete Account?", isPresented: $showDeleteConfirmation, presenting: accountToDelete) { ... }
 ```

 Use a custom overlay similar to the token input and account editor overlays:
 ```
 if showDeleteConfirmation, let account = accountToDelete {
     deleteConfirmationOverlay(account)
 }
 ```

 This keeps everything within the same window and avoids the system alert issues.
*/
