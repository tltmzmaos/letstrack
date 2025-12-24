import XCTest
import SwiftData
@testable import LetsTrack

// MARK: - TransactionRepository Tests

@MainActor
final class TransactionRepositoryTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: TransactionRepository!

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
        repository = TransactionRepository(modelContext: modelContext)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
    }

    // MARK: - CRUD Tests

    func testCreate() throws {
        let transaction = try repository.create(
            amount: 10000,
            type: .expense,
            category: nil,
            note: "테스트",
            date: Date()
        )

        XCTAssertEqual(transaction.amount, 10000)
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.note, "테스트")
    }

    func testDelete() throws {
        let transaction = try repository.create(
            amount: 10000,
            type: .expense,
            category: nil,
            note: "삭제 테스트",
            date: Date()
        )

        try repository.delete(transaction)

        let allTransactions = try repository.fetchAll()
        XCTAssertTrue(allTransactions.isEmpty)
    }

    func testFetchAll() throws {
        _ = try repository.create(amount: 10000, type: .expense, category: nil, note: "거래1", date: Date())
        _ = try repository.create(amount: 20000, type: .income, category: nil, note: "거래2", date: Date())
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "거래3", date: Date())

        let allTransactions = try repository.fetchAll()
        XCTAssertEqual(allTransactions.count, 3)
    }

    func testFetchForDate() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        _ = try repository.create(amount: 10000, type: .expense, category: nil, note: "오늘 거래", date: today)
        _ = try repository.create(amount: 20000, type: .expense, category: nil, note: "어제 거래", date: yesterday)

        let todayTransactions = try repository.fetch(for: today)
        XCTAssertEqual(todayTransactions.count, 1)
        XCTAssertEqual(todayTransactions.first?.note, "오늘 거래")
    }

    func testFetchDateRange() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!

        _ = try repository.create(amount: 10000, type: .expense, category: nil, note: "오늘", date: today)
        _ = try repository.create(amount: 20000, type: .expense, category: nil, note: "어제", date: yesterday)
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "지난주", date: lastWeek)

        let recentTransactions = try repository.fetch(from: yesterday, to: today)
        XCTAssertEqual(recentTransactions.count, 2)
    }

    func testSearch() throws {
        _ = try repository.create(amount: 10000, type: .expense, category: nil, note: "스타벅스 커피", date: Date())
        _ = try repository.create(amount: 20000, type: .expense, category: nil, note: "이디야 아메리카노", date: Date())
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "치킨", date: Date())

        let coffeeResults = try repository.search(query: "커피")
        XCTAssertEqual(coffeeResults.count, 1)
        XCTAssertEqual(coffeeResults.first?.note, "스타벅스 커피")
    }

    // MARK: - Statistics Tests

    func testTotalIncome() throws {
        let today = Date()
        let startOfMonth = today.startOfMonth
        let endOfMonth = today.endOfMonth

        _ = try repository.create(amount: 100000, type: .income, category: nil, note: "급여", date: today)
        _ = try repository.create(amount: 50000, type: .income, category: nil, note: "용돈", date: today)
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "지출", date: today)

        let totalIncome = try repository.totalIncome(from: startOfMonth, to: endOfMonth)
        XCTAssertEqual(totalIncome, 150000)
    }

    func testTotalExpense() throws {
        let today = Date()
        let startOfMonth = today.startOfMonth
        let endOfMonth = today.endOfMonth

        _ = try repository.create(amount: 100000, type: .income, category: nil, note: "급여", date: today)
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "식비", date: today)
        _ = try repository.create(amount: 20000, type: .expense, category: nil, note: "교통비", date: today)

        let totalExpense = try repository.totalExpense(from: startOfMonth, to: endOfMonth)
        XCTAssertEqual(totalExpense, 50000)
    }

    func testBalance() throws {
        let today = Date()
        let startOfMonth = today.startOfMonth
        let endOfMonth = today.endOfMonth

        _ = try repository.create(amount: 100000, type: .income, category: nil, note: "급여", date: today)
        _ = try repository.create(amount: 30000, type: .expense, category: nil, note: "지출", date: today)

        let balance = try repository.balance(from: startOfMonth, to: endOfMonth)
        XCTAssertEqual(balance, 70000)
    }

    func testTotalBalance() throws {
        _ = try repository.create(amount: 1000000, type: .income, category: nil, note: "급여", date: Date())
        _ = try repository.create(amount: 300000, type: .expense, category: nil, note: "월세", date: Date())
        _ = try repository.create(amount: 200000, type: .expense, category: nil, note: "생활비", date: Date())

        let totalBalance = try repository.totalBalance()
        XCTAssertEqual(totalBalance, 500000)
    }

    func testExpenseByCategory() throws {
        let foodCategory = AppCategory(name: "음식", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let transportCategory = AppCategory(name: "교통", icon: "car.fill", colorHex: "#34C759", type: .expense)

        modelContext.insert(foodCategory)
        modelContext.insert(transportCategory)
        try modelContext.save()

        let today = Date()
        let t1 = try repository.create(amount: 10000, type: .expense, category: nil, note: "점심", date: today)
        t1.category = foodCategory
        let t2 = try repository.create(amount: 15000, type: .expense, category: nil, note: "저녁", date: today)
        t2.category = foodCategory
        let t3 = try repository.create(amount: 5000, type: .expense, category: nil, note: "택시", date: today)
        t3.category = transportCategory
        try modelContext.save()

        let categoryExpenses = try repository.expenseByCategory(from: today.startOfMonth, to: today.endOfMonth)

        XCTAssertEqual(categoryExpenses.count, 2)

        let foodExpense = categoryExpenses.first { $0.category.name == "음식" }
        XCTAssertEqual(foodExpense?.amount, 25000)

        let transportExpense = categoryExpenses.first { $0.category.name == "교통" }
        XCTAssertEqual(transportExpense?.amount, 5000)
    }
}

