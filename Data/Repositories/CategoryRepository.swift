import Foundation
import SwiftData

@MainActor
final class CategoryRepository: CategoryRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    func create(
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool = false
    ) throws -> Category {
        let maxSortOrder = (try? fetchAll(for: type).map(\.sortOrder).max()) ?? -1

        let category = Category(
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            isDefault: isDefault,
            sortOrder: maxSortOrder + 1
        )
        modelContext.insert(category)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
        return category
    }

    func delete(_ category: Category) throws {
        modelContext.delete(category)
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

    func fetchAll() throws -> [Category] {
        var descriptor = FetchDescriptor<Category>()
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetchAll(for type: TransactionType) throws -> [Category] {
        let allCategories = try fetchAll()
        return allCategories.filter { $0.type == type }
    }

    func fetchDefaults() throws -> [Category] {
        let predicate = #Predicate<Category> { category in
            category.isDefault == true
        }

        var descriptor = FetchDescriptor<Category>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.sortOrder)]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Setup

    func setupDefaultCategoriesIfNeeded() throws {
        let existingCount: Int
        do {
            existingCount = try modelContext.fetchCount(FetchDescriptor<Category>())
        } catch {
            throw RepositoryError.fetchFailed(underlying: error)
        }

        guard existingCount == 0 else { return }

        Category.createDefaultCategories(context: modelContext)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.saveFailed(underlying: error)
        }
    }
}
