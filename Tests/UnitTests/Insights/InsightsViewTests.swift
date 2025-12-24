import XCTest
import SwiftData
@testable import LetsTrack

typealias InsightsCategory = LetsTrack.Category

@MainActor
final class InsightsViewTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Transaction.self, InsightsCategory.self, Budget.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - InsightPeriod Tests

    func testInsightPeriod_DisplayName_3Months() {
        let period = InsightPeriod.threeMonths
        XCTAssertFalse(period.displayName.isEmpty)
    }

    func testInsightPeriod_DisplayName_6Months() {
        let period = InsightPeriod.sixMonths
        XCTAssertFalse(period.displayName.isEmpty)
    }

    func testInsightPeriod_DisplayName_1Year() {
        let period = InsightPeriod.oneYear
        XCTAssertFalse(period.displayName.isEmpty)
    }

    func testInsightPeriod_MonthCount_3Months() {
        XCTAssertEqual(InsightPeriod.threeMonths.monthCount, 3)
    }

    func testInsightPeriod_MonthCount_6Months() {
        XCTAssertEqual(InsightPeriod.sixMonths.monthCount, 6)
    }

    func testInsightPeriod_MonthCount_1Year() {
        XCTAssertEqual(InsightPeriod.oneYear.monthCount, 12)
    }

    func testInsightPeriod_StartDate_3Months() {
        let period = InsightPeriod.threeMonths
        let expectedDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(period.startDate, inSameDayAs: expectedDate))
    }

    func testInsightPeriod_StartDate_6Months() {
        let period = InsightPeriod.sixMonths
        let expectedDate = Calendar.current.date(byAdding: .month, value: -6, to: Date())!

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(period.startDate, inSameDayAs: expectedDate))
    }

    func testInsightPeriod_StartDate_1Year() {
        let period = InsightPeriod.oneYear
        let expectedDate = Calendar.current.date(byAdding: .month, value: -12, to: Date())!

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(period.startDate, inSameDayAs: expectedDate))
    }

    func testInsightPeriod_AllCases() {
        XCTAssertEqual(InsightPeriod.allCases.count, 3)
        XCTAssertTrue(InsightPeriod.allCases.contains(.threeMonths))
        XCTAssertTrue(InsightPeriod.allCases.contains(.sixMonths))
        XCTAssertTrue(InsightPeriod.allCases.contains(.oneYear))
    }

    // MARK: - View Component Tests with Mock Data

    func testSpendingTrendsCard_WithEmptyTrends() {
        let trends: [SpendingTrend] = []
        XCTAssertTrue(trends.isEmpty)
    }

    func testSpendingTrendsCard_WithTrends() {
        let trends = [
            SpendingTrend(period: "Jan", income: 3000000, expense: 1500000, balance: 1500000, date: Date()),
            SpendingTrend(period: "Feb", income: 3000000, expense: 2000000, balance: 1000000, date: Date())
        ]

        XCTAssertEqual(trends.count, 2)
        XCTAssertEqual(trends[0].balance, trends[0].income - trends[0].expense)
    }

    func testBudgetPrediction_UsagePercentage() {
        let prediction = BudgetPrediction(
            currentSpent: 500000,
            predictedTotal: 800000,
            budgetAmount: 1000000,
            daysInPeriod: 30,
            daysElapsed: 15,
            dailyAverage: 33333,
            remainingBudget: 500000,
            predictedOverage: 0,
            isOnTrack: true,
            confidence: 50
        )

        XCTAssertEqual(prediction.usagePercentage, 50, accuracy: 0.01)
    }

    func testBudgetPrediction_PredictedUsagePercentage() {
        let prediction = BudgetPrediction(
            currentSpent: 500000,
            predictedTotal: 800000,
            budgetAmount: 1000000,
            daysInPeriod: 30,
            daysElapsed: 15,
            dailyAverage: 33333,
            remainingBudget: 500000,
            predictedOverage: 0,
            isOnTrack: true,
            confidence: 50
        )

        XCTAssertEqual(prediction.predictedUsagePercentage, 80, accuracy: 0.01)
    }

    func testBudgetPrediction_ZeroBudget_ReturnsZeroPercentage() {
        let prediction = BudgetPrediction(
            currentSpent: 500000,
            predictedTotal: 800000,
            budgetAmount: 0,
            daysInPeriod: 30,
            daysElapsed: 15,
            dailyAverage: 33333,
            remainingBudget: -500000,
            predictedOverage: 800000,
            isOnTrack: false,
            confidence: 50
        )

        XCTAssertEqual(prediction.usagePercentage, 0)
        XCTAssertEqual(prediction.predictedUsagePercentage, 0)
    }

    func testTopExpense_Rank() {
        let category = InsightsCategory(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        modelContext.insert(category)

        let transaction = Transaction(amount: 50000, type: .expense, note: "Lunch")
        transaction.category = category
        modelContext.insert(transaction)
        try? modelContext.save()

        let topExpense = TopExpense(transaction: transaction, rank: 1)

        XCTAssertEqual(topExpense.rank, 1)
        XCTAssertEqual(topExpense.transaction.amount, 50000)
    }

    func testSpendingByDayOfWeek_Properties() {
        let spending = SpendingByDayOfWeek(
            dayOfWeek: 1,
            dayName: "Sunday",
            totalAmount: 100000,
            averageAmount: 25000,
            transactionCount: 4
        )

        XCTAssertEqual(spending.dayOfWeek, 1)
        XCTAssertEqual(spending.dayName, "Sunday")
        XCTAssertEqual(spending.totalAmount, 100000)
        XCTAssertEqual(spending.averageAmount, 25000)
        XCTAssertEqual(spending.transactionCount, 4)
    }

    func testSpendingByHour_Properties() {
        let spending = SpendingByHour(
            hour: 12,
            totalAmount: 50000,
            transactionCount: 3
        )

        XCTAssertEqual(spending.hour, 12)
        XCTAssertEqual(spending.totalAmount, 50000)
        XCTAssertEqual(spending.transactionCount, 3)
    }

    func testCategorySpending_Properties() {
        let category = InsightsCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", type: .expense)
        modelContext.insert(category)
        try? modelContext.save()

        let spending = CategorySpending(
            category: category,
            amount: 200000,
            percentage: 25.5,
            transactionCount: 10
        )

        XCTAssertEqual(spending.category.name, "Shopping")
        XCTAssertEqual(spending.amount, 200000)
        XCTAssertEqual(spending.percentage, 25.5)
        XCTAssertEqual(spending.transactionCount, 10)
    }

    func testDetectedRecurringPattern_Properties() {
        let category = InsightsCategory(name: "Entertainment", icon: "gamecontroller.fill", colorHex: "#5856D6", type: .expense)
        modelContext.insert(category)
        try? modelContext.save()

        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())

        let pattern = DetectedRecurringPattern(
            category: category,
            averageAmount: 15000,
            frequency: "monthly",
            occurrences: 5,
            lastOccurrence: Date(),
            nextExpected: nextWeek,
            note: "Netflix",
            confidence: 0.9
        )

        XCTAssertEqual(pattern.category?.name, "Entertainment")
        XCTAssertEqual(pattern.averageAmount, 15000)
        XCTAssertEqual(pattern.frequency, "monthly")
        XCTAssertEqual(pattern.occurrences, 5)
        XCTAssertNotNil(pattern.nextExpected)
        XCTAssertEqual(pattern.note, "Netflix")
        XCTAssertEqual(pattern.confidence, 0.9)
    }

    func testCategoryTrend_Properties() {
        let category = InsightsCategory(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        modelContext.insert(category)
        try? modelContext.save()

        let trend = CategoryTrend(
            category: category,
            currentMonthAmount: 500000,
            previousMonthAmount: 400000,
            change: 100000,
            changePercentage: 25,
            isIncreasing: true,
            averageMonthlyAmount: 450000,
            transactionCount: 15
        )

        XCTAssertEqual(trend.category.name, "Food")
        XCTAssertEqual(trend.currentMonthAmount, 500000)
        XCTAssertEqual(trend.previousMonthAmount, 400000)
        XCTAssertEqual(trend.change, 100000)
        XCTAssertEqual(trend.changePercentage, 25)
        XCTAssertTrue(trend.isIncreasing)
        XCTAssertEqual(trend.averageMonthlyAmount, 450000)
        XCTAssertEqual(trend.transactionCount, 15)
    }

    func testCategoryTrend_Decreasing() {
        let category = InsightsCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", type: .expense)
        modelContext.insert(category)
        try? modelContext.save()

        let trend = CategoryTrend(
            category: category,
            currentMonthAmount: 100000,
            previousMonthAmount: 200000,
            change: -100000,
            changePercentage: -50,
            isIncreasing: false,
            averageMonthlyAmount: 150000,
            transactionCount: 5
        )

        XCTAssertFalse(trend.isIncreasing)
        XCTAssertEqual(trend.change, -100000)
        XCTAssertEqual(trend.changePercentage, -50)
    }

    // MARK: - SpendingTrend Tests

    func testSpendingTrend_ChangeFromPrevious() {
        var trend = SpendingTrend(
            period: "Dec",
            income: 3000000,
            expense: 2000000,
            balance: 1000000,
            date: Date()
        )

        trend.changeFromPrevious = 500000
        trend.changePercentage = 33.33

        XCTAssertEqual(trend.changeFromPrevious, 500000)
        XCTAssertNotNil(trend.changePercentage)
        if let changePercentage = trend.changePercentage {
            XCTAssertEqual(changePercentage, 33.33, accuracy: 0.01)
        }
    }

    func testSpendingTrend_HasUniqueId() {
        let trend1 = SpendingTrend(period: "Jan", income: 1000, expense: 500, balance: 500, date: Date())
        let trend2 = SpendingTrend(period: "Jan", income: 1000, expense: 500, balance: 500, date: Date())

        XCTAssertNotEqual(trend1.id, trend2.id)
    }
}
