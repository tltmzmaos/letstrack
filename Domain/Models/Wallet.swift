import Foundation
import SwiftData

@Model
final class Wallet {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "creditcard.fill"
    var colorHex: String = "#007AFF"
    var balance: Decimal = 0
    var isDefault: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Transaction.wallet)
    var transactions: [Transaction]? = []

    init(
        name: String,
        icon: String = "creditcard.fill",
        colorHex: String = "#007AFF",
        balance: Decimal = 0,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.balance = balance
        self.isDefault = isDefault
        self.isArchived = false
        self.createdAt = Date()
        self.sortOrder = 0
    }

    // MARK: - Computed Properties

    @MainActor
    var formattedBalance: String {
        CurrencySettings.shared.defaultCurrency.format(balance)
    }

    var color: String {
        colorHex
    }

    var transactionCount: Int {
        transactions?.count ?? 0
    }
}

// MARK: - Wallet Type Presets
extension Wallet {
    enum WalletType: String, CaseIterable {
        case cash = "cash"
        case bank = "bank"
        case creditCard = "credit_card"
        case debitCard = "debit_card"
        case savings = "savings"
        case investment = "investment"
        case other = "other"

        var displayName: String {
            switch self {
            case .cash: return String(localized: "wallet.type.cash")
            case .bank: return String(localized: "wallet.type.bank")
            case .creditCard: return String(localized: "wallet.type.credit_card")
            case .debitCard: return String(localized: "wallet.type.debit_card")
            case .savings: return String(localized: "wallet.type.savings")
            case .investment: return String(localized: "wallet.type.investment")
            case .other: return String(localized: "wallet.type.other")
            }
        }

        var icon: String {
            switch self {
            case .cash: return "banknote.fill"
            case .bank: return "building.columns.fill"
            case .creditCard: return "creditcard.fill"
            case .debitCard: return "creditcard.fill"
            case .savings: return "dollarsign.circle.fill"
            case .investment: return "chart.line.uptrend.xyaxis"
            case .other: return "wallet.pass.fill"
            }
        }

        var defaultColor: String {
            switch self {
            case .cash: return "#34C759"
            case .bank: return "#007AFF"
            case .creditCard: return "#FF9500"
            case .debitCard: return "#5856D6"
            case .savings: return "#00C7BE"
            case .investment: return "#AF52DE"
            case .other: return "#8E8E93"
            }
        }
    }

    static let presetIcons = [
        "creditcard.fill", "banknote.fill", "building.columns.fill",
        "dollarsign.circle.fill", "wallet.pass.fill", "chart.line.uptrend.xyaxis",
        "creditcard.and.123", "giftcard.fill"
    ]

    static let presetColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE",
        "#5856D6", "#00C7BE", "#FF3B30", "#FFCC00", "#8E8E93"
    ]
}
