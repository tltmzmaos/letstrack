import SwiftUI
import SwiftData
import MapKit

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Preloaded data for faster initialization
    var preloadedCategories: [Category] = []
    var preloadedTags: [Tag] = []

    @State private var transactionType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var categories: [Category] = []
    @State private var selectedCurrency: Currency = CurrencySettings.shared.defaultCurrency
    @State private var receiptImageData: Data?
    @State private var selectedTagNames: Set<String> = []
    @State private var isSaving: Bool = false
    @State private var suggestedCategory: Category?
    @State private var userManuallySelectedCategory: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var allTags: [Tag] = []

    // Location state
    @State private var selectedLocation: TransactionLocation?
    @State private var showLocationPicker: Bool = false
    @State private var isLoadingCategories: Bool = true
    @State private var isLocationLoading: Bool = false

    @FocusState private var isAmountFocused: Bool

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let successFeedback = UINotificationFeedbackGenerator()

    private var amount: Decimal {
        Decimal.parseLocalized(amountText) ?? 0
    }

    private var isValid: Bool {
        amount > 0 && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                transactionTypeSection
                amountSection
                categorySection
                noteSection

                if !allTags.isEmpty {
                    tagsSection
                }

                receiptSection
                locationSection
                dateSection
            }
            .navigationTitle(String(localized: "transactions.add"))
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveTransaction()
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                    .opacity(isValid ? 1.0 : 0.5)
                }
            }
            .task {
                await loadDataAsync()
                isAmountFocused = true
            }
            .onChange(of: transactionType) {
                hapticFeedback.impactOccurred()
                selectedCategory = categories.first { $0.type == transactionType }
            }
            .alert(String(localized: "common.error"), isPresented: $showErrorAlert) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - View Sections

    private var transactionTypeSection: some View {
        Section {
            Picker(String(localized: "transactions.type.expense"), selection: $transactionType) {
                Text(String(localized: "transactions.type.expense")).tag(TransactionType.expense)
                Text(String(localized: "transactions.type.income")).tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 8)
        }
    }

    private var amountSection: some View {
        Section(String(localized: "transactions.amount")) {
            HStack {
                CurrencySelector(selectedCurrency: $selectedCurrency)

                TextField("0", text: $amountText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var categorySection: some View {
        Section(String(localized: "transactions.category")) {
            if isLoadingCategories {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                CategorySelectionGrid(
                    categories: categories,
                    transactionType: transactionType,
                    selectedCategory: $selectedCategory
                )
            }
        }
    }

    private var noteSection: some View {
        Section(String(localized: "transactions.note")) {
            TextField(String(localized: "transactions.note_placeholder"), text: $note)
                .onChange(of: note) { _, newValue in
                    updateSmartCategorySuggestion(for: newValue)
                }

            // Smart category suggestion
            if let suggested = suggestedCategory, suggested.id != selectedCategory?.id {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)

                    Text(String(localized: "smart_category.suggestion"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        hapticFeedback.impactOccurred()
                        selectedCategory = suggested
                        userManuallySelectedCategory = true
                    } label: {
                        Label(suggested.name, systemImage: suggested.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(suggested.color.opacity(0.15))
                            .foregroundStyle(suggested.color)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func updateSmartCategorySuggestion(for text: String) {
        guard !text.isEmpty, !userManuallySelectedCategory else {
            suggestedCategory = nil
            return
        }

        let suggested = SmartCategoryService.shared.suggestCategory(
            for: text,
            from: categories.filter { $0.type == transactionType }
        )

        if let suggested = suggested, suggested.id != selectedCategory?.id {
            suggestedCategory = suggested
        } else {
            suggestedCategory = nil
        }
    }

    private var tagsSection: some View {
        Section(String(localized: "tags.title")) {
            TagSelectionView(
                allTags: allTags,
                selectedTagNames: $selectedTagNames
            )
        }
    }

    private var receiptSection: some View {
        Section(String(localized: "receipt.title")) {
            ReceiptPhotoPicker(imageData: $receiptImageData)
        }
    }

    private var locationSection: some View {
        Section(String(localized: "location.title")) {
            if let location = selectedLocation {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name ?? String(localized: "location.unknown"))
                            .font(.subheadline.weight(.medium))

                        if let address = location.address {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        selectedLocation = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 12) {
                    // Auto-detect button
                    Button {
                        Task {
                            await detectCurrentLocation()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isLocationLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(String(localized: "location.detect"))
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocationLoading)

                    // Manual search button
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text(String(localized: "location.search"))
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func detectCurrentLocation() async {
        isLocationLoading = true
        let result = await LocationService.shared.getCurrentLocation()
        isLocationLoading = false

        switch result {
        case .success(let location):
            selectedLocation = location
            hapticFeedback.impactOccurred()
        case .failure(let error):
            if case .permissionDenied = error {
                errorMessage = String(localized: "location.error.permission_denied")
                showErrorAlert = true
            }
        }
    }

    private var dateSection: some View {
        Section(String(localized: "transactions.date")) {
            DatePicker(String(localized: "transactions.date"), selection: $date, displayedComponents: [.date])
                .datePickerStyle(.compact)

            // Quick date selection buttons
            HStack(spacing: 12) {
                QuickDateButton(title: String(localized: "date.today"), isSelected: Calendar.current.isDateInToday(date)) {
                    date = Date()
                }
                QuickDateButton(title: String(localized: "date.yesterday"), isSelected: Calendar.current.isDateInYesterday(date)) {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }
            }
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func loadDataAsync() async {
        let preloader = AppDataPreloader.shared

        // Use preloaded categories if available, otherwise fetch
        if !preloadedCategories.isEmpty {
            categories = preloadedCategories
            isLoadingCategories = false
        } else if !preloader.categories.isEmpty {
            categories = preloader.categories
            isLoadingCategories = false
        } else {
            let categoryRepo = CategoryRepository(modelContext: modelContext)
            categories = (try? categoryRepo.fetchAll()) ?? []
            isLoadingCategories = false
            preloader.updateCategories(categories)
        }
        selectedCategory = categories.first { $0.type == transactionType }

        // Use preloaded tags if available, otherwise fetch
        if !preloadedTags.isEmpty {
            allTags = preloadedTags
        } else if !preloader.tags.isEmpty {
            allTags = preloader.tags
        } else {
            let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
            allTags = (try? modelContext.fetch(tagDescriptor)) ?? []
            preloader.updateTags(allTags)
        }

        selectedCurrency = CurrencySettings.shared.defaultCurrency
    }

    private func saveTransaction() {
        isSaving = true

        let repository = TransactionRepository(modelContext: modelContext)
        do {
            _ = try repository.create(
                amount: amount,
                type: transactionType,
                category: selectedCategory,
                note: note,
                date: date,
                currency: selectedCurrency,
                receiptImageData: receiptImageData,
                tagNames: Array(selectedTagNames),
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                locationName: selectedLocation?.name
            )

            for tag in allTags where selectedTagNames.contains(tag.name) {
                tag.usageCount += 1
            }

            // Learn from user's category selection for smart suggestions
            if let category = selectedCategory, !note.isEmpty {
                SmartCategoryService.shared.learnFromSelection(note: note, category: category)
            }

            // Haptic feedback for successful save
            successFeedback.notificationOccurred(.success)

            let preloader = AppDataPreloader.shared
            preloader.refreshTransactions(using: modelContext)
            preloader.refreshTags(using: modelContext)

            dismiss()
        } catch {
            isSaving = false
            errorMessage = String(localized: "transactions.save_error")
            showErrorAlert = true
            successFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: - Quick Date Button

private struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self, Tag.self], inMemory: true)
}
