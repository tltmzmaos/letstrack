import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(sort: \Category.sortOrder)
    private var allCategories: [Category]

    @State private var showingAddBudget = false
    @State private var editingBudget: Budget?
    @State private var isLoading = true
    @State private var totalSpent: Decimal = 0
    @State private var categorySpending: [UUID: Decimal] = [:]

    private var expenseCategories: [Category] {
        allCategories.filter { $0.type == .expense }
    }

    private var totalBudget: Budget? {
        budgets.first { $0.category == nil }
    }

    private var categoryBudgets: [Budget] {
        budgets.filter { $0.category != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        // Total Budget Card
                        TotalBudgetCard(
                            budget: totalBudget,
                            spentAmount: totalSpent,
                            onEdit: { budget in
                                editingBudget = budget
                            },
                            onAdd: {
                                showingAddBudget = true
                            }
                        )

                        // Category Budgets
                        if !categoryBudgets.isEmpty {
                            CategoryBudgetsSection(
                                budgets: categoryBudgets,
                                categorySpending: categorySpending,
                                onEdit: { budget in
                                    editingBudget = budget
                                }
                            )
                        }

                        // Add Category Budget Button
                        Button {
                            showingAddBudget = true
                        } label: {
                            Label(String(localized: "budget.add"), systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "budget.title"))
            .sheet(isPresented: $showingAddBudget) {
                BudgetEditView(categories: expenseCategories)
                    .onDisappear { Task { await loadSpendingData() } }
            }
            .sheet(item: $editingBudget) { budget in
                BudgetEditView(budget: budget, categories: expenseCategories)
                    .onDisappear { Task { await loadSpendingData() } }
            }
            .task {
                await loadSpendingData()
            }
        }
    }

    @MainActor
    private func loadSpendingData() async {
        isLoading = true
        await Task.yield()

        let repository = TransactionRepository(modelContext: modelContext)
        let now = Date()

        totalSpent = (try? repository.totalExpense(from: now.startOfMonth, to: now.endOfMonth)) ?? 0

        let expenses = (try? repository.expenseByCategory(from: now.startOfMonth, to: now.endOfMonth)) ?? []
        var spending: [UUID: Decimal] = [:]
        for item in expenses {
            spending[item.category.id] = item.amount
        }
        categorySpending = spending

        isLoading = false
    }
}

// MARK: - Total Budget Card
struct TotalBudgetCard: View {
    let budget: Budget?
    let spentAmount: Decimal
    let onEdit: (Budget) -> Void
    let onAdd: () -> Void

    private var remainingAmount: Decimal {
        (budget?.amount ?? 0) - spentAmount
    }

    private var progressValue: Double {
        guard let budget = budget, budget.amount > 0 else { return 0 }
        return min((spentAmount / budget.amount).doubleValue, 1.0)
    }

    private var progressColor: Color {
        if progressValue >= 1.0 {
            return .red
        } else if progressValue >= 0.8 {
            return .orange
        }
        return .green
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "budget.this_month"))
                    .font(.headline)
                Spacer()
                if let budget = budget {
                    Button {
                        onEdit(budget)
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                    }
                }
            }

            if let budget = budget {
                VStack(spacing: 12) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 12)

                        Circle()
                            .trim(from: 0, to: progressValue)
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.5), value: progressValue)

                        VStack(spacing: 4) {
                            Text(CurrencySettings.shared.defaultCurrency.format(spentAmount))
                                .font(.title2.bold())

                            Text("/ \(CurrencySettings.shared.defaultCurrency.format(budget.amount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)

                    // Remaining
                    HStack {
                        VStack(alignment: .leading) {
                            Text(String(localized: "budget.remaining"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencySettings.shared.defaultCurrency.format(remainingAmount))
                                .font(.title3.bold())
                                .foregroundStyle(remainingAmount >= 0 ? .green : .red)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(String(localized: "budget.usage"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", progressValue * 100))
                                .font(.title3.bold())
                                .foregroundStyle(progressColor)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "budget.setup_description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button(String(localized: "budget.setup")) {
                        onAdd()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category Budgets Section
struct CategoryBudgetsSection: View {
    let budgets: [Budget]
    let categorySpending: [UUID: Decimal]
    let onEdit: (Budget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "budget.category_budgets"))
                .font(.headline)

            ForEach(budgets, id: \.id) { budget in
                if let category = budget.category {
                    CategoryBudgetRow(
                        budget: budget,
                        category: category,
                        spentAmount: categorySpending[category.id] ?? 0
                    )
                    .onTapGesture {
                        onEdit(budget)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CategoryBudgetRow: View {
    let budget: Budget
    let category: Category
    let spentAmount: Decimal

    private var progressValue: Double {
        guard budget.amount > 0 else { return 0 }
        return min((spentAmount / budget.amount).doubleValue, 1.0)
    }

    private var isOverBudget: Bool {
        spentAmount > budget.amount
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 24)

                Text(category.name)
                    .font(.subheadline)

                Spacer()

                Text("\(CurrencySettings.shared.defaultCurrency.format(spentAmount)) / \(CurrencySettings.shared.defaultCurrency.format(budget.amount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverBudget ? Color.red : category.color)
                        .frame(width: geometry.size.width * progressValue, height: 8)
                        .animation(.easeOut(duration: 0.3), value: progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Budget Edit View
struct BudgetEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget?
    let categories: [Category]

    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var period: BudgetPeriod

    private var isEditing: Bool {
        budget != nil
    }

    private var isValid: Bool {
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            return false
        }
        return true
    }

    init(budget: Budget? = nil, categories: [Category]) {
        self.budget = budget
        self.categories = categories
        self._amount = State(initialValue: budget != nil ? "\(budget!.amount)" : "")
        self._selectedCategory = State(initialValue: budget?.category)
        self._period = State(initialValue: budget?.period ?? .monthly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "transactions.amount")) {
                    HStack {
                        Text(CurrencySettings.shared.defaultCurrency.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("0", text: $amount)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(String(localized: "budget.period")) {
                    Picker(String(localized: "budget.period"), selection: $period) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "budget.category_optional")) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(.blue)
                            Text(String(localized: "budget.total_budget"))
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(categories, id: \.id) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                Text(category.name)
                                Spacer()
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteBudget()
                        } label: {
                            HStack {
                                Spacer()
                                Label(String(localized: "budget.delete"), systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "budget.edit") : String(localized: "budget.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveBudget()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveBudget() {
        guard let amountDecimal = Decimal(string: amount) else { return }

        if let budget = budget {
            budget.amount = amountDecimal
            budget.period = period
            budget.category = selectedCategory
        } else {
            let newBudget = Budget(
                amount: amountDecimal,
                period: period,
                category: selectedCategory
            )
            modelContext.insert(newBudget)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteBudget() {
        if let budget = budget {
            modelContext.delete(budget)
            try? modelContext.save()
        }
        dismiss()
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
