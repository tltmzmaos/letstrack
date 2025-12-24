import Foundation
import SwiftData

// MARK: - Budget Status

enum BudgetStatus {
    case safe(remaining: Decimal, percentage: Double)
    case warning(remaining: Decimal, percentage: Double)
    case exceeded(overspent: Decimal)

    var isExceeded: Bool {
        if case .exceeded = self { return true }
        return false
    }

    var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }
}

// MARK: - Budget Repository

@MainActor
final class BudgetRepository: BudgetRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    func create(
        amount: Decimal,
        period: BudgetPeriod,
        category: Category?
    ) throws -> Budget {
        let budget = Budget(
            amount: amount,
            period: period,
            category: category
        )
        modelContext.insert(budget)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
        return budget
    }

    func delete(_ budget: Budget) throws {
        modelContext.delete(budget)
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

    func fetchAll() throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>()
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetchTotalBudget() throws -> Budget? {
        let predicate = #Predicate<Budget> { budget in
            budget.category == nil
        }

        let descriptor = FetchDescriptor<Budget>(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(for category: Category) throws -> Budget? {
        let categoryId = category.id

        let predicate = #Predicate<Budget> { budget in
            budget.category?.id == categoryId
        }

        let descriptor = FetchDescriptor<Budget>(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Budget Status

    func budgetStatus(budget: Budget, spent: Decimal) -> BudgetStatus {
        let remaining = budget.amount - spent
        let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0

        if remaining < 0 {
            return .exceeded(overspent: -remaining)
        } else if percentage >= 80 {
            return .warning(remaining: remaining, percentage: percentage.doubleValue)
        } else {
            return .safe(remaining: remaining, percentage: percentage.doubleValue)
        }
    }
}
