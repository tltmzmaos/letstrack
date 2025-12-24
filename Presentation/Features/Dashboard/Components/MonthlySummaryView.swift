import SwiftUI

struct MonthlySummaryView: View {
    let month: String
    let income: Decimal
    let expense: Decimal
    let balance: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(month)
                .font(.headline)

            HStack(spacing: 12) {
                SummaryItemView(
                    title: String(localized: "dashboard.income"),
                    amount: income,
                    color: .green,
                    icon: "arrow.down.circle.fill"
                )

                SummaryItemView(
                    title: String(localized: "dashboard.expense"),
                    amount: expense,
                    color: .red,
                    icon: "arrow.up.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SummaryItemView: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text(currency.format(amount))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MonthlySummaryView(
        month: "December 2024",
        income: 3000000,
        expense: 1500000,
        balance: 1500000
    )
    .padding()
}
