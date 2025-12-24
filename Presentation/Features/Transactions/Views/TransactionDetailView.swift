import SwiftUI
import SwiftData
import MapKit

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var transaction: Transaction

    @State private var transactionType: TransactionType
    @State private var amountText: String
    @State private var selectedCategory: Category?
    @State private var note: String
    @State private var date: Date
    @State private var selectedCurrency: Currency
    @State private var receiptImageData: Data?
    @State private var categories: [Category] = []
    @State private var showingDeleteAlert = false
    @State private var selectedTagNames: Set<String>
    @State private var selectedLocation: TransactionLocation?
    @State private var showLocationPicker: Bool = false
    @State private var allTags: [Tag] = []
    @State private var isLocationLoading: Bool = false

    private var amount: Decimal {
        Decimal.parseLocalized(amountText) ?? 0
    }

    private var isValid: Bool {
        amount > 0 && selectedCategory != nil
    }

    private var hasChanges: Bool {
        transactionType != transaction.type ||
        amount != transaction.amount ||
        selectedCategory?.id != transaction.category?.id ||
        note != transaction.note ||
        selectedCurrency != transaction.currency ||
        receiptImageData != transaction.receiptImageData ||
        selectedTagNames != Set(transaction.tagNames) ||
        !Calendar.current.isDate(date, inSameDayAs: transaction.date) ||
        hasLocationChanged
    }

    private var hasLocationChanged: Bool {
        let originalLat = transaction.latitude
        let originalLon = transaction.longitude
        let newLat = selectedLocation?.latitude
        let newLon = selectedLocation?.longitude
        return originalLat != newLat || originalLon != newLon
    }

    init(transaction: Transaction) {
        self.transaction = transaction
        self._transactionType = State(initialValue: transaction.type)
        self._amountText = State(initialValue: "\(transaction.amount)")
        self._selectedCategory = State(initialValue: transaction.category)
        self._note = State(initialValue: transaction.note)
        self._date = State(initialValue: transaction.date)
        self._selectedCurrency = State(initialValue: transaction.currency)
        self._receiptImageData = State(initialValue: transaction.receiptImageData)
        self._selectedTagNames = State(initialValue: Set(transaction.tagNames))

        // Initialize location if exists
        if let lat = transaction.latitude, let lon = transaction.longitude {
            self._selectedLocation = State(initialValue: TransactionLocation(
                latitude: lat,
                longitude: lon,
                name: transaction.locationName,
                address: nil
            ))
        } else {
            self._selectedLocation = State(initialValue: nil)
        }
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
                deleteSection
            }
            .navigationTitle(String(localized: "transactions.edit"))
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
                        saveChanges()
                    }
                    .disabled(!isValid || !hasChanges)
                    .fontWeight(.semibold)
                }
            }
            .alert(String(localized: "transactions.delete"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    deleteTransaction()
                }
            } message: {
                Text(String(localized: "transactions.delete_confirm"))
            }
            .onAppear {
                loadData()
            }
            .onChange(of: transactionType) {
                if selectedCategory?.type != transactionType {
                    selectedCategory = categories.first { $0.type == transactionType }
                }
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
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var categorySection: some View {
        Section(String(localized: "transactions.category")) {
            CategorySelectionGrid(
                categories: categories,
                transactionType: transactionType,
                selectedCategory: $selectedCategory
            )
        }
    }

    private var noteSection: some View {
        Section(String(localized: "transactions.note")) {
            TextField(String(localized: "transactions.note_placeholder"), text: $note)
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

        if case .success(let location) = result {
            selectedLocation = location
        }
    }

    private var dateSection: some View {
        Section(String(localized: "transactions.date")) {
            DatePicker(String(localized: "transactions.date"), selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Label(String(localized: "transactions.delete"), systemImage: "trash")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func loadData() {
        let preloader = AppDataPreloader.shared

        if !preloader.categories.isEmpty {
            categories = preloader.categories
        } else {
            let repository = CategoryRepository(modelContext: modelContext)
            categories = (try? repository.fetchAll()) ?? []
            preloader.updateCategories(categories)
        }

        if !preloader.tags.isEmpty {
            allTags = preloader.tags
        } else {
            let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
            allTags = (try? modelContext.fetch(tagDescriptor)) ?? []
            preloader.updateTags(allTags)
        }
    }

    private func saveChanges() {
        let oldTags = Set(transaction.tagNames)
        let newTags = selectedTagNames

        for tag in allTags where oldTags.contains(tag.name) && !newTags.contains(tag.name) {
            tag.usageCount = max(0, tag.usageCount - 1)
        }

        for tag in allTags where newTags.contains(tag.name) && !oldTags.contains(tag.name) {
            tag.usageCount += 1
        }

        transaction.update(
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
        try? modelContext.save()
        let preloader = AppDataPreloader.shared
        preloader.refreshTransactions(using: modelContext)
        preloader.refreshTags(using: modelContext)
        dismiss()
    }

    private func deleteTransaction() {
        modelContext.delete(transaction)
        try? modelContext.save()
        let preloader = AppDataPreloader.shared
        preloader.refreshTransactions(using: modelContext)
        preloader.refreshTags(using: modelContext)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Category.self, Budget.self, Tag.self, configurations: config)

    let transaction = Transaction(
        amount: 15000,
        type: .expense,
        note: "점심 식사"
    )
    container.mainContext.insert(transaction)

    return TransactionDetailView(transaction: transaction)
        .modelContainer(container)
}
