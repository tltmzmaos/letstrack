import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var type: TransactionType
    var isDefault: Bool
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budget: Budget?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

// MARK: - Default Categories
extension Category {
    static let defaultExpenseCategories: [(nameKey: String, icon: String, colorHex: String)] = [
        ("category.food", "fork.knife", "#FF9500"),
        ("category.shopping", "bag.fill", "#FF2D55"),
        ("category.transport", "car.fill", "#34C759"),
        ("category.housing", "house.fill", "#AF52DE"),
        ("category.telecom", "phone.fill", "#5856D6"),
        ("category.medical", "cross.case.fill", "#FF3B30"),
        ("category.education", "book.fill", "#007AFF"),
        ("category.entertainment", "gamecontroller.fill", "#FFCC00"),
        ("category.other", "ellipsis.circle.fill", "#8E8E93")
    ]

    static let defaultIncomeCategories: [(nameKey: String, icon: String, colorHex: String)] = [
        ("category.salary", "banknote.fill", "#34C759"),
        ("category.side_income", "plus.circle.fill", "#007AFF"),
        ("category.investment", "chart.line.uptrend.xyaxis", "#FF9500"),
        ("category.other", "ellipsis.circle.fill", "#8E8E93")
    ]

    static func createDefaultCategories(context: ModelContext) {
        // Check if default categories already exist
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.isDefault == true })
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        // Create expense categories
        for (index, cat) in defaultExpenseCategories.enumerated() {
            let category = Category(
                name: String(localized: String.LocalizationValue(cat.nameKey)),
                icon: cat.icon,
                colorHex: cat.colorHex,
                type: .expense,
                isDefault: true,
                sortOrder: index
            )
            context.insert(category)
        }

        // Create income categories
        for (index, cat) in defaultIncomeCategories.enumerated() {
            let category = Category(
                name: String(localized: String.LocalizationValue(cat.nameKey)),
                icon: cat.icon,
                colorHex: cat.colorHex,
                type: .income,
                isDefault: true,
                sortOrder: index
            )
            context.insert(category)
        }

        try? context.save()
    }
}
