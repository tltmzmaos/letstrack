import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var selectedTransaction: Transaction?
    @State private var showMonthlySummary: Bool = false
    @State private var hasLoaded: Bool = false

    // Cached data
    @State private var allTransactions: [Transaction] = []
    @State private var projectedRecurringTransactions: [Transaction] = []
    @State private var nonEditableRecurringIds: Set<UUID> = []
    @State private var combinedTransactions: [Transaction] = []
    @State private var dailyIndex: [Date: [Transaction]] = [:]
    @State private var cachedMonthlyTransactions: [Transaction] = []
    @State private var cachedMonthlyExpense: Decimal = 0
    @State private var cachedMonthlyIncome: Decimal = 0
    @State private var cachedDailyTransactions: [Transaction] = []

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation with summary
                CalendarMonthNavigationView(
                    currentMonth: $currentMonth,
                    monthlyIncome: cachedMonthlyIncome,
                    monthlyExpense: cachedMonthlyExpense,
                    showSummary: $showMonthlySummary
                )

                // Monthly Summary Card (collapsible)
                if showMonthlySummary {
                    CalendarMonthlySummaryCard(
                        transactions: cachedMonthlyTransactions,
                        income: cachedMonthlyIncome,
                        expense: cachedMonthlyExpense
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                // Calendar grid
                CalendarGridView(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    transactions: combinedTransactions
                )

                Divider()

                // Daily transactions
                CalendarDailyTransactionsView(
                    date: selectedDate,
                    transactions: cachedDailyTransactions,
                    selectedTransaction: $selectedTransaction,
                    nonEditableTransactionIds: nonEditableRecurringIds
                )
            }
            .navigationTitle(String(localized: "calendar.title"))
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await loadAllData()
            }
            .onChange(of: currentMonth) { _, _ in
                Task {
                    await loadRecurringProjections()
                    await updateMonthlyCache()
                }
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await updateDailyCache() }
            }
        }
    }

    private func loadAllData() async {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3000

        do {
            let preloader = AppDataPreloader.shared
            if !preloader.transactions.isEmpty {
                allTransactions = Array(preloader.transactions.prefix(3000))
            } else {
                allTransactions = try modelContext.fetch(descriptor)
                preloader.updateTransactions(allTransactions)
            }
            await loadRecurringProjections()
            rebuildCombinedCache()
            await updateMonthlyCache()
            await updateDailyCache()
        } catch {
            allTransactions = []
        }
    }

    private func loadRecurringProjections() async {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            projectedRecurringTransactions = []
            nonEditableRecurringIds = []
            return
        }

        let recurringRepo = RecurringTransactionRepository(modelContext: modelContext)
        let recurrings = (try? recurringRepo.fetchActive()) ?? []
        let currency = CurrencySettings.shared.defaultCurrency
        let projections = RecurringProjectionService.projectedTransactions(
            recurrings: recurrings,
            from: monthStart,
            to: monthEnd,
            currency: currency
        )
        projectedRecurringTransactions = projections
        nonEditableRecurringIds = Set(projections.map { $0.id })
        rebuildCombinedCache()
    }

    private func rebuildCombinedCache() {
        let combined = allTransactions + projectedRecurringTransactions
        combinedTransactions = combined
        dailyIndex = Dictionary(grouping: combined) { $0.date.startOfDay }
    }

    private func updateMonthlyCache() async {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }

        cachedMonthlyTransactions = combinedTransactions.filter { $0.date >= monthStart && $0.date <= monthEnd }

        // Single pass for totals
        var expense: Decimal = 0
        var income: Decimal = 0
        for tx in cachedMonthlyTransactions {
            if tx.type == .expense {
                expense += tx.amount
            } else {
                income += tx.amount
            }
        }
        cachedMonthlyExpense = expense
        cachedMonthlyIncome = income
    }

    private func updateDailyCache() async {
        cachedDailyTransactions = dailyIndex[selectedDate.startOfDay] ?? []
    }
}

// MARK: - Month Navigation View

struct CalendarMonthNavigationView: View {
    @Binding var currentMonth: Date
    let monthlyIncome: Decimal
    let monthlyExpense: Decimal
    @Binding var showSummary: Bool

    private let calendar = Calendar.current

