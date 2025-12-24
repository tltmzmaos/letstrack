import Foundation

enum RecurringProjectionService {
    static func projectedTransactions(
        recurrings: [RecurringTransaction],
        from startDate: Date,
        to endDate: Date,
        currency: Currency
    ) -> [Transaction] {
        let calendar = Calendar.current
        var projections: [Transaction] = []

        for recurring in recurrings where recurring.isActive {
            if let recurringEnd = recurring.endDate, recurringEnd < startDate {
                continue
            }

            var nextDate = recurring.startDate
            while nextDate < startDate {
                nextDate = advance(nextDate, frequency: recurring.frequency, calendar: calendar)
            }

            while nextDate <= endDate {
                if let recurringEnd = recurring.endDate, nextDate > recurringEnd {
                    break
                }

                let autoLabel = String(localized: "recurring.auto_generated")
                let noteSuffix = " (\(autoLabel))"
                let note = recurring.note.isEmpty ? autoLabel : recurring.note + noteSuffix

                let transaction = Transaction(
                    amount: recurring.amount,
                    type: recurring.type,
                    category: recurring.category,
                    note: note,
                    date: nextDate,
                    currency: currency
                )
                projections.append(transaction)

                nextDate = advance(nextDate, frequency: recurring.frequency, calendar: calendar)
            }
        }

        return projections
    }

    private static func advance(_ date: Date, frequency: RecurringFrequency, calendar: Calendar) -> Date {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
