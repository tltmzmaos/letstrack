import Foundation

/// Represents a transaction parsed from voice input
struct ParsedTransaction {
    var amount: Decimal?
    var date: Date?
    var suggestedCategoryKeyword: String?
    var note: String?
    var type: TransactionType = .expense

    var isValid: Bool {
        guard let amount = amount else { return false }
        return amount > 0
    }
}
