import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: StatisticsViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel = viewModel {
                    VStack(spacing: 20) {
                        // Period Selector
                        PeriodSelectorView(viewModel: viewModel)

                        // Summary Card
                        SummaryCardView(
                            income: viewModel.totalIncome,
                            expense: viewModel.totalExpense,
                            balance: viewModel.balance
                        )

                        // Charts based on period
                        if viewModel.selectedPeriod == .month {
                            // Pie Chart for monthly
                            if !viewModel.expenseByCategory.isEmpty {
                                CategoryPieChartView(
                                    data: viewModel.expenseByCategory,
                                    total: viewModel.totalExpense
                                )
                            }
                        } else {
                            // Bar Chart for yearly
                            if !viewModel.monthlyData.isEmpty {
                                MonthlyBarChartView(data: viewModel.monthlyData)
                            }
                        }

                        // Category List
                        if !viewModel.expenseByCategory.isEmpty {
                            CategoryListView(
                                data: viewModel.expenseByCategory,
                                total: viewModel.totalExpense
                            )
                        }
                    }
                    .padding()
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "statistics.title"))
            .onAppear {
                if viewModel == nil {
                    viewModel = StatisticsViewModel(modelContext: modelContext)
                }
                viewModel?.loadData()
            }
        }
    }
}

// MARK: - Period Selector
struct PeriodSelectorView: View {
    @Bindable var viewModel: StatisticsViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Period Picker
            Picker(String(localized: "budget.period"), selection: $viewModel.selectedPeriod) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)

            // Navigation
            HStack {
                Button {
                    viewModel.goToPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(viewModel.periodTitle)
                    .font(.title2.bold())

                Spacer()

                Button {
                    viewModel.goToNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .onChange(of: viewModel.selectedPeriod) {
            viewModel.loadData()
        }
    }
}

// MARK: - Summary Card
struct SummaryCardView: View {
    let income: Decimal
    let expense: Decimal
    let balance: Decimal

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "dashboard.income"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(currency.format(income))
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "dashboard.expense"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(currency.format(expense))
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                }
            }

            Divider()

            HStack {
                Text(String(localized: "dashboard.total_balance"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currency.formatWithSign(balance))
                    .font(.title2.bold())
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Pie Chart
struct CategoryPieChartView: View {
    let data: [(category: Category, amount: Decimal)]
    let total: Decimal

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "statistics.expense_by_category"))
                .font(.headline)

            Chart(data, id: \.category.id) { item in
                SectorMark(
                    angle: .value(String(localized: "transactions.amount"), item.amount.doubleValue),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(item.category.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartBackground { _ in
                VStack {
                    Text(String(localized: "statistics.total_expense"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currency.format(total))
                        .font(.title3.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Bar Chart
struct MonthlyBarChartView: View {
    let data: [MonthlyData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "statistics.daily_spending"))
                .font(.headline)

            Chart(data) { item in
                BarMark(
                    x: .value(String(localized: "statistics.period.month"), item.monthName),
                    y: .value(String(localized: "dashboard.expense"), item.expense.doubleValue)
                )
                .foregroundStyle(.red.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Decimal(amount).formatted())
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category List
struct CategoryListView: View {
    let data: [(category: Category, amount: Decimal)]
    let total: Decimal

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "statistics.expense_by_category"))
                .font(.headline)

            ForEach(data, id: \.category.id) { item in
                HStack {
                    Image(systemName: item.category.icon)
                        .foregroundStyle(item.category.color)
                        .frame(width: 28)

                    Text(item.category.name)

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(currency.format(item.amount))
                            .font(.subheadline.bold())

                        let percentage = total > 0 ? (item.amount / total * 100).doubleValue : 0
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if item.category.id != data.last?.category.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
