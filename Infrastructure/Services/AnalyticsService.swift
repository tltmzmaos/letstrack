import Foundation
import SwiftData

// MARK: - Spending Trend

struct SpendingTrend: Identifiable {
    let id = UUID()
    let period: String
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
    let date: Date

    var changeFromPrevious: Decimal?
    var changePercentage: Double?
}

// MARK: - Category Spending

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
}

// MARK: - Budget Prediction

struct BudgetPrediction {
    let currentSpent: Decimal
    let predictedTotal: Decimal
    let budgetAmount: Decimal
    let daysInPeriod: Int
    let daysElapsed: Int
    let dailyAverage: Decimal
    let remainingBudget: Decimal
    let predictedOverage: Decimal
    let isOnTrack: Bool
    let confidence: Double

    var usagePercentage: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(truncating: (currentSpent / budgetAmount) as NSDecimalNumber) * 100
    }

    var predictedUsagePercentage: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(truncating: (predictedTotal / budgetAmount) as NSDecimalNumber) * 100
    }
}

// MARK: - Top Expense

struct TopExpense: Identifiable {
    let id = UUID()
    let transaction: Transaction
    let rank: Int
}

// MARK: - Day/Time Analysis

struct SpendingByDayOfWeek: Identifiable {
    let id = UUID()
    let dayOfWeek: Int  // 1 = Sunday, 7 = Saturday
    let dayName: String
    let totalAmount: Decimal
    let averageAmount: Decimal
    let transactionCount: Int
}

struct SpendingByHour: Identifiable {
    let id = UUID()
    let hour: Int
    let totalAmount: Decimal
    let transactionCount: Int
}

// MARK: - Detected Recurring Pattern

struct DetectedRecurringPattern: Identifiable {
    let id = UUID()
    let category: Category?
    let averageAmount: Decimal
    let frequency: String  // "monthly", "weekly"
    let occurrences: Int
    let lastOccurrence: Date
    let nextExpected: Date?
    let note: String?
    let confidence: Double  // 0.0 - 1.0
}

// MARK: - Category Trend

struct CategoryTrend: Identifiable {
    let id = UUID()
    let category: Category
    let currentMonthAmount: Decimal
    let previousMonthAmount: Decimal
    let change: Decimal
    let changePercentage: Double
    let isIncreasing: Bool
    let averageMonthlyAmount: Decimal
    let transactionCount: Int
}

