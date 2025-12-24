import Foundation
import SwiftData

@MainActor
final class TransactionRepository: TransactionRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    func create(
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        note: String,
        date: Date,
        currency: Currency = .usd,
        receiptImageData: Data? = nil,
        tagNames: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) throws -> Transaction {
        let transaction = Transaction(
            amount: amount,
            type: type,
            category: category,
            note: note,
            date: date,
            currency: currency,
            receiptImageData: receiptImageData,
            tagNames: tagNames,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
        modelContext.insert(transaction)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
        return transaction
    }

    func delete(_ transaction: Transaction) throws {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.deleteFailed(underlying: error)
        }
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }

    // MARK: - Fetch Operations

    func fetchAll(sortBy sortDescriptor: SortDescriptor<Transaction> = SortDescriptor(\.date, order: .reverse)) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [sortDescriptor])
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(for date: Date) throws -> [Transaction] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= startOfDay && transaction.date <= endOfDay
        }

        var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(from startDate: Date, to endDate: Date) throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }

        var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetchCurrentMonth() throws -> [Transaction] {
        let now = Date()
        return try fetch(from: now.startOfMonth, to: now.endOfMonth)
    }

    func search(query: String) throws -> [Transaction] {
        let lowercasedQuery = query.lowercased()

        let predicate = #Predicate<Transaction> { transaction in
            transaction.note.localizedStandardContains(lowercasedQuery)
        }

        var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Statistics

    func totalIncome(from startDate: Date, to endDate: Date) throws -> Decimal {
        let transactions = try fetch(from: startDate, to: endDate)
        return transactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func totalExpense(from startDate: Date, to endDate: Date) throws -> Decimal {
        let transactions = try fetch(from: startDate, to: endDate)
        return transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func balance(from startDate: Date, to endDate: Date) throws -> Decimal {
        try totalIncome(from: startDate, to: endDate) - totalExpense(from: startDate, to: endDate)
    }

    func totalBalance() throws -> Decimal {
        let transactions = try fetchAll()
        return transactions.reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    func expenseByCategory(from startDate: Date, to endDate: Date) throws -> [(category: Category, amount: Decimal)] {
        let transactions = try fetch(from: startDate, to: endDate)
            .filter { $0.type == .expense }

        var categoryTotals: [Category: Decimal] = [:]

        for transaction in transactions {
            if let category = transaction.category {
                categoryTotals[category, default: .zero] += transaction.amount
            }
        }

        return categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
