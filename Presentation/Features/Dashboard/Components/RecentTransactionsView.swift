import SwiftUI

struct RecentTransactionsView: View {
    let transactions: [Transaction]
    var onViewAll: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "dashboard.recent_transactions"))
                    .font(.headline)

                Spacer()

                Button {
                    onViewAll?()
                } label: {
                    Text(String(localized: "dashboard.view_all"))
                        .font(.subheadline)
                }
            }

            ForEach(transactions, id: \.id) { transaction in
                TransactionRowView(transaction: transaction)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 32, height: 32)
                    .background(category.color.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.category?.name ?? String(localized: "categories.uncategorized"))
                        .font(.subheadline.weight(.medium))

                    if transaction.receiptImageData != nil {
                        Image(systemName: "doc.text.image")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedSignedAmount)
                    .font(.subheadline.bold())
                    .foregroundStyle(transaction.type == .income ? .green : .primary)

                Text(transaction.date.relativeDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
