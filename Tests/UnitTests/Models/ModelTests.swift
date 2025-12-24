import XCTest
import SwiftData
@testable import LetsTrack

// Type alias to avoid ambiguity with Foundation.Category
typealias AppCategory = LetsTrack.Category

@MainActor
final class TransactionModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Transaction.self,
            AppCategory.self,
            Budget.self,
            RecurringTransaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Transaction Tests

    func testTransactionCreation() throws {
        let transaction = Transaction(
            amount: 10000,
            type: .expense,
            note: "테스트 지출"
        )

        XCTAssertEqual(transaction.amount, 10000)
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.note, "테스트 지출")
        XCTAssertNotNil(transaction.id)
        XCTAssertNotNil(transaction.createdAt)
    }

    func testTransactionSignedAmount_Expense() throws {
        let expense = Transaction(amount: 5000, type: .expense)
        XCTAssertEqual(expense.signedAmount, -5000)
    }

    func testTransactionSignedAmount_Income() throws {
        let income = Transaction(amount: 100000, type: .income)
        XCTAssertEqual(income.signedAmount, 100000)
    }

    func testTransactionUpdate() throws {
        let transaction = Transaction(amount: 10000, type: .expense, note: "원래 메모")
        let originalUpdatedAt = transaction.updatedAt

        Thread.sleep(forTimeInterval: 0.01)

        transaction.update(amount: 20000, note: "수정된 메모")

        XCTAssertEqual(transaction.amount, 20000)
        XCTAssertEqual(transaction.note, "수정된 메모")
        XCTAssertGreaterThan(transaction.updatedAt, originalUpdatedAt)
    }

    func testTransactionWithCategory() throws {
        let category = AppCategory(
            name: "음식",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        modelContext.insert(category)
        try modelContext.save()

        let transaction = Transaction(
            amount: 15000,
            type: .expense,
            note: "점심 식사"
        )
        modelContext.insert(transaction)
        transaction.category = category
        try modelContext.save()

        XCTAssertNotNil(transaction.category)
        XCTAssertEqual(transaction.category?.name, "음식")
    }
}

// MARK: - Category Model Tests

@MainActor
final class CategoryModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Transaction.self,
            AppCategory.self,
            Budget.self,
            RecurringTransaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    func testCategoryCreation() throws {
        let category = AppCategory(
            name: "쇼핑",
            icon: "bag.fill",
            colorHex: "#FF2D55",
            type: .expense,
            isDefault: true,
            sortOrder: 0
        )

        XCTAssertEqual(category.name, "쇼핑")
        XCTAssertEqual(category.icon, "bag.fill")
        XCTAssertEqual(category.colorHex, "#FF2D55")
        XCTAssertEqual(category.type, .expense)
        XCTAssertTrue(category.isDefault)
        XCTAssertEqual(category.sortOrder, 0)
    }

    func testCategoryColor() throws {
        let category = AppCategory(
            name: "교통",
            icon: "car.fill",
            colorHex: "#34C759",
            type: .expense
        )

        XCTAssertNotNil(category.color)
    }

    func testDefaultExpenseCategories() throws {
        let defaults = AppCategory.defaultExpenseCategories

        XCTAssertEqual(defaults.count, 9)
        XCTAssertEqual(defaults[0].nameKey, "category.food")
        XCTAssertEqual(defaults[1].nameKey, "category.shopping")
        XCTAssertEqual(defaults[8].nameKey, "category.other")
    }

    func testDefaultIncomeCategories() throws {
        let defaults = AppCategory.defaultIncomeCategories

        XCTAssertEqual(defaults.count, 4)
        XCTAssertEqual(defaults[0].nameKey, "category.salary")
        XCTAssertEqual(defaults[1].nameKey, "category.side_income")
    }

    func testCreateDefaultCategories() throws {
        AppCategory.createDefaultCategories(context: modelContext)

        let descriptor = FetchDescriptor<AppCategory>()
        let categories = try modelContext.fetch(descriptor)

        XCTAssertEqual(categories.count, 13) // 9 expense + 4 income

        let expenseCategories = categories.filter { $0.type == .expense }
        let incomeCategories = categories.filter { $0.type == .income }

        XCTAssertEqual(expenseCategories.count, 9)
        XCTAssertEqual(incomeCategories.count, 4)
    }

    func testCreateDefaultCategoriesOnlyOnce() throws {
        AppCategory.createDefaultCategories(context: modelContext)
        AppCategory.createDefaultCategories(context: modelContext)

        let descriptor = FetchDescriptor<AppCategory>()
        let categories = try modelContext.fetch(descriptor)

        XCTAssertEqual(categories.count, 13)
    }
}

// MARK: - Budget Model Tests

@MainActor
final class BudgetModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Transaction.self,
            AppCategory.self,
            Budget.self,
            RecurringTransaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    func testBudgetCreation() throws {
        let budget = Budget(
            amount: 500000,
            period: .monthly
        )

        XCTAssertEqual(budget.amount, 500000)
        XCTAssertEqual(budget.period, .monthly)
        XCTAssertNil(budget.category)
    }

    func testBudgetWithCategory() throws {
        let category = AppCategory(
            name: "음식",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        modelContext.insert(category)
        try modelContext.save()

        let budget = Budget(
            amount: 200000,
            period: .monthly
        )
        modelContext.insert(budget)
        budget.category = category
        try modelContext.save()

        XCTAssertNotNil(budget.category)
        XCTAssertEqual(budget.category?.name, "음식")
    }

    func testBudgetPeriodDisplayName() throws {
        // DisplayName uses localized strings, just verify they are not empty
        XCTAssertFalse(BudgetPeriod.weekly.displayName.isEmpty)
        XCTAssertFalse(BudgetPeriod.monthly.displayName.isEmpty)
        XCTAssertFalse(BudgetPeriod.yearly.displayName.isEmpty)
    }
}

