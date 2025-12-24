import XCTest
import SwiftData
@testable import LetsTrack

@MainActor
final class AppDataPreloaderTests: XCTestCase {
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

        AppDataPreloader.shared.updateCategories([])
        AppDataPreloader.shared.updateTags([])
        AppDataPreloader.shared.updateTransactions([])
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        AppDataPreloader.shared.updateCategories([])
        AppDataPreloader.shared.updateTags([])
        AppDataPreloader.shared.updateTransactions([])
    }

    func testRefreshLoadsCategoriesTagsAndTransactions() throws {
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense)
        let tag = Tag(name: "coffee", colorHex: "#FF2D55")
        let transaction = Transaction(amount: 5000, type: .expense, category: category, note: "Cafe", currency: .krw)

        modelContext.insert(category)
        modelContext.insert(tag)
        modelContext.insert(transaction)
        try modelContext.save()

        AppDataPreloader.shared.refresh(using: modelContext)

        XCTAssertEqual(AppDataPreloader.shared.categories.count, 1)
        XCTAssertEqual(AppDataPreloader.shared.tags.count, 1)
        XCTAssertEqual(AppDataPreloader.shared.transactions.count, 1)
    }

    func testUpdateMethodsOverrideCaches() {
        let category = Category(name: "Temp", icon: "star", colorHex: "#FF9500", type: .expense)
        let tag = Tag(name: "temp", colorHex: "#FF9500")
        let transaction = Transaction(amount: 1, type: .expense, note: "Temp", currency: .krw)

        AppDataPreloader.shared.updateCategories([category])
        AppDataPreloader.shared.updateTags([tag])
        AppDataPreloader.shared.updateTransactions([transaction])

        XCTAssertEqual(AppDataPreloader.shared.categories.first?.name, "Temp")
        XCTAssertEqual(AppDataPreloader.shared.tags.first?.name, "temp")
        XCTAssertEqual(AppDataPreloader.shared.transactions.first?.note, "Temp")
    }
}
