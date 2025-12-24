import Foundation
import SwiftData

@Model
final class TransactionTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0
    var typeRawValue: String = TransactionType.expense.rawValue
    var category: Category?
    var note: String = ""
    var usageCount: Int = 0
    var lastUsedAt: Date?
    var createdAt: Date = Date()

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        amount: Decimal,
        type: TransactionType,
        category: Category? = nil,
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.typeRawValue = type.rawValue
        self.category = category
        self.note = note
        self.usageCount = 0
        self.createdAt = Date()
    }

    // MARK: - Methods

    @MainActor
    func formattedAmount() -> String {
        CurrencySettings.shared.defaultCurrency.format(amount)
    }

    func markAsUsed() {
        usageCount += 1
        lastUsedAt = Date()
    }
}
