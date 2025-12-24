import SwiftUI

struct CategoryBreakdownView: View {
    let categories: [(category: Category, amount: Decimal)]
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "statistics.expense_by_category"))
                .font(.headline)

            ForEach(categories.prefix(5), id: \.category.id) { item in
                CategoryRowView(
                    category: item.category,
                    amount: item.amount,
                    percentage: total > 0 ? (item.amount / total * 100).doubleValue : 0
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CategoryRowView: View {
    let category: Category
    let amount: Decimal
    let percentage: Double

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.body)
                .foregroundStyle(category.color)
                .frame(width: 28, height: 28)
                .background(category.color.opacity(0.15))
                .clipShape(Circle())

            Text(category.name)
                .lineLimit(1)

            Spacer()

            Text(currency.format(amount))
                .font(.subheadline.bold())
                .minimumScaleFactor(0.8)

            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

#Preview {
    CategoryBreakdownView(
        categories: [],
        total: 100000
    )
    .padding()
}
