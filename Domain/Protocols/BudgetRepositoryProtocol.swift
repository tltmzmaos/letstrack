import Foundation
import SwiftData

// MARK: - Budget Repository Protocol

@MainActor
protocol BudgetRepositoryProtocol {
    // MARK: - CRUD Operations

    func create(
        amount: Decimal,
        period: BudgetPeriod,
        category: Category?
    ) throws -> Budget

    func delete(_ budget: Budget) throws

    func save() throws

    // MARK: - Fetch Operations

    func fetchAll() throws -> [Budget]

    func fetchTotalBudget() throws -> Budget?

    func fetch(for category: Category) throws -> Budget?

    // MARK: - Budget Status

    func budgetStatus(budget: Budget, spent: Decimal) -> BudgetStatus
}
