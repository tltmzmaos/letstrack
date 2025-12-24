import Foundation
import SwiftData

@MainActor
final class RecurringTransactionRepository: RecurringTransactionRepositoryProtocol {
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
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date? = nil
    ) throws -> RecurringTransaction {
        let recurring = RecurringTransaction(
            amount: amount,
            type: type,
            category: category,
            note: note,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate
        )
        modelContext.insert(recurring)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
        return recurring
    }

    func delete(_ recurring: RecurringTransaction) throws {
        modelContext.delete(recurring)
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

    func fetchAll() throws -> [RecurringTransaction] {
        var descriptor = FetchDescriptor<RecurringTransaction>()
        descriptor.sortBy = [SortDescriptor(\.nextDueDate)]
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetchActive() throws -> [RecurringTransaction] {
        let predicate = #Predicate<RecurringTransaction> { recurring in
            recurring.isActive == true
        }

        var descriptor = FetchDescriptor<RecurringTransaction>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.nextDueDate)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetchDue(on date: Date = Date()) throws -> [RecurringTransaction] {
        let activeRecurrings = try fetchActive()
        return activeRecurrings.filter { $0.shouldProcess(on: date) }
    }

    // MARK: - Process Recurring Transactions

    func processAllDue(transactionRepository: TransactionRepositoryProtocol) throws -> [Transaction] {
        let dueRecurrings = try fetchDue()
        var createdTransactions: [Transaction] = []

        for recurring in dueRecurrings {
            let transaction = try transactionRepository.create(
                amount: recurring.amount,
                type: recurring.type,
                category: recurring.category,
                note: recurring.note + " (\(String(localized: "recurring.auto_generated")))",
                date: recurring.nextDueDate,
                currency: .krw,
                receiptImageData: nil
            )
            createdTransactions.append(transaction)

            recurring.lastProcessedDate = recurring.nextDueDate
            recurring.nextDueDate = recurring.calculateNextDueDate()

            if let endDate = recurring.endDate, recurring.nextDueDate > endDate {
                recurring.isActive = false
            }
        }

        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
        return createdTransactions
    }
}
