import XCTest
import SwiftData
@testable import LetsTrack

@MainActor
final class BackupServiceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            RecurringTransaction.self,
            SavingsGoal.self,
            Wallet.self,
            Tag.self,
            TransactionTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
    }

    func testExportImport_RoundTripCountsAndRelationships() throws {
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let wallet = Wallet(name: "Main", icon: "wallet.pass", colorHex: "#007AFF", balance: 100000, isDefault: true)
        let tag = Tag(name: "lunch", colorHex: "#FF2D55")
        let budget = Budget(amount: 200000, period: .monthly, category: category, startDate: Date())
        let goal = SavingsGoal(name: "Trip", targetAmount: 1000000, currentAmount: 250000, deadline: nil, icon: "airplane", colorHex: "#5856D6", note: "Summer")

        modelContext.insert(category)
        modelContext.insert(wallet)
        modelContext.insert(tag)
        modelContext.insert(budget)
        modelContext.insert(goal)

        let transaction = Transaction(
            amount: 12000,
            type: .expense,
            category: category,
            wallet: wallet,
            note: "Lunch",
            date: Date(),
            currency: .krw,
            tagNames: [tag.name]
        )
        modelContext.insert(transaction)
        try modelContext.save()

        let data = try BackupService.shared.exportBackup(modelContext: modelContext)

        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            RecurringTransaction.self,
            SavingsGoal.self,
            Wallet.self,
            Tag.self,
            TransactionTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let importContext = importContainer.mainContext

        let result = try BackupService.shared.importBackup(from: data, modelContext: importContext)

        XCTAssertEqual(result.transactionsImported, 1)
        XCTAssertEqual(result.categoriesImported, 1)
        XCTAssertEqual(result.walletsImported, 1)
        XCTAssertEqual(result.budgetsImported, 1)
        XCTAssertEqual(result.savingsGoalsImported, 1)
        XCTAssertEqual(result.tagsImported, 1)

        let importedTransactions = try importContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(importedTransactions.count, 1)
        XCTAssertEqual(importedTransactions.first?.note, "Lunch")
        XCTAssertEqual(importedTransactions.first?.category?.name, "Food")
        XCTAssertEqual(importedTransactions.first?.wallet?.name, "Main")
    }

    func testImport_EmptyBackupProducesZeroCounts() throws {
        let backup = BackupData(
            version: "2.0",
            createdAt: Date(),
            transactions: [],
            categories: [],
            budgets: [],
            savingsGoals: [],
            wallets: [],
            tags: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let result = try BackupService.shared.importBackup(from: data, modelContext: modelContext)

        XCTAssertEqual(result.totalImported, 0)
        XCTAssertTrue(result.summary.contains("0 transactions"))
    }
}
