import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Backup Data Structure

struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let transactions: [TransactionBackup]
    let categories: [CategoryBackup]
    let budgets: [BudgetBackup]
    let savingsGoals: [SavingsGoalBackup]
    let wallets: [WalletBackup]
    let tags: [TagBackup]

    struct TransactionBackup: Codable {
        let id: String
        let amount: String
        let type: String
        let categoryId: String?
        let walletId: String?
        let note: String
        let date: Date
        let currencyCode: String
        let tagNames: [String]
        let createdAt: Date
    }

    struct CategoryBackup: Codable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let type: String
        let isDefault: Bool
    }

    struct BudgetBackup: Codable {
        let id: String
        let amount: String
        let period: String
        let startDate: Date
        let categoryId: String?
    }

    struct SavingsGoalBackup: Codable {
        let id: String
        let name: String
        let targetAmount: String
        let currentAmount: String
        let deadline: Date?
        let icon: String
        let colorHex: String
        let note: String
        let isCompleted: Bool
    }

    struct WalletBackup: Codable {
        let id: String
        let name: String
        let icon: String
        let colorHex: String
        let balance: String
        let isDefault: Bool
    }

    struct TagBackup: Codable {
        let id: String
        let name: String
        let colorHex: String
    }
}

// MARK: - Backup Service

@MainActor
final class BackupService: ObservableObject {
    static let shared = BackupService()

    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var lastBackupDate: Date?

    private let backupVersion = "2.0"

    private init() {
        loadLastBackupDate()
    }

    // MARK: - Export

    func exportBackup(modelContext: ModelContext) throws -> Data {
        isExporting = true
        defer { isExporting = false }

        // Fetch all data
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let categories = try modelContext.fetch(FetchDescriptor<Category>())
        let budgets = try modelContext.fetch(FetchDescriptor<Budget>())
        let savingsGoals = try modelContext.fetch(FetchDescriptor<SavingsGoal>())
        let wallets = try modelContext.fetch(FetchDescriptor<Wallet>())
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())

