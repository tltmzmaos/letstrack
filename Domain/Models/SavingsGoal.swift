import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""
    var targetAmount: Decimal = 0
    var currentAmount: Decimal = 0
    var deadline: Date?
    var icon: String = "target"
    var colorHex: String = "#007AFF"
    var note: String = ""
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date?

    init(
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        deadline: Date? = nil,
        icon: String = "target",
        colorHex: String = "#007AFF",
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.icon = icon
        self.colorHex = colorHex
        self.note = note
        self.createdAt = Date()
        self.isCompleted = false
    }

    // MARK: - Computed Properties

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        let progress = Double(truncating: (currentAmount / targetAmount) as NSDecimalNumber)
        return min(progress, 1.0)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var remainingAmount: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    var daysRemaining: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }

    var dailySavingsNeeded: Decimal? {
        guard let daysRemaining = daysRemaining, daysRemaining > 0 else { return nil }
        return remainingAmount / Decimal(daysRemaining)
    }

    var color: String {
        colorHex
    }

    @MainActor
    var formattedTargetAmount: String {
        CurrencySettings.shared.defaultCurrency.format(targetAmount)
    }

    @MainActor
    var formattedCurrentAmount: String {
        CurrencySettings.shared.defaultCurrency.format(currentAmount)
    }

    @MainActor
    var formattedRemainingAmount: String {
        CurrencySettings.shared.defaultCurrency.format(remainingAmount)
    }

    // MARK: - Methods

    func addSavings(_ amount: Decimal) {
        currentAmount += amount
        checkCompletion()
    }

    func withdrawSavings(_ amount: Decimal) {
        currentAmount = max(currentAmount - amount, 0)
        if isCompleted && currentAmount < targetAmount {
            isCompleted = false
            completedAt = nil
        }
    }

    private func checkCompletion() {
        if currentAmount >= targetAmount && !isCompleted {
            isCompleted = true
            completedAt = Date()
        }
    }
}

// MARK: - Preset Icons
extension SavingsGoal {
    static let presetIcons = [
        "target", "house.fill", "car.fill", "airplane", "graduationcap.fill",
        "gift.fill", "heart.fill", "star.fill", "dollarsign.circle.fill",
        "iphone", "laptopcomputer", "tv.fill", "gamecontroller.fill",
        "figure.walk", "fork.knife", "cup.and.saucer.fill", "tshirt.fill",
        "bag.fill", "creditcard.fill", "banknote.fill"
    ]

    static let presetColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE",
        "#5856D6", "#00C7BE", "#FF3B30", "#FFCC00", "#8E8E93"
    ]
}
