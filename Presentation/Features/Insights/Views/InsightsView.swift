import SwiftUI
import SwiftData
import Charts
import MapKit

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPeriod: InsightPeriod = .sixMonths
    @State private var isLoading = true
    @State private var hasAppeared = false

    // Fetched data
    @State private var budgets: [Budget] = []

    // Cached analytics data
    @State private var spendingTrends: [SpendingTrend] = []
    @State private var topExpenses: [TopExpense] = []
    @State private var spendingByDay: [SpendingByDayOfWeek] = []
    @State private var categoryBreakdown: [CategorySpending] = []
    @State private var recurringPatterns: [DetectedRecurringPattern] = []
    @State private var categoryTrends: [CategoryTrend] = []
    @State private var budgetPredictions: [(budget: Budget, prediction: BudgetPrediction)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(InsightPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        // Spending Trends
                        SpendingTrendsCard(trends: spendingTrends)

                        // Budget Predictions
                        if !budgetPredictions.isEmpty {
                            BudgetPredictionsCardOptimized(predictions: budgetPredictions)
                        }

                        // Top Expenses
                        TopExpensesCard(expenses: topExpenses)

                        // Spending by Day of Week
                        SpendingByDayCard(data: spendingByDay)

                        // Category Comparison
                        CategoryComparisonCard(data: categoryBreakdown)

                        // Recurring Patterns
                        RecurringPatternsCard(patterns: recurringPatterns)

                        // Category Trends
                        CategoryTrendsCard(trends: categoryTrends)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(String(localized: "insights.title"))
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true
                await loadAnalytics()
            }
            .onChange(of: selectedPeriod) { _, _ in
                Task {
                    await loadAnalytics()
                }
            }
        }
    }

    private func loadAnalytics() async {
        isLoading = true

        let period = selectedPeriod
        let startDate = period.startDate

        let preloader = AppDataPreloader.shared
        let cachedTransactions = preloader.transactions

        // Fetch transactions with date predicate for filtered data
        let filteredDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        // Fetch all transactions for trends (limited)
        var allDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        allDescriptor.fetchLimit = 2000 // Reasonable limit for analytics

        // Fetch budgets
        let budgetDescriptor = FetchDescriptor<Budget>()

        do {
            let filteredTransactions: [Transaction]
            let allTransactions: [Transaction]

            if !cachedTransactions.isEmpty {
                filteredTransactions = cachedTransactions.filter { $0.date >= startDate }
                allTransactions = Array(cachedTransactions.prefix(2000))
            } else {
                filteredTransactions = try modelContext.fetch(filteredDescriptor)
                allTransactions = try modelContext.fetch(allDescriptor)
            }
            budgets = try modelContext.fetch(budgetDescriptor)

            // Run analytics synchronously (these are fast CPU-bound operations)
            spendingTrends = AnalyticsService.shared.getMonthlyTrends(
                transactions: allTransactions,
                months: period.monthCount
            )

            topExpenses = AnalyticsService.shared.getTopExpenses(
                transactions: allTransactions,
                limit: 5,
                from: startDate
            )

            spendingByDay = AnalyticsService.shared.getSpendingByDayOfWeek(
                transactions: filteredTransactions
            )

            categoryBreakdown = AnalyticsService.shared.getCategoryBreakdown(
                transactions: filteredTransactions
            )

            recurringPatterns = AnalyticsService.shared.detectRecurringPatterns(
                transactions: allTransactions
            )

            categoryTrends = AnalyticsService.shared.getCategoryTrends(
                transactions: allTransactions
            )

            // Compute budget predictions
            var predictions: [(budget: Budget, prediction: BudgetPrediction)] = []
            for budget in budgets {
                let prediction = AnalyticsService.shared.predictBudget(
                    budget: budget,
                    transactions: allTransactions
                )
                predictions.append((budget: budget, prediction: prediction))
            }
            budgetPredictions = predictions

        } catch {
            // Handle error silently
        }

        isLoading = false
    }
}

// MARK: - Optimized Budget Predictions Card