// MARK: - RecurringTransaction Model Tests

@MainActor
final class RecurringTransactionModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Transaction.self,
            AppCategory.self,
            Budget.self,
            RecurringTransaction.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    func testRecurringTransactionCreation() throws {
        let recurring = RecurringTransaction(
            amount: 50000,
            type: .expense,
            note: "월 구독료",
            frequency: .monthly
        )

        XCTAssertEqual(recurring.amount, 50000)
        XCTAssertEqual(recurring.type, .expense)
        XCTAssertEqual(recurring.note, "월 구독료")
        XCTAssertEqual(recurring.frequency, .monthly)
        XCTAssertTrue(recurring.isActive)
        XCTAssertNil(recurring.lastProcessedDate)
    }

    func testCalculateNextDueDate_Daily() throws {
        let startDate = Date()
        let recurring = RecurringTransaction(
            amount: 5000,
            type: .expense,
            frequency: .daily,
            startDate: startDate
        )

        let nextDate = recurring.calculateNextDueDate()
        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

        XCTAssertEqual(Calendar.current.isDate(nextDate, inSameDayAs: expectedDate), true)
    }

    func testCalculateNextDueDate_Weekly() throws {
        let startDate = Date()
        let recurring = RecurringTransaction(
            amount: 10000,
            type: .expense,
            frequency: .weekly,
            startDate: startDate
        )

        let nextDate = recurring.calculateNextDueDate()
        let expectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: startDate)!

        XCTAssertEqual(Calendar.current.isDate(nextDate, inSameDayAs: expectedDate), true)
    }

    func testCalculateNextDueDate_Biweekly() throws {
        let startDate = Date()
        let recurring = RecurringTransaction(
            amount: 20000,
            type: .expense,
            frequency: .biweekly,
            startDate: startDate
        )

        let nextDate = recurring.calculateNextDueDate()
        let expectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: startDate)!

        XCTAssertEqual(Calendar.current.isDate(nextDate, inSameDayAs: expectedDate), true)
    }

    func testCalculateNextDueDate_Monthly() throws {
        let startDate = Date()
        let recurring = RecurringTransaction(
            amount: 100000,
            type: .expense,
            frequency: .monthly,
            startDate: startDate
        )

        let nextDate = recurring.calculateNextDueDate()
        let expectedDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        XCTAssertEqual(Calendar.current.isDate(nextDate, inSameDayAs: expectedDate), true)
    }

    func testCalculateNextDueDate_Yearly() throws {
        let startDate = Date()
        let recurring = RecurringTransaction(
            amount: 120000,
            type: .expense,
            frequency: .yearly,
            startDate: startDate
        )

        let nextDate = recurring.calculateNextDueDate()
        let expectedDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!

        XCTAssertEqual(Calendar.current.isDate(nextDate, inSameDayAs: expectedDate), true)
    }

    func testShouldProcess_Active() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let recurring = RecurringTransaction(
            amount: 50000,
            type: .expense,
            frequency: .monthly,
            startDate: pastDate
        )

        XCTAssertTrue(recurring.shouldProcess())
    }

    func testShouldProcess_Inactive() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let recurring = RecurringTransaction(
            amount: 50000,
            type: .expense,
            frequency: .monthly,
            startDate: pastDate
        )
        recurring.isActive = false

        XCTAssertFalse(recurring.shouldProcess())
    }

    func testShouldProcess_FutureStartDate() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let recurring = RecurringTransaction(
            amount: 50000,
            type: .expense,
            frequency: .monthly,
            startDate: futureDate
        )

        XCTAssertFalse(recurring.shouldProcess())
    }

    func testShouldProcess_PastEndDate() throws {
        let pastDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        let recurring = RecurringTransaction(
            amount: 50000,
            type: .expense,
            frequency: .monthly,
            startDate: pastDate,
            endDate: endDate
        )

        XCTAssertFalse(recurring.shouldProcess())
    }

    func testRecurringFrequencyDisplayName() throws {
        // DisplayName uses localized strings, just verify they are not empty
        XCTAssertFalse(RecurringFrequency.daily.displayName.isEmpty)
        XCTAssertFalse(RecurringFrequency.weekly.displayName.isEmpty)
        XCTAssertFalse(RecurringFrequency.biweekly.displayName.isEmpty)
        XCTAssertFalse(RecurringFrequency.monthly.displayName.isEmpty)
        XCTAssertFalse(RecurringFrequency.yearly.displayName.isEmpty)
    }
}

// MARK: - TransactionType Tests

final class TransactionTypeTests: XCTestCase {
    func testTransactionTypeDisplayName() throws {
        // DisplayName uses localized strings, just verify they are not empty
        XCTAssertFalse(TransactionType.income.displayName.isEmpty)
        XCTAssertFalse(TransactionType.expense.displayName.isEmpty)
    }

    func testTransactionTypeIcon() throws {
        XCTAssertEqual(TransactionType.income.icon, "arrow.down.circle.fill")
        XCTAssertEqual(TransactionType.expense.icon, "arrow.up.circle.fill")
    }

    func testTransactionTypeRawValue() throws {
        XCTAssertEqual(TransactionType.income.rawValue, "income")
        XCTAssertEqual(TransactionType.expense.rawValue, "expense")
    }
}
