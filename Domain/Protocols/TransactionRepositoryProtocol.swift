import Foundation
import SwiftData

// MARK: - Repository Error

enum RepositoryError: Error, LocalizedError {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case notFound
    case invalidData(reason: String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return String(localized: "error.save_failed")
        case .fetchFailed:
            return String(localized: "error.fetch_failed")
        case .deleteFailed:
            return String(localized: "error.delete_failed")
        case .notFound:
            return String(localized: "error.not_found")
        case .invalidData(let reason):
            return String(localized: "error.invalid_data \(reason)")
        }
    }
}

// MARK: - Transaction Repository Protocol

@MainActor
protocol TransactionRepositoryProtocol {
    // MARK: - CRUD Operations

    func create(
        amount: Decimal,
        type: TransactionType,
        category: Category?,
        note: String,
        date: Date,
        currency: Currency,
        receiptImageData: Data?,
        tagNames: [String],
        latitude: Double?,
        longitude: Double?,
        locationName: String?
    ) throws -> Transaction

    func delete(_ transaction: Transaction) throws

    func save() throws

    // MARK: - Fetch Operations

    func fetchAll(sortBy: SortDescriptor<Transaction>) throws -> [Transaction]

    func fetch(for date: Date) throws -> [Transaction]

    func fetch(from startDate: Date, to endDate: Date) throws -> [Transaction]

    func fetchCurrentMonth() throws -> [Transaction]

    func search(query: String) throws -> [Transaction]

    // MARK: - Statistics

    func totalIncome(from startDate: Date, to endDate: Date) throws -> Decimal

    func totalExpense(from startDate: Date, to endDate: Date) throws -> Decimal

    func balance(from startDate: Date, to endDate: Date) throws -> Decimal

    func totalBalance() throws -> Decimal

    func expenseByCategory(from startDate: Date, to endDate: Date) throws -> [(category: Category, amount: Decimal)]
}

// MARK: - Default Parameter Extensions

extension TransactionRepositoryProtocol {
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
        try create(
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
    }

    func fetchAll() throws -> [Transaction] {
        try fetchAll(sortBy: SortDescriptor(\.date, order: .reverse))
    }
}
