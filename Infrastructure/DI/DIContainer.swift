import Foundation
import SwiftData

/// Simple Dependency Injection Container
/// Provides repository instances with protocol-based abstraction
@MainActor
final class DIContainer {
    private let modelContext: ModelContext

    // MARK: - Cached Repositories

    private lazy var _transactionRepository: TransactionRepositoryProtocol = {
        TransactionRepository(modelContext: modelContext)
    }()

    private lazy var _categoryRepository: CategoryRepositoryProtocol = {
        CategoryRepository(modelContext: modelContext)
    }()

    private lazy var _budgetRepository: BudgetRepositoryProtocol = {
        BudgetRepository(modelContext: modelContext)
    }()

    private lazy var _recurringTransactionRepository: RecurringTransactionRepositoryProtocol = {
        RecurringTransactionRepository(modelContext: modelContext)
    }()

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Repository Accessors

    var transactionRepository: TransactionRepositoryProtocol {
        _transactionRepository
    }

    var categoryRepository: CategoryRepositoryProtocol {
        _categoryRepository
    }

    var budgetRepository: BudgetRepositoryProtocol {
        _budgetRepository
    }

    var recurringTransactionRepository: RecurringTransactionRepositoryProtocol {
        _recurringTransactionRepository
    }
}