struct BudgetPredictionsCardOptimized: View {
    let predictions: [(budget: Budget, prediction: BudgetPrediction)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.budget_predictions"))
                .font(.headline)

            ForEach(predictions, id: \.budget.id) { item in
                BudgetPredictionRow(budget: item.budget, prediction: item.prediction)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Insight Period

enum InsightPeriod: String, CaseIterable {
    case threeMonths = "3m"
    case sixMonths = "6m"
    case oneYear = "1y"

    var displayName: String {
        switch self {
        case .threeMonths: return String(localized: "insights.period.3m")
        case .sixMonths: return String(localized: "insights.period.6m")
        case .oneYear: return String(localized: "insights.period.1y")
        }
    }

    var monthCount: Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .month, value: -monthCount, to: Date()) ?? Date()
    }
}

// MARK: - Spending Trends Card

struct SpendingTrendsCard: View {
    let trends: [SpendingTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.spending_trends"))
                .font(.headline)

            if trends.isEmpty {
                Text(String(localized: "insights.no_data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(trends) { trend in
                    BarMark(
                        x: .value("Month", trend.period),
                        y: .value("Expense", trend.expense)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Summary
                if let latestTrend = trends.last,
                   let previousTrend = trends.dropLast().last {
                    let change = latestTrend.expense - previousTrend.expense
                    let isIncrease = change > 0

                    HStack {
                        Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(isIncrease ? .red : .green)

                        Text(isIncrease
                             ? String(localized: "insights.increased_by \(CurrencySettings.shared.defaultCurrency.format(abs(change)))")
                             : String(localized: "insights.decreased_by \(CurrencySettings.shared.defaultCurrency.format(abs(change)))"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Budget Predictions Card

struct BudgetPredictionsCard: View {
    let budgets: [Budget]
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.budget_predictions"))
                .font(.headline)

            ForEach(budgets, id: \.id) { budget in
                let prediction = AnalyticsService.shared.predictBudget(
                    budget: budget,
                    transactions: transactions
                )

                BudgetPredictionRow(budget: budget, prediction: prediction)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct BudgetPredictionRow: View {
    let budget: Budget
    let prediction: BudgetPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category?.name ?? String(localized: "budget.total_budget"))
                    .font(.subheadline.weight(.medium))

                Spacer()

                Image(systemName: prediction.isOnTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(prediction.isOnTrack ? .green : .orange)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(prediction.isOnTrack ? Color.green : Color.orange)
                        .frame(width: geometry.size.width * min(prediction.usagePercentage / 100, 1), height: 8)

                    // Predicted line
                    if prediction.predictedUsagePercentage > prediction.usagePercentage {
                        Rectangle()
                            .fill(Color.red.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width * min(prediction.predictedUsagePercentage / 100, 1) - 1)
                    }
                }
            }
            .frame(height: 12)

            HStack {
                Text(String(localized: "insights.current \(Int(prediction.usagePercentage))%"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(localized: "insights.predicted \(Int(prediction.predictedUsagePercentage))%"))
                    .font(.caption)
                    .foregroundStyle(prediction.predictedUsagePercentage > 100 ? .red : .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Top Expenses Card

struct TopExpensesCard: View {
    let expenses: [TopExpense]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.top_expenses"))
                .font(.headline)

            if expenses.isEmpty {
                Text(String(localized: "insights.no_data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(expenses) { expense in
                    HStack(spacing: 12) {
                        Text("#\(expense.rank)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(rankColor(expense.rank))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(expense.transaction.category?.name ?? String(localized: "categories.uncategorized"))
                                    .font(.subheadline.weight(.medium))

                                if !expense.transaction.note.isEmpty {
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text(expense.transaction.note)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Text(expense.transaction.date.shortDateString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(expense.transaction.formattedAmount)
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .accentColor
        }
    }
}

// MARK: - Spending by Day Card

struct SpendingByDayCard: View {
    let data: [SpendingByDayOfWeek]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.spending_by_day"))
                .font(.headline)

            if data.allSatisfy({ $0.totalAmount == 0 }) {
                Text(String(localized: "insights.no_data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(data) { day in
                    BarMark(
                        x: .value("Day", String(day.dayName.prefix(3))),
                        y: .value("Amount", day.totalAmount)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 150)

                // Peak day
                if let peakDay = data.max(by: { $0.totalAmount < $1.totalAmount }), peakDay.totalAmount > 0 {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.accentColor)

                        Text(String(localized: "insights.peak_day \(peakDay.dayName)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Category Comparison Card

struct CategoryComparisonCard: View {
    let data: [CategorySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "insights.category_breakdown"))
                .font(.headline)

            if data.isEmpty {
                Text(String(localized: "insights.no_data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(data.prefix(5)) { categoryData in
                    HStack(spacing: 12) {
                        Image(systemName: categoryData.category.icon)
                            .foregroundStyle(categoryData.category.color)
                            .frame(width: 32, height: 32)
                            .background(categoryData.category.color.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(categoryData.category.name)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Text(CurrencySettings.shared.defaultCurrency.format(categoryData.amount))
                                    .font(.subheadline)
                            }

                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(categoryData.category.color)
                                    .frame(width: geometry.size.width * (categoryData.percentage / 100))
                            }
                            .frame(height: 4)

                            Text("\(Int(categoryData.percentage))% · \(categoryData.transactionCount) " + String(localized: "insights.transactions"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Recurring Patterns Card

struct RecurringPatternsCard: View {
    let patterns: [DetectedRecurringPattern]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "insights.recurring_patterns"))
                    .font(.headline)

                Spacer()

                Image(systemName: "repeat.circle.fill")
                    .foregroundStyle(.blue)
            }

            if patterns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "insights.no_recurring_patterns"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(patterns.prefix(5)) { pattern in
                    RecurringPatternRow(pattern: pattern)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct RecurringPatternRow: View {
    let pattern: DetectedRecurringPattern

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            if let category = pattern.category {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 36, height: 36)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pattern.category?.name ?? String(localized: "categories.uncategorized"))
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(CurrencySettings.shared.defaultCurrency.format(pattern.averageAmount))
                        .font(.subheadline.bold())
                }

                HStack {
                    // Frequency badge
                    Text(frequencyDisplayName(pattern.frequency))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text("· \(pattern.occurrences) " + String(localized: "insights.occurrences"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Confidence indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index < Int(pattern.confidence * 3) ? Color.green : Color(.systemGray4))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                if let nextExpected = pattern.nextExpected {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                        Text(String(localized: "insights.next_expected \(nextExpected.formatted(date: .abbreviated, time: .omitted))"))
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func frequencyDisplayName(_ frequency: String) -> String {
        switch frequency {
        case "monthly": return String(localized: "insights.frequency.monthly")
        case "weekly": return String(localized: "insights.frequency.weekly")
        case "biweekly": return String(localized: "insights.frequency.biweekly")
        default: return frequency
        }
    }
}

// MARK: - Category Trends Card

struct CategoryTrendsCard: View {
    let trends: [CategoryTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "insights.category_trends"))
                    .font(.headline)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)
            }

            if trends.isEmpty {
                Text(String(localized: "insights.no_data"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(trends.prefix(5)) { trend in
                    CategoryTrendRow(trend: trend)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct CategoryTrendRow: View {
    let trend: CategoryTrend

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: trend.category.icon)
                .foregroundStyle(trend.category.color)
                .frame(width: 36, height: 36)
                .background(trend.category.color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trend.category.name)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    // Change indicator
                    HStack(spacing: 4) {
                        Image(systemName: trend.isIncreasing ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.bold())

                        Text(String(format: "%.0f%%", abs(trend.changePercentage)))
                            .font(.caption.bold())
                    }
                    .foregroundStyle(trend.isIncreasing ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((trend.isIncreasing ? Color.red : Color.green).opacity(0.15))
                    .clipShape(Capsule())
                }

                HStack {
                    Text(String(localized: "insights.this_month"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(CurrencySettings.shared.defaultCurrency.format(trend.currentMonthAmount))
                        .font(.caption.weight(.medium))

                    Text("←")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "insights.last_month"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(CurrencySettings.shared.defaultCurrency.format(trend.previousMonthAmount))
                        .font(.caption.weight(.medium))
                }

                // Average indicator
                HStack {
                    Text(String(localized: "insights.avg"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(CurrencySettings.shared.defaultCurrency.format(trend.averageMonthlyAmount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(trend.transactionCount) " + String(localized: "insights.transactions_this_month"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