    private var balance: Decimal {
        monthlyIncome - monthlyExpense
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSummary.toggle()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(currentMonth.monthYearString)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(CurrencySettings.shared.defaultCurrency.formatCompact(monthlyIncome))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                Text(CurrencySettings.shared.defaultCurrency.formatCompact(monthlyExpense))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        Image(systemName: showSummary ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Monthly Summary Card

struct CalendarMonthlySummaryCard: View {
    let transactions: [Transaction]
    let income: Decimal
    let expense: Decimal

    private var balance: Decimal {
        income - expense
    }

    private var categoryBreakdown: [(category: Category, amount: Decimal)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.category }

        return grouped.compactMap { category, transactions in
            guard let category = category else { return nil }
            let amount = transactions.reduce(Decimal.zero) { $0 + $1.amount }
            return (category: category, amount: amount)
        }
        .sorted { $0.amount > $1.amount }
        .prefix(5)
        .map { $0 }
    }

    private var transactionCount: Int {
        transactions.count
    }

    private var averageExpense: Decimal {
        let expenseCount = transactions.filter { $0.type == .expense }.count
        guard expenseCount > 0 else { return 0 }
        return expense / Decimal(expenseCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Balance summary
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(localized: "calendar.balance"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencySettings.shared.defaultCurrency.format(balance))
                        .font(.title3.bold())
                        .foregroundStyle(balance >= 0 ? .green : .red)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text(String(localized: "calendar.transactions_count"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(transactionCount)")
                        .font(.title3.bold())
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text(String(localized: "calendar.avg_expense"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencySettings.shared.defaultCurrency.formatCompact(averageExpense))
                        .font(.title3.bold())
                }
            }

            // Top categories
            if !categoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "calendar.top_categories"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(categoryBreakdown, id: \.category.id) { item in
                            VStack(spacing: 4) {
                                Image(systemName: item.category.icon)
                                    .font(.body)
                                    .foregroundStyle(item.category.color)
                                    .frame(width: 32, height: 32)
                                    .background(item.category.color.opacity(0.15))
                                    .clipShape(Circle())

                                Text(CurrencySettings.shared.defaultCurrency.formatCompact(item.amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let transactions: [Transaction]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    CalendarDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        dayTransactions: transactionsForDate(date)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = firstWeekday - calendar.firstWeekday
        let adjustedLeadingDays = leadingEmptyDays < 0 ? leadingEmptyDays + 7 : leadingEmptyDays

        var days: [Date?] = Array(repeating: nil, count: adjustedLeadingDays)

        var currentDate = monthStart
        while currentDate <= monthEnd {
            days.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return days
    }

    private func transactionsForDate(_ date: Date) -> [Transaction] {
        transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let dayTransactions: [Transaction]

    private let calendar = Calendar.current

    private var dayExpense: Decimal {
        dayTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var hasTransactions: Bool {
        !dayTransactions.isEmpty
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))

            if hasTransactions {
                Circle()
                    .fill(isSelected ? .white : .accentColor)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.1) : Color.clear))
        )
    }
}

// MARK: - Daily Transactions View

struct CalendarDailyTransactionsView: View {
    let date: Date
    let transactions: [Transaction]
    @Binding var selectedTransaction: Transaction?
    var nonEditableTransactionIds: Set<UUID> = []

    private var dailyIncome: Decimal {
        transactions.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var dailyExpense: Decimal {
        transactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(date.formatted(date: .complete, time: .omitted))
                    .font(.headline)

                Spacer()

                if !transactions.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        if dailyIncome > 0 {
                            Text("+" + CurrencySettings.shared.defaultCurrency.format(dailyIncome))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        if dailyExpense > 0 {
                            Text("-" + CurrencySettings.shared.defaultCurrency.format(dailyExpense))
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding()

            if transactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "calendar.no_transactions"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(transactions, id: \.id) { transaction in
                        CalendarTransactionRow(
                            transaction: transaction,
                            isRecurring: nonEditableTransactionIds.contains(transaction.id)
                        )
                            .onTapGesture {
                                guard !nonEditableTransactionIds.contains(transaction.id) else { return }
                                selectedTransaction = transaction
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Calendar Transaction Row

struct CalendarTransactionRow: View {
    let transaction: Transaction
    var isRecurring: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .font(.body)
                    .foregroundStyle(category.color)
                    .frame(width: 36, height: 36)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(.gray)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.category?.name ?? String(localized: "categories.uncategorized"))
                        .font(.subheadline.weight(.medium))
                    if isRecurring {
                        Text(String(localized: "recurring.auto_generated"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
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

            Text(transaction.formattedSignedAmount)
                .font(.subheadline.bold())
                .foregroundStyle(transaction.type == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