// MARK: - CategoryRepository Tests

@MainActor
final class CategoryRepositoryTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: CategoryRepository!

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
        repository = CategoryRepository(modelContext: modelContext)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
    }

    func testCreate() throws {
        let category = try repository.create(
            name: "테스트 카테고리",
            icon: "star.fill",
            colorHex: "#FF0000",
            type: .expense
        )

        XCTAssertEqual(category.name, "테스트 카테고리")
        XCTAssertEqual(category.icon, "star.fill")
        XCTAssertEqual(category.type, .expense)
    }

    func testCreateWithAutoSortOrder() throws {
        _ = try repository.create(name: "카테고리1", icon: "1.circle", colorHex: "#111111", type: .expense)
        _ = try repository.create(name: "카테고리2", icon: "2.circle", colorHex: "#222222", type: .expense)
        let category3 = try repository.create(name: "카테고리3", icon: "3.circle", colorHex: "#333333", type: .expense)

        XCTAssertEqual(category3.sortOrder, 2)
    }

    func testDelete() throws {
        let category = try repository.create(
            name: "삭제할 카테고리",
            icon: "trash",
            colorHex: "#FF0000",
            type: .expense
        )

        try repository.delete(category)

        let allCategories = try repository.fetchAll()
        XCTAssertTrue(allCategories.isEmpty)
    }

    func testFetchAll() throws {
        _ = try repository.create(name: "카테고리1", icon: "1.circle", colorHex: "#111111", type: .expense)
        _ = try repository.create(name: "카테고리2", icon: "2.circle", colorHex: "#222222", type: .income)

        let allCategories = try repository.fetchAll()
        XCTAssertEqual(allCategories.count, 2)
    }

    func testSetupDefaultCategoriesIfNeeded() throws {
        try repository.setupDefaultCategoriesIfNeeded()

        let allCategories = try repository.fetchAll()
        XCTAssertEqual(allCategories.count, 13) // 9 expense + 4 income
    }

    func testSetupDefaultCategoriesOnlyOnce() throws {
        try repository.setupDefaultCategoriesIfNeeded()
        try repository.setupDefaultCategoriesIfNeeded()

        let allCategories = try repository.fetchAll()
        XCTAssertEqual(allCategories.count, 13)
    }
}