// MARK: - Analytics Service

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Spending Trends

    func getMonthlyTrends(
        transactions: [Transaction],
        months: Int = 6
    ) -> [SpendingTrend] {
        let calendar = Calendar.current
        let now = Date()

        var trends: [SpendingTrend] = []

        for monthOffset in (0..<months).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
            else { continue }

            let monthTransactions = transactions.filter {
                $0.date >= monthStart && $0.date <= monthEnd
            }

            let income = monthTransactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }

            let expense = monthTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }

            let formatter = DateFormatter()
            // Only show year if different from current year
            let currentYear = calendar.component(.year, from: now)
            let trendYear = calendar.component(.year, from: monthDate)
            formatter.dateFormat = trendYear == currentYear ? "MMM" : "MMM yy"

            var trend = SpendingTrend(
                period: formatter.string(from: monthDate),
                income: income,
                expense: expense,
                balance: income - expense,
                date: monthDate
            )

            // Calculate change from previous month
            if let previousTrend = trends.last {
                let change = expense - previousTrend.expense
                trend.changeFromPrevious = change

                if previousTrend.expense > 0 {
                    trend.changePercentage = Double(truncating: (change / previousTrend.expense) as NSDecimalNumber) * 100
                }
            }

            trends.append(trend)
        }

        return trends
    }

    // MARK: - Category Analysis

    func getCategoryBreakdown(
        transactions: [Transaction],
        type: TransactionType = .expense
    ) -> [CategorySpending] {
        let filteredTransactions = transactions.filter { $0.type == type }
        let total = filteredTransactions.reduce(Decimal.zero) { $0 + $1.amount }

        let grouped = Dictionary(grouping: filteredTransactions) { $0.category }

        var results: [CategorySpending] = []

        for (category, categoryTransactions) in grouped {
            guard let category = category else { continue }

            let amount = categoryTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            let percentage = total > 0
                ? Double(truncating: (amount / total) as NSDecimalNumber) * 100
                : 0

            results.append(CategorySpending(
                category: category,
                amount: amount,
                percentage: percentage,
                transactionCount: categoryTransactions.count
            ))
        }

        return results.sorted { $0.amount > $1.amount }
    }

    // MARK: - Budget Prediction

    func predictBudget(
        budget: Budget,
        transactions: [Transaction]
    ) -> BudgetPrediction {
        let calendar = Calendar.current
        let now = Date()

        // Calculate period dates
        let (periodStart, periodEnd) = budget.currentPeriodDates

        // Filter transactions for current period
        let periodTransactions = transactions.filter { transaction in
            transaction.date >= periodStart &&
            transaction.date <= periodEnd &&
            transaction.type == .expense &&
            (budget.category == nil || transaction.category?.id == budget.category?.id)
        }

        let currentSpent = periodTransactions.reduce(Decimal.zero) { $0 + $1.amount }

        // Calculate days
        let totalDays = calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 30
        let daysElapsed = max(calendar.dateComponents([.day], from: periodStart, to: now).day ?? 1, 1)

        // Calculate daily average and prediction
        let dailyAverage = currentSpent / Decimal(daysElapsed)
        let predictedTotal = dailyAverage * Decimal(totalDays)

        // Calculate budget status
        let remainingBudget = budget.amount - currentSpent
        let predictedOverage = max(predictedTotal - budget.amount, 0)

        // Determine if on track
        let expectedSpentByNow = (budget.amount / Decimal(totalDays)) * Decimal(daysElapsed)
        let isOnTrack = currentSpent <= expectedSpentByNow

        // Calculate confidence based on days elapsed
        let confidence = min(Double(daysElapsed) / Double(totalDays) * 100, 100)

        return BudgetPrediction(
            currentSpent: currentSpent,
            predictedTotal: predictedTotal,
            budgetAmount: budget.amount,
            daysInPeriod: totalDays,
            daysElapsed: daysElapsed,
            dailyAverage: dailyAverage,
            remainingBudget: remainingBudget,
            predictedOverage: predictedOverage,
            isOnTrack: isOnTrack,
            confidence: confidence
        )
    }

    // MARK: - Top Expenses

    func getTopExpenses(
        transactions: [Transaction],
        limit: Int = 10,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) -> [TopExpense] {
        var filtered = transactions.filter { $0.type == .expense }

        if let startDate = startDate {
            filtered = filtered.filter { $0.date >= startDate }
        }

        if let endDate = endDate {
            filtered = filtered.filter { $0.date <= endDate }
        }

        let sorted = filtered.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.enumerated().map { index, transaction in
            TopExpense(transaction: transaction, rank: index + 1)
        }
    }

    // MARK: - Day of Week Analysis

    func getSpendingByDayOfWeek(
        transactions: [Transaction]
    ) -> [SpendingByDayOfWeek] {
        let calendar = Calendar.current
        let expenses = transactions.filter { $0.type == .expense }

        let grouped = Dictionary(grouping: expenses) { transaction -> Int in
            calendar.component(.weekday, from: transaction.date)
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        return (1...7).map { dayOfWeek in
            let dayTransactions = grouped[dayOfWeek] ?? []
            let total = dayTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            let count = dayTransactions.count
            let average = count > 0 ? total / Decimal(count) : 0

            // Create a date for this day of week to get the name
            var components = DateComponents()
            components.weekday = dayOfWeek
            let date = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
            let dayName = dayFormatter.string(from: date)

            return SpendingByDayOfWeek(
                dayOfWeek: dayOfWeek,
                dayName: dayName,
                totalAmount: total,
                averageAmount: average,
                transactionCount: count
            )
        }
    }

    // MARK: - Hour Analysis

    func getSpendingByHour(
        transactions: [Transaction]
    ) -> [SpendingByHour] {
        let calendar = Calendar.current
        let expenses = transactions.filter { $0.type == .expense }

        let grouped = Dictionary(grouping: expenses) { transaction -> Int in
            calendar.component(.hour, from: transaction.date)
        }

        return (0..<24).map { hour in
            let hourTransactions = grouped[hour] ?? []
            let total = hourTransactions.reduce(Decimal.zero) { $0 + $1.amount }

            return SpendingByHour(
                hour: hour,
                totalAmount: total,
                transactionCount: hourTransactions.count
            )
        }
    }

    // MARK: - Comparison

    func compareMonths(
        transactions: [Transaction],
        month1: Date,
        month2: Date
    ) -> (month1Total: Decimal, month2Total: Decimal, difference: Decimal, percentChange: Double) {
        let calendar = Calendar.current

        func getMonthTotal(_ date: Date) -> Decimal {
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
            else { return 0 }

            return transactions
                .filter { $0.date >= monthStart && $0.date <= monthEnd && $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
        }

        let total1 = getMonthTotal(month1)
        let total2 = getMonthTotal(month2)
        let difference = total2 - total1

        let percentChange: Double
        if total1 > 0 {
            percentChange = Double(truncating: (difference / total1) as NSDecimalNumber) * 100
        } else {
            percentChange = total2 > 0 ? 100 : 0
        }

        return (total1, total2, difference, percentChange)
    }

    // MARK: - Recurring Pattern Detection

    func detectRecurringPatterns(
        transactions: [Transaction],
        minOccurrences: Int = 3,
        minConfidence: Double = 0.6
    ) -> [DetectedRecurringPattern] {
        let calendar = Calendar.current
        let expenses = transactions.filter { $0.type == .expense }

        // Group by category and similar amounts (within 10% tolerance)
        var patterns: [DetectedRecurringPattern] = []

        // Group transactions by category
        let groupedByCategory = Dictionary(grouping: expenses) { $0.category }

        for (category, categoryTransactions) in groupedByCategory {
            guard let category = category else { continue }

            // Group by similar amounts (within 15% tolerance)
            let amountGroups = groupTransactionsByAmount(categoryTransactions, tolerance: 0.15)

            for group in amountGroups {
                guard group.count >= minOccurrences else { continue }

                // Detect frequency pattern
                let sortedDates = group.map { $0.date }.sorted()

                if let frequencyResult = detectFrequency(dates: sortedDates) {
                    let averageAmount = group.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(group.count)

                    // Calculate next expected date
                    let lastDate = sortedDates.last ?? Date()
                    let nextExpected: Date?
                    switch frequencyResult.frequency {
                    case "monthly":
                        nextExpected = calendar.date(byAdding: .month, value: 1, to: lastDate)
                    case "weekly":
                        nextExpected = calendar.date(byAdding: .weekOfYear, value: 1, to: lastDate)
                    case "biweekly":
                        nextExpected = calendar.date(byAdding: .weekOfYear, value: 2, to: lastDate)
                    default:
                        nextExpected = nil
                    }

                    // Get common note from transactions
                    let notes = group.compactMap { $0.note }.filter { !$0.isEmpty }
                    let commonNote = notes.first

                    if frequencyResult.confidence >= minConfidence {
                        patterns.append(DetectedRecurringPattern(
                            category: category,
                            averageAmount: averageAmount,
                            frequency: frequencyResult.frequency,
                            occurrences: group.count,
                            lastOccurrence: lastDate,
                            nextExpected: nextExpected,
                            note: commonNote,
                            confidence: frequencyResult.confidence
                        ))
                    }
                }
            }
        }

        return patterns.sorted { $0.confidence > $1.confidence }
    }

    private func groupTransactionsByAmount(
        _ transactions: [Transaction],
        tolerance: Double
    ) -> [[Transaction]] {
        var groups: [[Transaction]] = []

        for transaction in transactions {
            var foundGroup = false
            for i in groups.indices {
                if let first = groups[i].first {
                    let ratio = Double(truncating: (transaction.amount / first.amount) as NSDecimalNumber)
                    if ratio >= (1 - tolerance) && ratio <= (1 + tolerance) {
                        groups[i].append(transaction)
                        foundGroup = true
                        break
                    }
                }
            }
            if !foundGroup {
                groups.append([transaction])
            }
        }

        return groups
    }

    private func detectFrequency(dates: [Date]) -> (frequency: String, confidence: Double)? {
        guard dates.count >= 2 else { return nil }

        let calendar = Calendar.current
        var intervals: [Int] = []

        for i in 1..<dates.count {
            let days = calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? 0
            intervals.append(days)
        }

        guard !intervals.isEmpty else { return nil }

        let averageInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let variance = intervals.map { pow(Double($0) - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)

        // Determine frequency based on average interval
        let frequency: String
        let expectedInterval: Double

        if averageInterval >= 25 && averageInterval <= 35 {
            frequency = "monthly"
            expectedInterval = 30
        } else if averageInterval >= 12 && averageInterval <= 16 {
            frequency = "biweekly"
            expectedInterval = 14
        } else if averageInterval >= 5 && averageInterval <= 9 {
            frequency = "weekly"
            expectedInterval = 7
        } else {
            return nil
        }

        // Calculate confidence based on how consistent the intervals are
        let normalizedStdDev = stdDev / expectedInterval
        let confidence = max(0, min(1, 1 - normalizedStdDev))

        return (frequency, confidence)
    }

    // MARK: - Category Trends

    func getCategoryTrends(
        transactions: [Transaction],
        months: Int = 3
    ) -> [CategoryTrend] {
        let calendar = Calendar.current
        let now = Date()

        // Get current month dates
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let currentMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentMonthStart),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
              let previousMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: previousMonthStart)
        else { return [] }

        // Get transactions for analysis period (for average calculation)
        guard let analysisStart = calendar.date(byAdding: .month, value: -months, to: currentMonthStart) else {
            return []
        }

        let expenses = transactions.filter { $0.type == .expense && $0.date >= analysisStart }

        // Group by category
        let groupedByCategory = Dictionary(grouping: expenses) { $0.category }

        var trends: [CategoryTrend] = []

        for (category, categoryTransactions) in groupedByCategory {
            guard let category = category else { continue }

            // Current month spending
            let currentMonthTransactions = categoryTransactions.filter {
                $0.date >= currentMonthStart && $0.date <= currentMonthEnd
            }
            let currentMonthAmount = currentMonthTransactions.reduce(Decimal.zero) { $0 + $1.amount }

            // Previous month spending
            let previousMonthTransactions = categoryTransactions.filter {
                $0.date >= previousMonthStart && $0.date <= previousMonthEnd
            }
            let previousMonthAmount = previousMonthTransactions.reduce(Decimal.zero) { $0 + $1.amount }

            // Calculate change
            let change = currentMonthAmount - previousMonthAmount
            let changePercentage: Double
            if previousMonthAmount > 0 {
                changePercentage = Double(truncating: (change / previousMonthAmount) as NSDecimalNumber) * 100
            } else {
                changePercentage = currentMonthAmount > 0 ? 100 : 0
            }

            // Calculate average monthly amount
            let totalAmount = categoryTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            let averageMonthlyAmount = totalAmount / Decimal(months)

            trends.append(CategoryTrend(
                category: category,
                currentMonthAmount: currentMonthAmount,
                previousMonthAmount: previousMonthAmount,
                change: change,
                changePercentage: changePercentage,
                isIncreasing: change > 0,
                averageMonthlyAmount: averageMonthlyAmount,
                transactionCount: currentMonthTransactions.count
            ))
        }

        // Sort by absolute change percentage (most significant changes first)
        return trends.sorted { abs($0.changePercentage) > abs($1.changePercentage) }
    }
}
