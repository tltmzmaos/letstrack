import Foundation
import SwiftData

@Model
final class RecurringTransaction {
    var id: UUID
    var amount: Decimal
    var type: TransactionType
    var note: String
    var frequency: RecurringFrequency
    var startDate: Date
    var endDate: Date?
    var nextDueDate: Date
    var isActive: Bool
    var lastProcessedDate: Date?
    var createdAt: Date

    var category: Category?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        category: Category? = nil,
        note: String = "",
        frequency: RecurringFrequency,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.nextDueDate = startDate
        self.isActive = true
        self.lastProcessedDate = nil
        self.createdAt = Date()
    }

    func calculateNextDueDate() -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: nextDueDate) ?? nextDueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: nextDueDate) ?? nextDueDate
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: nextDueDate) ?? nextDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
        }
    }

    func shouldProcess(on date: Date = Date()) -> Bool {
        guard isActive else { return false }

        if let endDate = endDate, date > endDate {
            return false
        }

        return date >= nextDueDate
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .daily:
            return String(localized: "recurring.frequency.daily")
        case .weekly:
            return String(localized: "recurring.frequency.weekly")
        case .biweekly:
            return String(localized: "recurring.frequency.biweekly")
        case .monthly:
            return String(localized: "recurring.frequency.monthly")
        case .yearly:
            return String(localized: "recurring.frequency.yearly")
        }
    }
}
