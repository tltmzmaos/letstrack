import Foundation
import SwiftData

// MARK: - Category Repository Protocol

@MainActor
protocol CategoryRepositoryProtocol {
    // MARK: - CRUD Operations

    func create(
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool
    ) throws -> Category

    func delete(_ category: Category) throws

    func save() throws

    // MARK: - Fetch Operations

    func fetchAll() throws -> [Category]

    func fetchAll(for type: TransactionType) throws -> [Category]

    func fetchDefaults() throws -> [Category]

    // MARK: - Setup

    func setupDefaultCategoriesIfNeeded() throws
}

// MARK: - Default Parameter Extensions

extension CategoryRepositoryProtocol {
    func create(
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool = false
    ) throws -> Category {
        try create(
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            isDefault: isDefault
        )
    }
}
