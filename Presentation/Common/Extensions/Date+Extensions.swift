import Foundation

extension Date {
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfYear: Date {
        var components = DateComponents()
        components.year = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfYear) ?? self
    }

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }

    func isSameMonth(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: self) == calendar.component(.year, from: date) &&
               calendar.component(.month, from: self) == calendar.component(.month, from: date)
    }

    func isSameYear(as date: Date) -> Bool {
        Calendar.current.component(.year, from: self) == Calendar.current.component(.year, from: date)
    }

    var monthYearString: String {
        Date.monthYearFormatter.string(from: self)
    }

    var shortDateString: String {
        Date.shortDateFormatter.string(from: self)
    }

    var relativeDateString: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return String(localized: "common.today")
        } else if calendar.isDateInYesterday(self) {
            return String(localized: "date.yesterday")
        } else if calendar.isDateInTomorrow(self) {
            return String(localized: "date.tomorrow")
        } else {
            return shortDateString
        }
    }
}