        // Convert to backup format
        let backup = BackupData(
            version: backupVersion,
            createdAt: Date(),
            transactions: transactions.map { transaction in
                BackupData.TransactionBackup(
                    id: transaction.id.uuidString,
                    amount: "\(transaction.amount)",
                    type: transaction.type.rawValue,
                    categoryId: transaction.category?.id.uuidString,
                    walletId: transaction.wallet?.id.uuidString,
                    note: transaction.note,
                    date: transaction.date,
                    currencyCode: transaction.currencyCode,
                    tagNames: transaction.tagNames,
                    createdAt: transaction.createdAt
                )
            },
            categories: categories.map { category in
                BackupData.CategoryBackup(
                    id: category.id.uuidString,
                    name: category.name,
                    icon: category.icon,
                    colorHex: category.colorHex,
                    type: category.type.rawValue,
                    isDefault: category.isDefault
                )
            },
            budgets: budgets.map { budget in
                BackupData.BudgetBackup(
                    id: budget.id.uuidString,
                    amount: "\(budget.amount)",
                    period: budget.period.rawValue,
                    startDate: budget.startDate,
                    categoryId: budget.category?.id.uuidString
                )
            },
            savingsGoals: savingsGoals.map { goal in
                BackupData.SavingsGoalBackup(
                    id: goal.id.uuidString,
                    name: goal.name,
                    targetAmount: "\(goal.targetAmount)",
                    currentAmount: "\(goal.currentAmount)",
                    deadline: goal.deadline,
                    icon: goal.icon,
                    colorHex: goal.colorHex,
                    note: goal.note,
                    isCompleted: goal.isCompleted
                )
            },
            wallets: wallets.map { wallet in
                BackupData.WalletBackup(
                    id: wallet.id.uuidString,
                    name: wallet.name,
                    icon: wallet.icon,
                    colorHex: wallet.colorHex,
                    balance: "\(wallet.balance)",
                    isDefault: wallet.isDefault
                )
            },
            tags: tags.map { tag in
                BackupData.TagBackup(
                    id: tag.id.uuidString,
                    name: tag.name,
                    colorHex: tag.colorHex
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(backup)

        // Save last backup date
        lastBackupDate = Date()
        saveLastBackupDate()

        logInfo("Backup created with \(transactions.count) transactions", category: "Backup")

        return data
    }

    func getBackupFileURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "LetsTrack_Backup_\(dateString).json"

        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Import

    func importBackup(from data: Data, modelContext: ModelContext) throws -> ImportResult {
        isImporting = true
        defer { isImporting = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(BackupData.self, from: data)

        var result = ImportResult()

        // Import categories first (transactions depend on them)
        var categoryMap: [String: Category] = [:]
        for categoryBackup in backup.categories {
            let category = Category(
                name: categoryBackup.name,
                icon: categoryBackup.icon,
                colorHex: categoryBackup.colorHex,
                type: TransactionType(rawValue: categoryBackup.type) ?? .expense
            )
            category.isDefault = categoryBackup.isDefault
            modelContext.insert(category)
            categoryMap[categoryBackup.id] = category
            result.categoriesImported += 1
        }

        // Import wallets
        var walletMap: [String: Wallet] = [:]
        for walletBackup in backup.wallets {
            let wallet = Wallet(
                name: walletBackup.name,
                icon: walletBackup.icon,
                colorHex: walletBackup.colorHex,
                balance: Decimal(string: walletBackup.balance) ?? 0,
                isDefault: walletBackup.isDefault
            )
            modelContext.insert(wallet)
            walletMap[walletBackup.id] = wallet
            result.walletsImported += 1
        }

        // Import transactions
        for transactionBackup in backup.transactions {
            let transaction = Transaction(
                amount: Decimal(string: transactionBackup.amount) ?? 0,
                type: TransactionType(rawValue: transactionBackup.type) ?? .expense,
                category: transactionBackup.categoryId.flatMap { categoryMap[$0] },
                wallet: transactionBackup.walletId.flatMap { walletMap[$0] },
                note: transactionBackup.note,
                date: transactionBackup.date,
                currency: Currency(rawValue: transactionBackup.currencyCode) ?? .usd,
                tagNames: transactionBackup.tagNames
            )
            modelContext.insert(transaction)
            result.transactionsImported += 1
        }

        // Import budgets
        for budgetBackup in backup.budgets {
            let budget = Budget(
                amount: Decimal(string: budgetBackup.amount) ?? 0,
                period: BudgetPeriod(rawValue: budgetBackup.period) ?? .monthly,
                category: budgetBackup.categoryId.flatMap { categoryMap[$0] },
                startDate: budgetBackup.startDate
            )
            modelContext.insert(budget)
            result.budgetsImported += 1
        }

        // Import savings goals
        for goalBackup in backup.savingsGoals {
            let goal = SavingsGoal(
                name: goalBackup.name,
                targetAmount: Decimal(string: goalBackup.targetAmount) ?? 0,
                currentAmount: Decimal(string: goalBackup.currentAmount) ?? 0,
                deadline: goalBackup.deadline,
                icon: goalBackup.icon,
                colorHex: goalBackup.colorHex,
                note: goalBackup.note
            )
            goal.isCompleted = goalBackup.isCompleted
            modelContext.insert(goal)
            result.savingsGoalsImported += 1
        }

        // Import tags
        for tagBackup in backup.tags {
            let tag = Tag(
                name: tagBackup.name,
                colorHex: tagBackup.colorHex
            )
            modelContext.insert(tag)
            result.tagsImported += 1
        }

        try modelContext.save()

        logInfo("Backup imported: \(result.summary)", category: "Backup")

        return result
    }

    // MARK: - Helper Methods

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
    }
}

// MARK: - Import Result

struct ImportResult {
    var transactionsImported: Int = 0
    var categoriesImported: Int = 0
    var budgetsImported: Int = 0
    var savingsGoalsImported: Int = 0
    var walletsImported: Int = 0
    var tagsImported: Int = 0

    var totalImported: Int {
        transactionsImported + categoriesImported + budgetsImported +
        savingsGoalsImported + walletsImported + tagsImported
    }

    var summary: String {
        "\(transactionsImported) transactions, \(categoriesImported) categories, \(budgetsImported) budgets, \(savingsGoalsImported) goals, \(walletsImported) wallets, \(tagsImported) tags"
    }
}

// MARK: - Backup Document

struct BackupDocument: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { document in
            document.data
        }
    }
}
