import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    private let transactionRepository: TransactionRepositoryProtocol

    var totalBalance: Decimal = 0
    var monthlyIncome: Decimal = 0
    var monthlyExpense: Decimal = 0
    var recentTransactions: [Transaction] = []
    var expenseByCategory: [(category: Category, amount: Decimal)] = []
    var errorMessage: String?
    var isLoading: Bool = false
    private var loadTask: Task<Void, Never>?

    var monthlyBalance: Decimal {
        monthlyIncome - monthlyExpense
    }

    var currentMonthString: String {
        Date().monthYearString
    }

    var isEmpty: Bool {
        !isLoading && recentTransactions.isEmpty && totalBalance == 0 && monthlyIncome == 0 && monthlyExpense == 0
    }

    init(transactionRepository: TransactionRepositoryProtocol) {
        self.transactionRepository = transactionRepository
    }

    convenience init(modelContext: ModelContext) {
        self.init(transactionRepository: TransactionRepository(modelContext: modelContext))
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        do {
            let preloader = AppDataPreloader.shared
            let allTransactions: [Transaction]

            if !preloader.transactions.isEmpty {
                allTransactions = preloader.transactions
            } else {
                // Single fetch for all transactions - no repeated DB calls
                let fetched = try transactionRepository.fetchAll()
                preloader.updateTransactions(fetched)
                allTransactions = fetched
            }

            let now = Date()
            let startOfMonth = now.startOfMonth
            let endOfMonth = now.endOfMonth

            // Calculate totals in a single pass
            var runningBalance: Decimal = 0
            var runningMonthlyIncome: Decimal = 0
            var runningMonthlyExpense: Decimal = 0
            var categoryTotals: [Category: Decimal] = [:]

            for transaction in allTransactions {
                runningBalance += transaction.signedAmount

                guard transaction.date >= startOfMonth && transaction.date <= endOfMonth else {
                    continue
                }

                if transaction.type == .income {
                    runningMonthlyIncome += transaction.amount
                } else {
                    runningMonthlyExpense += transaction.amount
                    if let category = transaction.category {
                        categoryTotals[category, default: .zero] += transaction.amount
                    }
                }
            }

            totalBalance = runningBalance
            monthlyIncome = runningMonthlyIncome
            monthlyExpense = runningMonthlyExpense
            recentTransactions = Array(allTransactions.prefix(5))
            expenseByCategory = categoryTotals
                .map { (category: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
