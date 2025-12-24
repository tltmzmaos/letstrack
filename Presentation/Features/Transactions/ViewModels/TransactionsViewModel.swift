import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class TransactionsViewModel {
    private let transactionRepository: TransactionRepositoryProtocol

    var transactions: [Transaction] = []
    var searchText: String = ""
    var selectedFilter: TransactionFilter = .all
    var groupedTransactions: [String: [Transaction]] = [:]
    var errorMessage: String?
    var isLoading: Bool = false

    private var groupedSectionDates: [String: Date] = [:]

    var filteredTransactions: [Transaction] {
        var result = transactions

        switch selectedFilter {
        case .all:
            break
        case .income:
            result = result.filter { $0.type == .income }
        case .expense:
            result = result.filter { $0.type == .expense }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.note.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    init(transactionRepository: TransactionRepositoryProtocol) {
        self.transactionRepository = transactionRepository
    }

    convenience init(modelContext: ModelContext) {
        self.init(transactionRepository: TransactionRepository(modelContext: modelContext))
    }

    private var loadTask: Task<Void, Never>?

    func loadTransactions(forceRefresh: Bool = false) {
        // Cancel previous load if still running
        loadTask?.cancel()

        loadTask = Task {
            await loadTransactionsAsync(forceRefresh: forceRefresh)
        }
    }

    private func loadTransactionsAsync(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil

        // Yield to allow UI to update with loading state
        await Task.yield()

        do {
            guard !Task.isCancelled else { return }
            let preloader = AppDataPreloader.shared
            if !forceRefresh, !preloader.transactions.isEmpty {
                transactions = preloader.transactions
            } else {
                let fetched = try transactionRepository.fetchAll()
                transactions = fetched
                preloader.updateTransactions(fetched)
            }
            updateGroupedTransactions()
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }

    func applyFilters() {
        updateGroupedTransactions()
    }

    func deleteTransaction(_ transaction: Transaction) {
        do {
            try transactionRepository.delete(transaction)
            loadTransactions(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransactions(at offsets: IndexSet, in section: String) {
        guard let sectionTransactions = groupedTransactions[section] else { return }

        for index in offsets {
            let transaction = sectionTransactions[index]
            do {
                try transactionRepository.delete(transaction)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        loadTransactions(forceRefresh: true)
    }

    private func updateGroupedTransactions() {
        let filtered = filteredTransactions
        let grouped = Dictionary(grouping: filtered) { transaction in
            transaction.date.monthYearString
        }
        groupedTransactions = grouped
        groupedSectionDates = grouped.reduce(into: [:]) { result, entry in
            if let firstDate = entry.value.first?.date {
                result[entry.key] = firstDate.startOfMonth
            }
        }
    }

    var sortedSectionKeys: [String] {
        groupedTransactions.keys.sorted { key1, key2 in
            let date1 = groupedSectionDates[key1] ?? Date.distantPast
            let date2 = groupedSectionDates[key2] ?? Date.distantPast
            return date1 > date2
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all
    case income
    case expense

    var displayName: String {
        switch self {
        case .all:
            return String(localized: "search.filter.all")
        case .income:
            return String(localized: "search.filter.income")
        case .expense:
            return String(localized: "search.filter.expense")
        }
    }

    var shortName: String {
        switch self {
        case .all:
            return String(localized: "common.all")
        case .income:
            return String(localized: "dashboard.income")
        case .expense:
            return String(localized: "dashboard.expense")
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .income:
            return "arrow.down.circle"
        case .expense:
            return "arrow.up.circle"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .all:
            return "rectangle.stack.fill"
        case .income:
            return "plus.circle.fill"
        case .expense:
            return "minus.circle.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .all:
            return String(localized: "filter.all.short")
        case .income:
            return String(localized: "filter.income.short")
        case .expense:
            return String(localized: "filter.expense.short")
        }
    }
}
