import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurringTransactions: [RecurringTransaction]

    @State private var showingAddRecurring = false
    @State private var editingRecurring: RecurringTransaction?

    private var activeTransactions: [RecurringTransaction] {
        recurringTransactions.filter { $0.isActive }
    }

    private var inactiveTransactions: [RecurringTransaction] {
        recurringTransactions.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            List {
                if activeTransactions.isEmpty && inactiveTransactions.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "recurring.no_transactions"), systemImage: "repeat")
                    } description: {
                        Text(String(localized: "recurring.no_transactions_description"))
                    } actions: {
                        Button(String(localized: "recurring.add")) {
                            showingAddRecurring = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    if !activeTransactions.isEmpty {
                        Section(String(localized: "recurring.active")) {
                            ForEach(activeTransactions, id: \.id) { recurring in
                                RecurringTransactionRow(recurring: recurring)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingRecurring = recurring
                                    }
                            }
                            .onDelete { indexSet in
                                deleteRecurrings(at: indexSet, from: activeTransactions)
                            }
                        }
                    }

                    if !inactiveTransactions.isEmpty {
                        Section(String(localized: "recurring.inactive")) {
                            ForEach(inactiveTransactions, id: \.id) { recurring in
                                RecurringTransactionRow(recurring: recurring)
                                    .opacity(0.6)
                            }
                            .onDelete { indexSet in
                                deleteRecurrings(at: indexSet, from: inactiveTransactions)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "recurring.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRecurring = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddRecurring) {
                AddRecurringTransactionView()
            }
            .sheet(item: $editingRecurring) { recurring in
                EditRecurringTransactionView(recurring: recurring)
            }
        }
    }

    private func deleteRecurrings(at offsets: IndexSet, from list: [RecurringTransaction]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Recurring Transaction Row
struct RecurringTransactionRow: View {
    let recurring: RecurringTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            if let category = recurring.category {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .frame(width: 40, height: 40)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "repeat.circle")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.note.isEmpty ? (recurring.category?.name ?? String(localized: "recurring.title")) : recurring.note)
                    .font(.body.weight(.medium))

                HStack(spacing: 4) {
                    Text(recurring.frequency.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text("\(String(localized: "recurring.next_date")): \(recurring.nextDueDate.shortDateString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(recurring.type == .income ? "+\(recurring.amount.formatted())" : "-\(recurring.amount.formatted())")
                .font(.body.bold())
                .foregroundStyle(recurring.type == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Recurring Transaction View
struct AddRecurringTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var transactionType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var categories: [Category] = []
    @State private var isLoadingCategories: Bool = true

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    private var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }

    private var isValid: Bool {
        amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction Type
                Section {
                    Picker(String(localized: "transactions.type.expense"), selection: $transactionType) {
                        Text(String(localized: "transactions.type.expense")).tag(TransactionType.expense)
                        Text(String(localized: "transactions.type.income")).tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // Amount
                Section(String(localized: "transactions.amount")) {
                    HStack {
                        Text(currency.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("0", text: $amountText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Frequency
                Section(String(localized: "recurring.frequency")) {
                    Picker(String(localized: "recurring.frequency"), selection: $frequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                // Category
                Section(String(localized: "transactions.category")) {
                    if isLoadingCategories {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                            ForEach(categories.filter { $0.type == transactionType }, id: \.id) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Note
                Section(String(localized: "transactions.note")) {
                    TextField(String(localized: "recurring.note_example"), text: $note)
                }

                // Start Date
                Section(String(localized: "recurring.start_date")) {
                    DatePicker(String(localized: "recurring.start_date"), selection: $startDate, displayedComponents: .date)
                }

                // End Date (Optional)
                Section(String(localized: "recurring.end_date_optional")) {
                    Toggle(String(localized: "recurring.set_end_date"), isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(String(localized: "recurring.end_date"), selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(String(localized: "recurring.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveRecurring()
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                await loadCategoriesAsync()
            }
            .onChange(of: transactionType) {
                selectedCategory = categories.first { $0.type == transactionType }
            }
        }
    }

    @MainActor
    private func loadCategoriesAsync() async {
        let repository = CategoryRepository(modelContext: modelContext)
        try? repository.setupDefaultCategoriesIfNeeded()
        categories = (try? repository.fetchAll()) ?? []
        selectedCategory = categories.first { $0.type == transactionType }
        isLoadingCategories = false
    }

    private func saveRecurring() {
        let repository = RecurringTransactionRepository(modelContext: modelContext)
        _ = try? repository.create(
            amount: amount,
            type: transactionType,
            category: selectedCategory,
            note: note,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil
        )
        dismiss()
    }
}

// MARK: - Edit Recurring Transaction View
struct EditRecurringTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var recurring: RecurringTransaction

    @State private var amountText: String
    @State private var note: String
    @State private var frequency: RecurringFrequency
    @State private var isActive: Bool
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showingDeleteAlert = false

    private let currency: Currency = CurrencySettings.shared.defaultCurrency

    init(recurring: RecurringTransaction) {
        self.recurring = recurring
        self._amountText = State(initialValue: "\(recurring.amount)")
        self._note = State(initialValue: recurring.note)
        self._frequency = State(initialValue: recurring.frequency)
        self._isActive = State(initialValue: recurring.isActive)
        self._hasEndDate = State(initialValue: recurring.endDate != nil)
        self._endDate = State(initialValue: recurring.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    }

    private var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "transactions.amount")) {
                    HStack {
                        Text(currency.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("0", text: $amountText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(String(localized: "recurring.frequency")) {
                    Picker(String(localized: "recurring.frequency"), selection: $frequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section(String(localized: "transactions.note")) {
                    TextField(String(localized: "transactions.note"), text: $note)
                }

                Section(String(localized: "recurring.status")) {
                    Toggle(String(localized: "recurring.active"), isOn: $isActive)

                    Toggle(String(localized: "recurring.set_end_date"), isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(String(localized: "recurring.end_date"), selection: $endDate, displayedComponents: .date)
                    }
                }

                Section(String(localized: "recurring.info")) {
                    HStack {
                        Text(String(localized: "recurring.next_date"))
                        Spacer()
                        Text(recurring.nextDueDate.shortDateString)
                            .foregroundStyle(.secondary)
                    }

                    if let lastProcessed = recurring.lastProcessedDate {
                        HStack {
                            Text(String(localized: "recurring.last_processed"))
                            Spacer()
                            Text(lastProcessed.shortDateString)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(String(localized: "common.delete"), systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "recurring.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveChanges()
                    }
                }
            }
            .alert(String(localized: "common.delete"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteRecurring()
                }
            } message: {
                Text(String(localized: "recurring.delete_confirm"))
            }
        }
    }

    private func saveChanges() {
        recurring.amount = amount
        recurring.note = note
        recurring.frequency = frequency
        recurring.isActive = isActive
        recurring.endDate = hasEndDate ? endDate : nil

        try? modelContext.save()
        dismiss()
    }

    private func deleteRecurring() {
        modelContext.delete(recurring)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    RecurringTransactionsView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self, RecurringTransaction.self], inMemory: true)
}
