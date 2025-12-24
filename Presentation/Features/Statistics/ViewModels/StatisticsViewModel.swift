import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class StatisticsViewModel {
    private let transactionRepository: TransactionRepositoryProtocol

    var selectedPeriod: StatisticsPeriod = .month
    var selectedDate: Date = Date()

    var totalIncome: Decimal = 0
    var totalExpense: Decimal = 0
    var expenseByCategory: [(category: Category, amount: Decimal)] = []
    var monthlyData: [MonthlyData] = []
    var errorMessage: String?
    var isLoading: Bool = false

    var balance: Decimal {
        totalIncome - totalExpense
    }

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    var periodTitle: String {
        switch selectedPeriod {
        case .month:
            return selectedDate.monthYearString
        case .year:
            return Self.yearFormatter.string(from: selectedDate)
        }
    }

    init(transactionRepository: TransactionRepositoryProtocol) {
        self.transactionRepository = transactionRepository
    }

    convenience init(modelContext: ModelContext) {
        self.init(transactionRepository: TransactionRepository(modelContext: modelContext))
    }

    private var loadTask: Task<Void, Never>?

    func loadData() {
        // Cancel previous load if still running
        loadTask?.cancel()

        loadTask = Task {
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        isLoading = true
        errorMessage = nil

        // Yield to allow UI to update with loading state
        await Task.yield()

        do {
            let (startDate, endDate) = dateRange(for: selectedPeriod, date: selectedDate)

            guard !Task.isCancelled else { return }
            let transactions = try transactionRepository.fetch(from: startDate, to: endDate)
            applyStatistics(from: transactions, period: selectedPeriod)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }

    func goToPrevious() {
        switch selectedPeriod {
        case .month:
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate) ?? selectedDate
        }
        loadData()
    }

    func goToNext() {
        switch selectedPeriod {
        case .month:
            selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
        }
        loadData()
    }

    private func dateRange(for period: StatisticsPeriod, date: Date) -> (start: Date, end: Date) {
        switch period {
        case .month:
            return (date.startOfMonth, date.endOfMonth)
        case .year:
            return (date.startOfYear, date.endOfYear)
        }
    }

    private func applyStatistics(from transactions: [Transaction], period: StatisticsPeriod) {
        var income: Decimal = 0
        var expense: Decimal = 0
        var categoryTotals: [Category: Decimal] = [:]

        for transaction in transactions {
            if transaction.type == .income {
                income += transaction.amount
            } else {
                expense += transaction.amount
                if let category = transaction.category {
                    categoryTotals[category, default: .zero] += transaction.amount
                }
            }
        }

        totalIncome = income
        totalExpense = expense
        expenseByCategory = categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        guard period == .year else {
            monthlyData = []
            return
        }

        let calendar = Calendar.current
        var monthTotals: [Int: (income: Decimal, expense: Decimal)] = [:]

        for transaction in transactions {
            let month = calendar.component(.month, from: transaction.date)
            if transaction.type == .income {
                monthTotals[month, default: (.zero, .zero)].income += transaction.amount
            } else {
                monthTotals[month, default: (.zero, .zero)].expense += transaction.amount
            }
        }

        monthlyData = (1...12).map { month in
            let totals = monthTotals[month] ?? (income: .zero, expense: .zero)
            return MonthlyData(
                month: month,
                expense: totals.expense,
                income: totals.income
            )
        }
    }
}

enum StatisticsPeriod: String, CaseIterable {
    case month = "month"
    case year = "year"

    var displayName: String {
        switch self {
        case .month:
            return String(localized: "statistics.period.month")
        case .year:
            return String(localized: "statistics.period.year")
        }
    }
}

struct MonthlyData: Identifiable {
    let id = UUID()
    let month: Int
    let expense: Decimal
    let income: Decimal

    var monthName: String {
        let symbols = Calendar.current.shortMonthSymbols
        guard month > 0, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }
}
