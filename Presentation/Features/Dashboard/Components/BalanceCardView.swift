import SwiftUI

struct BalanceCardView: View {
    let totalBalance: Decimal
    let monthlyIncome: Decimal
    let monthlyExpense: Decimal

    // Cache currency at init to avoid repeated singleton access
    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "dashboard.total_balance"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(currency.format(totalBalance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(totalBalance >= 0 ? Color.primary : Color.red)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    BalanceCardView(totalBalance: 1500000, monthlyIncome: 3000000, monthlyExpense: 1500000)
        .padding()
}
