import Foundation
import SwiftData

@MainActor
final class AppDataPreloader {
    static let shared = AppDataPreloader()

    private(set) var categories: [Category] = []
    private(set) var tags: [Tag] = []
    private(set) var transactions: [Transaction] = []
    private var didPreload = false

    func preload(using modelContext: ModelContext) {
        guard !didPreload else { return }
        didPreload = true
        refresh(using: modelContext)
    }

    func refresh(using modelContext: ModelContext) {
        refreshCategories(using: modelContext)
        refreshTags(using: modelContext)
        refreshTransactions(using: modelContext)
    }

    func refreshCategories(using modelContext: ModelContext) {
        let categoryRepo = CategoryRepository(modelContext: modelContext)
        categories = (try? categoryRepo.fetchAll()) ?? []
    }

    func refreshTags(using modelContext: ModelContext) {
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        tags = (try? modelContext.fetch(tagDescriptor)) ?? []
    }

    func refreshTransactions(using modelContext: ModelContext) {
        let transactionRepo = TransactionRepository(modelContext: modelContext)
        transactions = (try? transactionRepo.fetchAll()) ?? []
    }

    func updateCategories(_ categories: [Category]) {
        self.categories = categories
    }

    func updateTags(_ tags: [Tag]) {
        self.tags = tags
    }

    func updateTransactions(_ transactions: [Transaction]) {
        self.transactions = transactions
    }
}
