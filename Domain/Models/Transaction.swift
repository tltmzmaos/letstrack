import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var amount: Decimal
    var type: TransactionType
    var note: String
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    var currencyCode: String
    @Attribute(.externalStorage) var receiptImageData: Data?
    var tagNames: [String] = []

    // Location fields (optional)
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    var category: Category?
    var wallet: Wallet?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        category: Category? = nil,
        wallet: Wallet? = nil,
        note: String = "",
        date: Date = Date(),
        currency: Currency = .usd,
        receiptImageData: Data? = nil,
        tagNames: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.wallet = wallet
        self.note = note
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currencyCode = currency.rawValue
        self.receiptImageData = receiptImageData
        self.tagNames = tagNames
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }

    /// Returns the signed amount (positive for income, negative for expense)
    var signedAmount: Decimal {
        switch type {
        case .income:
            return amount
        case .expense:
            return -amount
        }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyCode) ?? .krw }
        set { currencyCode = newValue.rawValue }
    }

    var formattedAmount: String {
        currency.format(amount)
    }

    var formattedSignedAmount: String {
        let formatted = currency.format(amount)
        switch type {
        case .income:
            return "+\(formatted)"
        case .expense:
            return "-\(formatted)"
        }
    }
}

// MARK: - Convenience Methods
extension Transaction {
    func update(
        amount: Decimal? = nil,
        type: TransactionType? = nil,
        category: Category? = nil,
        wallet: Wallet? = nil,
        note: String? = nil,
        date: Date? = nil,
        currency: Currency? = nil,
        receiptImageData: Data? = nil,
        tagNames: [String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) {
        if let amount = amount { self.amount = amount }
        if let type = type { self.type = type }
        if let category = category { self.category = category }
        if let wallet = wallet { self.wallet = wallet }
        if let note = note { self.note = note }
        if let date = date { self.date = date }
        if let currency = currency { self.currencyCode = currency.rawValue }
        if let receiptImageData = receiptImageData { self.receiptImageData = receiptImageData }
        if let tagNames = tagNames { self.tagNames = tagNames }
        if let latitude = latitude { self.latitude = latitude }
        if let longitude = longitude { self.longitude = longitude }
        if let locationName = locationName { self.locationName = locationName }
        self.updatedAt = Date()
    }

    /// Check if transaction has location data
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var formattedTags: String {
        tagNames.map { "#\($0)" }.joined(separator: " ")
    }

    var hasTags: Bool {
        !tagNames.isEmpty
    }
}
