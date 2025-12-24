import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var amount: Decimal
    var period: BudgetPeriod
    var startDate: Date

    var category: Category?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        category: Category? = nil,
        startDate: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.period = period
        self.category = category
        self.startDate = startDate
    }
}

// MARK: - Budget Extensions

extension Budget {
    var currentPeriodDates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now
            return (weekStart, weekEnd)

        case .monthly:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? now
            return (monthStart, monthEnd)

        case .yearly:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart) ?? now
            return (yearStart, yearEnd)
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .weekly:
            return String(localized: "budget.period.weekly")
        case .monthly:
            return String(localized: "budget.period.monthly")
        case .yearly:
            return String(localized: "budget.period.yearly")
        }
    }
}