// MARK: - BudgetRepository Tests

@MainActor
final class BudgetRepositoryTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: BudgetRepository!

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
        repository = BudgetRepository(modelContext: modelContext)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
    }

    func testCreate() throws {
        let budget = try repository.create(
            amount: 500000,
            period: .monthly,
            category: nil
        )

        XCTAssertEqual(budget.amount, 500000)
        XCTAssertEqual(budget.period, .monthly)
        XCTAssertNil(budget.category)
    }

    func testCreateWithCategory() throws {
        let category = AppCategory(
            name: "음식",
            icon: "fork.knife",
            colorHex: "#FF9500",
            type: .expense
        )
        modelContext.insert(category)
        try modelContext.save()

        let budget = try repository.create(
            amount: 200000,
            period: .monthly,
            category: nil
        )
        budget.category = category
        try modelContext.save()

        XCTAssertNotNil(budget.category)
        XCTAssertEqual(budget.category?.name, "음식")
    }

    func testDelete() throws {
        let budget = try repository.create(amount: 300000, period: .monthly, category: nil)

        try repository.delete(budget)

        let allBudgets = try repository.fetchAll()
        XCTAssertTrue(allBudgets.isEmpty)
    }

    func testFetchTotalBudget() throws {
        _ = try repository.create(amount: 500000, period: .monthly, category: nil)

        let category = AppCategory(name: "음식", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        modelContext.insert(category)
        try modelContext.save()
        let categoryBudget = try repository.create(amount: 200000, period: .monthly, category: nil)
        categoryBudget.category = category
        try modelContext.save()

        let totalBudget = try repository.fetchTotalBudget()
        XCTAssertNotNil(totalBudget)
        XCTAssertEqual(totalBudget?.amount, 500000)
        XCTAssertNil(totalBudget?.category)
    }

    func testFetchForCategory() throws {
        let category = AppCategory(name: "음식", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        modelContext.insert(category)
        try modelContext.save()

        let budget = try repository.create(amount: 200000, period: .monthly, category: nil)
        budget.category = category
        try modelContext.save()

        let fetchedBudget = try repository.fetch(for: category)
        XCTAssertNotNil(fetchedBudget)
        XCTAssertEqual(fetchedBudget?.amount, 200000)
    }

    // MARK: - Budget Status Tests

    func testBudgetStatus_Safe() throws {
        let budget = Budget(amount: 500000, period: .monthly)
        let spent: Decimal = 200000

        let status = repository.budgetStatus(budget: budget, spent: spent)

        if case .safe(let remaining, let percentage) = status {
            XCTAssertEqual(remaining, 300000)
            XCTAssertEqual(percentage, 40.0)
        } else {
            XCTFail("Expected safe status")
        }
    }

    func testBudgetStatus_Warning() throws {
        let budget = Budget(amount: 500000, period: .monthly)
        let spent: Decimal = 450000

        let status = repository.budgetStatus(budget: budget, spent: spent)

        if case .warning(let remaining, let percentage) = status {
            XCTAssertEqual(remaining, 50000)
            XCTAssertEqual(percentage, 90.0)
        } else {
            XCTFail("Expected warning status")
        }

        XCTAssertTrue(status.isWarning)
        XCTAssertFalse(status.isExceeded)
    }

    func testBudgetStatus_Exceeded() throws {
        let budget = Budget(amount: 500000, period: .monthly)
        let spent: Decimal = 600000

        let status = repository.budgetStatus(budget: budget, spent: spent)

        if case .exceeded(let overspent) = status {
            XCTAssertEqual(overspent, 100000)
        } else {
            XCTFail("Expected exceeded status")
        }

        XCTAssertTrue(status.isExceeded)
        XCTAssertFalse(status.isWarning)
    }

    func testBudgetStatus_EdgeCase80Percent() throws {
        let budget = Budget(amount: 100000, period: .monthly)
        let spent: Decimal = 80000

        let status = repository.budgetStatus(budget: budget, spent: spent)

        XCTAssertTrue(status.isWarning)
    }
}
