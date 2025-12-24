import Foundation

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    func formatted(currency: String = "KRW") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency

        if currency == "KRW" {
            formatter.maximumFractionDigits = 0
        }

        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self)"
    }

    func formattedWithSign(currency: String = "KRW") -> String {
        let prefix = self >= 0 ? "+" : ""
        return prefix + formatted(currency: currency)
    }

    static func parseLocalized(_ string: String) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let number = formatter.number(from: string) {
            return number.decimalValue
        }
        return Decimal(string: string)
    }
}
