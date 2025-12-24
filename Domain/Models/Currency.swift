import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case krw = "KRW"
    case usd = "USD"
    case eur = "EUR"
    case jpy = "JPY"
    case cny = "CNY"
    case gbp = "GBP"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .krw: return "₩"
        case .usd: return "$"
        case .eur: return "€"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .gbp: return "£"
        }
    }

    var name: String {
        switch self {
        case .krw: return String(localized: "currency.krw")
        case .usd: return String(localized: "currency.usd")
        case .eur: return String(localized: "currency.eur")
        case .jpy: return String(localized: "currency.jpy")
        case .cny: return String(localized: "currency.cny")
        case .gbp: return String(localized: "currency.gbp")
        }
    }

    var locale: Locale {
        switch self {
        case .krw: return Locale(identifier: "ko_KR")
        case .usd: return Locale(identifier: "en_US")
        case .eur: return Locale(identifier: "de_DE")
        case .jpy: return Locale(identifier: "ja_JP")
        case .cny: return Locale(identifier: "zh_CN")
        case .gbp: return Locale(identifier: "en_GB")
        }
    }

    var decimalPlaces: Int {
        switch self {
        case .krw, .jpy: return 0
        case .usd, .eur, .cny, .gbp: return 2
        }
    }

    func format(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.currencySymbol = symbol
        formatter.locale = locale
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = decimalPlaces
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(symbol)\(amount)"
    }

    func formatWithSign(_ amount: Decimal) -> String {
        let formatted = format(abs(amount))
        if amount >= 0 {
            return "+\(formatted)"
        } else {
            return "-\(formatted)"
        }
    }

    /// Compact format for large numbers (e.g., 1.2M, 500K)
    func formatCompact(_ amount: Decimal) -> String {
        let doubleAmount = Double(truncating: amount as NSDecimalNumber)

        switch self {
        case .krw, .jpy:
            // Korean/Japanese: 억 (100M), 만 (10K)
            if abs(doubleAmount) >= 100_000_000 {
                return String(format: "%@%.1f억", symbol, doubleAmount / 100_000_000)
            } else if abs(doubleAmount) >= 10_000 {
                return String(format: "%@%.0f만", symbol, doubleAmount / 10_000)
            } else {
                return format(amount)
            }
        default:
            // Western currencies: M (million), K (thousand)
            if abs(doubleAmount) >= 1_000_000 {
                return String(format: "%@%.1fM", symbol, doubleAmount / 1_000_000)
            } else if abs(doubleAmount) >= 1_000 {
                return String(format: "%@%.1fK", symbol, doubleAmount / 1_000)
            } else {
                return format(amount)
            }
        }
    }
}

// MARK: - User Settings for Currency
@MainActor
final class CurrencySettings: ObservableObject {
    static let shared = CurrencySettings()

    @Published var defaultCurrency: Currency {
        didSet {
            UserDefaults.standard.set(defaultCurrency.rawValue, forKey: "defaultCurrency")
        }
    }

    private init() {
        let savedCurrency = UserDefaults.standard.string(forKey: "defaultCurrency") ?? Currency.usd.rawValue
        self.defaultCurrency = Currency(rawValue: savedCurrency) ?? .usd
    }
}
