import XCTest
@testable import LetsTrack

final class RecurringProjectionServiceTests: XCTestCase {
    func testProjectedTransactions_RespectsRangeAndFrequency() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 12))!
        let endDate = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 12))!

        let recurring = RecurringTransaction(
            amount: 10000,
            type: .expense,
            note: "Subscription",
            frequency: .monthly,
            startDate: calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 12))!
        )

        let projections = RecurringProjectionService.projectedTransactions(
            recurrings: [recurring],
            from: startDate,
            to: endDate,
            currency: .usd
        )

        XCTAssertEqual(projections.count, 3)
        XCTAssertEqual(projections[0].date, recurring.startDate)
        XCTAssertEqual(projections[0].currency, .usd)
    }

    func testProjectedTransactions_SkipsInactive() {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        let recurring = RecurringTransaction(
            amount: 5000,
            type: .expense,
            note: "Inactive",
            frequency: .monthly,
            startDate: startDate
        )
        recurring.isActive = false

        let projections = RecurringProjectionService.projectedTransactions(
            recurrings: [recurring],
            from: startDate,
            to: endDate,
            currency: .krw
        )

        XCTAssertTrue(projections.isEmpty)
    }

    func testProjectedTransactions_StopsAtEndDate() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 12))!
        let endDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 20, hour: 12))!

        let recurring = RecurringTransaction(
            amount: 10000,
            type: .expense,
            note: "Limited",
            frequency: .weekly,
            startDate: calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 12))!,
            endDate: calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 12))!
        )

        let projections = RecurringProjectionService.projectedTransactions(
            recurrings: [recurring],
            from: startDate,
            to: endDate,
            currency: .usd
        )

        XCTAssertEqual(projections.count, 3)
        XCTAssertTrue(projections.allSatisfy { $0.date <= recurring.endDate! })
    }
}
