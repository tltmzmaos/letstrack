import XCTest
import UserNotifications
@testable import LetsTrack

@MainActor
final class NotificationServiceTests: XCTestCase {

    var service: NotificationService!

    override func setUpWithError() throws {
        service = NotificationService.shared
    }

    override func tearDownWithError() throws {
        service.clearAllNotifications()
    }

    // MARK: - Budget Notification Tests

    func testScheduleBudgetWarningNotification_DoesNotCrash() throws {
        // This test verifies the method doesn't crash
        // Actual notification delivery requires device/simulator with permissions
        service.scheduleBudgetWarningNotification(
            budgetName: "음식",
            spent: 80000,
            budget: 100000,
            percentage: 80.0
        )

        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }

    func testScheduleBudgetExceededNotification_DoesNotCrash() throws {
        service.scheduleBudgetExceededNotification(
            budgetName: "총 예산",
            overspent: 50000
        )

        XCTAssertTrue(true)
    }

    // MARK: - Daily Reminder Tests

    func testScheduleDailyReminder_DoesNotCrash() throws {
        service.scheduleDailyReminder(at: 21, minute: 0)

        XCTAssertTrue(true)
    }

    func testScheduleDailyReminder_ValidHours() throws {
        // Test various valid hour/minute combinations
        service.scheduleDailyReminder(at: 0, minute: 0)
        service.scheduleDailyReminder(at: 12, minute: 30)
        service.scheduleDailyReminder(at: 23, minute: 59)

        XCTAssertTrue(true)
    }

    func testCancelDailyReminder_DoesNotCrash() throws {
        // First schedule, then cancel
        service.scheduleDailyReminder(at: 21, minute: 0)
        service.cancelDailyReminder()

        XCTAssertTrue(true)
    }

    // MARK: - Recurring Transaction Reminder Tests

    func testScheduleRecurringTransactionReminder_DoesNotCrash() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

        service.scheduleRecurringTransactionReminder(
            id: "test-recurring-1",
            name: "월세",
            amount: 500000,
            dueDate: futureDate
        )

        XCTAssertTrue(true)
    }

    func testScheduleRecurringTransactionReminder_WithTomorrow() throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        service.scheduleRecurringTransactionReminder(
            id: "test-recurring-2",
            name: "넷플릭스",
            amount: 17000,
            dueDate: tomorrow
        )

        XCTAssertTrue(true)
    }

    // MARK: - Clear All Tests

    func testClearAllNotifications_DoesNotCrash() throws {
        // Schedule some notifications first
        service.scheduleDailyReminder(at: 21, minute: 0)
        service.scheduleBudgetWarningNotification(
            budgetName: "테스트",
            spent: 50000,
            budget: 100000,
            percentage: 50.0
        )

        // Clear all
        service.clearAllNotifications()

        XCTAssertTrue(true)
    }

    // MARK: - Singleton Tests

    func testSharedInstance() throws {
        let instance1 = NotificationService.shared
        let instance2 = NotificationService.shared

        XCTAssertTrue(instance1 === instance2)
    }
}

// MARK: - Budget Status Tests

final class BudgetStatusTests: XCTestCase {

    func testBudgetStatus_IsExceeded() throws {
        let exceeded = BudgetStatus.exceeded(overspent: 10000)
        XCTAssertTrue(exceeded.isExceeded)
        XCTAssertFalse(exceeded.isWarning)
    }

    func testBudgetStatus_IsWarning() throws {
        let warning = BudgetStatus.warning(remaining: 20000, percentage: 80.0)
        XCTAssertTrue(warning.isWarning)
        XCTAssertFalse(warning.isExceeded)
    }

    func testBudgetStatus_IsSafe() throws {
        let safe = BudgetStatus.safe(remaining: 50000, percentage: 50.0)
        XCTAssertFalse(safe.isExceeded)
        XCTAssertFalse(safe.isWarning)
    }

    func testBudgetStatus_ExceededValues() throws {
        let exceeded = BudgetStatus.exceeded(overspent: 25000)

        if case .exceeded(let overspent) = exceeded {
            XCTAssertEqual(overspent, 25000)
        } else {
            XCTFail("Expected exceeded status")
        }
    }

    func testBudgetStatus_WarningValues() throws {
        let warning = BudgetStatus.warning(remaining: 15000, percentage: 85.0)

        if case .warning(let remaining, let percentage) = warning {
            XCTAssertEqual(remaining, 15000)
            XCTAssertEqual(percentage, 85.0)
        } else {
            XCTFail("Expected warning status")
        }
    }

    func testBudgetStatus_SafeValues() throws {
        let safe = BudgetStatus.safe(remaining: 70000, percentage: 30.0)

        if case .safe(let remaining, let percentage) = safe {
            XCTAssertEqual(remaining, 70000)
            XCTAssertEqual(percentage, 30.0)
        } else {
            XCTFail("Expected safe status")
        }
    }
}
