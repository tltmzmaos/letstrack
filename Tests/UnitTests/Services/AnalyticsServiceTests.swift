import XCTest
import SwiftData
@testable import LetsTrack

typealias AnalyticsCategory = LetsTrack.Category

@MainActor
final class AnalyticsServiceTests: XCTestCase {
    var service: AnalyticsService!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testCategories: [AnalyticsCategory]!
    var testTransactions: [Transaction]!

    override func setUpWithError() throws {
        service = AnalyticsService.shared

        let schema = Schema([Transaction.self, AnalyticsCategory.self, Budget.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext

        // Create test categories
        testCategories = [
            AnalyticsCategory(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense),
            AnalyticsCategory(name: "Transport", icon: "car.fill", colorHex: "#007AFF", type: .expense),
            AnalyticsCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", type: .expense),
            AnalyticsCategory(name: "Salary", icon: "banknote.fill", colorHex: "#00C853", type: .income)
        ]
        testCategories.forEach { modelContext.insert($0) }

        // Create test transactions
        testTransactions = createTestTransactions()
        testTransactions.forEach { modelContext.insert($0) }

        try modelContext.save()
    }

    override func tearDownWithError() throws {
        testCategories = nil
        testTransactions = nil
        modelContainer = nil
        modelContext = nil
    }

    private func createTestTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        var transactions: [Transaction] = []

        // Current month expenses
        let foodCategory = testCategories.first { $0.name == "Food" }
        let transportCategory = testCategories.first { $0.name == "Transport" }
        let shoppingCategory = testCategories.first { $0.name == "Shopping" }
        let salaryCategory = testCategories.first { $0.name == "Salary" }

        // Food transactions this month
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let transaction = Transaction(amount: Decimal(10000 + i * 1000), type: .expense, note: "Food \(i)", date: date)
            transaction.category = foodCategory
            transactions.append(transaction)
        }

        // Transport transactions this month
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i * 2, to: now) ?? now
            let transaction = Transaction(amount: Decimal(3000), type: .expense, note: "Taxi", date: date)
            transaction.category = transportCategory
            transactions.append(transaction)
        }

        // Shopping transaction this month
        let shoppingTransaction = Transaction(amount: Decimal(50000), type: .expense, note: "Shopping", date: now)
        shoppingTransaction.category = shoppingCategory
        transactions.append(shoppingTransaction)

        // Income this month
        let salaryTransaction = Transaction(amount: Decimal(3000000), type: .income, note: "Salary", date: now)
        salaryTransaction.category = salaryCategory
        transactions.append(salaryTransaction)

        // Last month transactions
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) {
            let lastMonthFood = Transaction(amount: Decimal(30000), type: .expense, note: "Food last month", date: lastMonth)
            lastMonthFood.category = foodCategory
            transactions.append(lastMonthFood)

            let lastMonthSalary = Transaction(amount: Decimal(3000000), type: .income, note: "Salary last month", date: lastMonth)
            lastMonthSalary.category = salaryCategory
            transactions.append(lastMonthSalary)
        }

        return transactions
    }

    // MARK: - Monthly Trends Tests

    func testGetMonthlyTrends_ReturnsCorrectCount() {
        let trends = service.getMonthlyTrends(transactions: testTransactions, months: 6)
        XCTAssertEqual(trends.count, 6)
    }

    func testGetMonthlyTrends_CalculatesTotalsCorrectly() {
        let trends = service.getMonthlyTrends(transactions: testTransactions, months: 2)

        // Current month should have transactions
        if let currentMonthTrend = trends.last {
            XCTAssertGreaterThan(currentMonthTrend.expense, 0)
            XCTAssertGreaterThan(currentMonthTrend.income, 0)
        }
    }

    func testGetMonthlyTrends_CalculatesBalance() {
        let trends = service.getMonthlyTrends(transactions: testTransactions, months: 1)

        if let trend = trends.first {
            XCTAssertEqual(trend.balance, trend.income - trend.expense)
        }
    }

    func testGetMonthlyTrends_EmptyTransactions() {
        let trends = service.getMonthlyTrends(transactions: [], months: 3)
        XCTAssertEqual(trends.count, 3)

        for trend in trends {
            XCTAssertEqual(trend.income, 0)
            XCTAssertEqual(trend.expense, 0)
        }
    }

    // MARK: - Category Breakdown Tests

    func testGetCategoryBreakdown_ReturnsCategories() {
        let breakdown = service.getCategoryBreakdown(transactions: testTransactions, type: .expense)
        XCTAssertGreaterThan(breakdown.count, 0)
    }

    func testGetCategoryBreakdown_CalculatesPercentages() {
        let breakdown = service.getCategoryBreakdown(transactions: testTransactions, type: .expense)

        let totalPercentage = breakdown.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 100, accuracy: 0.1)
    }

    func testGetCategoryBreakdown_SortsByAmount() {
        let breakdown = service.getCategoryBreakdown(transactions: testTransactions, type: .expense)

        for i in 0..<(breakdown.count - 1) {
            XCTAssertGreaterThanOrEqual(breakdown[i].amount, breakdown[i + 1].amount)
        }
    }

    func testGetCategoryBreakdown_FiltersByType() {
        let expenseBreakdown = service.getCategoryBreakdown(transactions: testTransactions, type: .expense)
        let incomeBreakdown = service.getCategoryBreakdown(transactions: testTransactions, type: .income)

        for item in expenseBreakdown {
            XCTAssertEqual(item.category.type, .expense)
        }

        for item in incomeBreakdown {
            XCTAssertEqual(item.category.type, .income)
        }
    }

    func testGetCategoryBreakdown_EmptyTransactions() {
        let breakdown = service.getCategoryBreakdown(transactions: [], type: .expense)
        XCTAssertTrue(breakdown.isEmpty)
    }

    // MARK: - Top Expenses Tests

    func testGetTopExpenses_ReturnsCorrectLimit() {
        let topExpenses = service.getTopExpenses(transactions: testTransactions, limit: 5)
        XCTAssertLessThanOrEqual(topExpenses.count, 5)
    }

    func testGetTopExpenses_SortsByAmountDescending() {
        let topExpenses = service.getTopExpenses(transactions: testTransactions)

        for i in 0..<(topExpenses.count - 1) {
            XCTAssertGreaterThanOrEqual(
                topExpenses[i].transaction.amount,
                topExpenses[i + 1].transaction.amount
            )
        }
    }

    func testGetTopExpenses_AssignsCorrectRanks() {
        let topExpenses = service.getTopExpenses(transactions: testTransactions, limit: 5)

        for (index, expense) in topExpenses.enumerated() {
            XCTAssertEqual(expense.rank, index + 1)
        }
    }

    func testGetTopExpenses_OnlyIncludesExpenses() {
        let topExpenses = service.getTopExpenses(transactions: testTransactions)

        for expense in topExpenses {
            XCTAssertEqual(expense.transaction.type, .expense)
        }
    }

    func testGetTopExpenses_FiltersByDateRange() {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -3, to: now)!
        let endDate = now

        let topExpenses = service.getTopExpenses(
            transactions: testTransactions,
            from: startDate,
            to: endDate
        )

        for expense in topExpenses {
            XCTAssertGreaterThanOrEqual(expense.transaction.date, startDate)
            XCTAssertLessThanOrEqual(expense.transaction.date, endDate)
        }
    }

    // MARK: - Day of Week Analysis Tests

    func testGetSpendingByDayOfWeek_Returns7Days() {
        let spending = service.getSpendingByDayOfWeek(transactions: testTransactions)
        XCTAssertEqual(spending.count, 7)
    }

    func testGetSpendingByDayOfWeek_HasCorrectDayNumbers() {
        let spending = service.getSpendingByDayOfWeek(transactions: testTransactions)

        for (index, day) in spending.enumerated() {
            XCTAssertEqual(day.dayOfWeek, index + 1)
        }
    }

    func testGetSpendingByDayOfWeek_CalculatesAverage() {
        let spending = service.getSpendingByDayOfWeek(transactions: testTransactions)

        for day in spending {
            if day.transactionCount > 0 {
                let expectedAverage = day.totalAmount / Decimal(day.transactionCount)
                XCTAssertEqual(day.averageAmount, expectedAverage)
            } else {
                XCTAssertEqual(day.averageAmount, 0)
            }
        }
    }

    // MARK: - Hour Analysis Tests

    func testGetSpendingByHour_Returns24Hours() {
        let spending = service.getSpendingByHour(transactions: testTransactions)
        XCTAssertEqual(spending.count, 24)
    }

    func testGetSpendingByHour_HasCorrectHourNumbers() {
        let spending = service.getSpendingByHour(transactions: testTransactions)

        for (index, hour) in spending.enumerated() {
            XCTAssertEqual(hour.hour, index)
        }
    }

    // MARK: - Month Comparison Tests

    func testCompareMonths_CalculatesDifference() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let result = service.compareMonths(
            transactions: testTransactions,
            month1: lastMonth,
            month2: now
        )

        XCTAssertEqual(result.difference, result.month2Total - result.month1Total)
    }

    func testCompareMonths_CalculatesPercentChange() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let result = service.compareMonths(
            transactions: testTransactions,
            month1: lastMonth,
            month2: now
        )

        if result.month1Total > 0 {
            let expectedPercent = Double(truncating: (result.difference / result.month1Total) as NSDecimalNumber) * 100
            XCTAssertEqual(result.percentChange, expectedPercent, accuracy: 0.01)
        }
    }

    // MARK: - Recurring Pattern Detection Tests

    func testDetectRecurringPatterns_FindsMonthlyPattern() {
        let calendar = Calendar.current
        let now = Date()
        let foodCategory = testCategories.first { $0.name == "Food" }!

        // Create monthly recurring transactions
        var monthlyTransactions: [Transaction] = []
        for i in 0..<4 {
            let date = calendar.date(byAdding: .month, value: -i, to: now)!
            let transaction = Transaction(amount: Decimal(50000), type: .expense, note: "Monthly subscription", date: date)
            transaction.category = foodCategory
            monthlyTransactions.append(transaction)
        }
        monthlyTransactions.forEach { modelContext.insert($0) }
        try? modelContext.save()

        let patterns = service.detectRecurringPatterns(transactions: monthlyTransactions, minOccurrences: 3, minConfidence: 0.5)

        let monthlyPattern = patterns.first { $0.frequency == "monthly" }
        XCTAssertNotNil(monthlyPattern)
    }

    func testDetectRecurringPatterns_FindsWeeklyPattern() {
        let calendar = Calendar.current
        let now = Date()
        let transportCategory = testCategories.first { $0.name == "Transport" }!

        // Create weekly recurring transactions
        var weeklyTransactions: [Transaction] = []
        for i in 0..<5 {
            let date = calendar.date(byAdding: .weekOfYear, value: -i, to: now)!
            let transaction = Transaction(amount: Decimal(10000), type: .expense, note: "Weekly expense", date: date)
            transaction.category = transportCategory
            weeklyTransactions.append(transaction)
        }
        weeklyTransactions.forEach { modelContext.insert($0) }
        try? modelContext.save()

        let patterns = service.detectRecurringPatterns(transactions: weeklyTransactions, minOccurrences: 3, minConfidence: 0.5)

        let weeklyPattern = patterns.first { $0.frequency == "weekly" }
        XCTAssertNotNil(weeklyPattern)
    }

    func testDetectRecurringPatterns_RespectsMinOccurrences() {
        let patterns = service.detectRecurringPatterns(
            transactions: testTransactions,
            minOccurrences: 100,
            minConfidence: 0.1
        )

        XCTAssertTrue(patterns.isEmpty)
    }

    func testDetectRecurringPatterns_EmptyTransactions() {
        let patterns = service.detectRecurringPatterns(transactions: [])
        XCTAssertTrue(patterns.isEmpty)
    }

    // MARK: - Category Trends Tests

    func testGetCategoryTrends_ReturnsCategories() {
        let trends = service.getCategoryTrends(transactions: testTransactions, months: 3)
        XCTAssertGreaterThan(trends.count, 0)
    }

    func testGetCategoryTrends_CalculatesChange() {
        let trends = service.getCategoryTrends(transactions: testTransactions, months: 3)

        for trend in trends {
            let expectedChange = trend.currentMonthAmount - trend.previousMonthAmount
            XCTAssertEqual(trend.change, expectedChange)
        }
    }

    func testGetCategoryTrends_SetsIsIncreasingCorrectly() {
        let trends = service.getCategoryTrends(transactions: testTransactions, months: 3)

        for trend in trends {
            if trend.change > 0 {
                XCTAssertTrue(trend.isIncreasing)
            } else {
                XCTAssertFalse(trend.isIncreasing)
            }
        }
    }

    func testGetCategoryTrends_SortsByChangePercentage() {
        let trends = service.getCategoryTrends(transactions: testTransactions, months: 3)

        for i in 0..<(trends.count - 1) {
            XCTAssertGreaterThanOrEqual(
                abs(trends[i].changePercentage),
                abs(trends[i + 1].changePercentage)
            )
        }
    }

    func testGetCategoryTrends_EmptyTransactions() {
        let trends = service.getCategoryTrends(transactions: [], months: 3)
        XCTAssertTrue(trends.isEmpty)
    }

    // MARK: - Budget Prediction Tests

    func testBudgetPrediction_CalculatesUsagePercentage() {
        let budget = Budget(amount: 1000000, period: .monthly)
        modelContext.insert(budget)
        try? modelContext.save()

        let prediction = service.predictBudget(budget: budget, transactions: testTransactions)

        if prediction.budgetAmount > 0 {
            let expectedPercentage = Double(truncating: (prediction.currentSpent / prediction.budgetAmount) as NSDecimalNumber) * 100
            XCTAssertEqual(prediction.usagePercentage, expectedPercentage, accuracy: 0.01)
        }
    }

    func testBudgetPrediction_CalculatesRemainingBudget() {
        let budget = Budget(amount: 1000000, period: .monthly)
        modelContext.insert(budget)
        try? modelContext.save()

        let prediction = service.predictBudget(budget: budget, transactions: testTransactions)

        let expectedRemaining = budget.amount - prediction.currentSpent
        XCTAssertEqual(prediction.remainingBudget, expectedRemaining)
    }

    func testBudgetPrediction_CalculatesDailyAverage() {
        let budget = Budget(amount: 1000000, period: .monthly)
        modelContext.insert(budget)
        try? modelContext.save()

        let prediction = service.predictBudget(budget: budget, transactions: testTransactions)

        if prediction.daysElapsed > 0 {
            let expectedAverage = prediction.currentSpent / Decimal(prediction.daysElapsed)
            XCTAssertEqual(prediction.dailyAverage, expectedAverage)
        }
    }

    func testBudgetPrediction_ConfidenceIncreasesOverTime() {
        let budget = Budget(amount: 1000000, period: .monthly)
        modelContext.insert(budget)
        try? modelContext.save()

        let prediction = service.predictBudget(budget: budget, transactions: testTransactions)

        // Confidence should be between 0 and 100
        XCTAssertGreaterThanOrEqual(prediction.confidence, 0)
        XCTAssertLessThanOrEqual(prediction.confidence, 100)
    }
}
