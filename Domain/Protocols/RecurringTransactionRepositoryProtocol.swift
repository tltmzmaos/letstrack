import Foundation
import SwiftData

// MARK: - Recurring Transaction Repository Protocol

@MainActor
protocol RecurringTransactionRepositoryProtocol {
    // MARK: - CRUD Operations

    func create(
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        note: String,
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date?
    ) throws -> RecurringTransaction

    func delete(_ recurring: RecurringTransaction) throws

    func save() throws

    // MARK: - Fetch Operations

    func fetchAll() throws -> [RecurringTransaction]

    func fetchActive() throws -> [RecurringTransaction]

    func fetchDue(on date: Date) throws -> [RecurringTransaction]

    // MARK: - Process Recurring Transactions

    func processAllDue(transactionRepository: TransactionRepositoryProtocol) throws -> [Transaction]
}

// MARK: - Default Parameter Extensions

extension RecurringTransactionRepositoryProtocol {
    func create(
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        note: String,
        frequency: RecurringFrequency,
        startDate: Date,
        endDate: Date? = nil
    ) throws -> RecurringTransaction {
        try create(
            amount: amount,
            type: type,
            category: category,
            note: note,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate
        )
    }

    func fetchDue() throws -> [RecurringTransaction] {
        try fetchDue(on: Date())
    }
}
