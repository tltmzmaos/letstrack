import SwiftUI
import SwiftData
import MapKit

enum TransactionViewMode: String, CaseIterable {
    case list
    case calendar
    case map

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        case .map: return "map"
        }
    }

    var nextMode: TransactionViewMode {
        switch self {
        case .list: return .calendar
        case .calendar: return .map
        case .map: return .list
        }
    }
}

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TransactionsViewModel?
    @State private var showingAddTransaction = false
    @State private var showingVoiceTransaction = false
    @State private var showAddPopover = false
    @State private var selectedTransaction: Transaction?
    @State private var viewMode: TransactionViewMode = .list

    // Calendar states
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showMonthlySummary: Bool = false
    // Cached calendar data
    @State private var calendarTransactions: [Transaction] = []
    @State private var projectedRecurringTransactions: [Transaction] = []
    @State private var nonEditableRecurringIds: Set<UUID> = []
    @State private var combinedCalendarTransactions: [Transaction] = []
    @State private var dailyIndex: [Date: [Transaction]] = [:]
    @State private var cachedMonthlyTransactions: [Transaction] = []
    @State private var cachedMonthlyExpense: Decimal = 0
    @State private var cachedMonthlyIncome: Decimal = 0
    @State private var cachedDailyTransactions: [Transaction] = []

    // Map states
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var mapSelectedTransaction: Transaction?
    @State private var isMapReady: Bool = false
    @State private var mapTransactions: [Transaction] = []
    @State private var mapAnnotations: [TransactionMapAnnotation] = []

    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    @State private var hasAppeared = false

    // Preloaded categories for faster sheet opening
    @State private var preloadedCategories: [Category] = []
    @State private var preloadedTags: [Tag] = []

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Toggle (only for list view)
                if viewMode == .list, let viewModel = viewModel {
                    TransactionFilterToggle(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }

                // Content based on view mode
                switch viewMode {
                case .list:
                    listContent
                case .calendar:
                    calendarContent
                case .map:
                    mapContent
                }
            }
            .navigationTitle(String(localized: "transactions.title"))
            .searchable(text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ), prompt: String(localized: "search.placeholder"))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(TransactionViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue.capitalized, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        // Add button with popover
                        Button {
                            showAddPopover = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .popover(isPresented: $showAddPopover, arrowEdge: .top) {
                            AddMenuPopover(
                                showManualAdd: $showingAddTransaction,
                                showVoiceAdd: $showingVoiceTransaction
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddTransaction) {
                AddTransactionView(
                    preloadedCategories: preloadedCategories,
                    preloadedTags: preloadedTags
                )
                    .onDisappear {
                        viewModel?.loadTransactions()
                        Task { await loadMapData() }
                    }
            }
            .fullScreenCover(isPresented: $showingVoiceTransaction) {
                VoiceTransactionView(preloadedCategories: preloadedCategories)
                    .onDisappear {
                        viewModel?.loadTransactions()
                        Task { await loadMapData() }
                    }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
                    .onDisappear {
                        viewModel?.loadTransactions()
                        Task { await loadMapData() }
                    }
            }
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true

                // Preload categories/tags for faster sheet opening
                let preloader = AppDataPreloader.shared

                if preloadedCategories.isEmpty {
                    if preloader.categories.isEmpty {
                        let categoryRepo = CategoryRepository(modelContext: modelContext)
                        preloadedCategories = (try? categoryRepo.fetchAll()) ?? []
                        preloader.updateCategories(preloadedCategories)
                    } else {
                        preloadedCategories = preloader.categories
                    }
                }

                if preloadedTags.isEmpty {
                    if preloader.tags.isEmpty {
                        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
                        preloadedTags = (try? modelContext.fetch(tagDescriptor)) ?? []
                        preloader.updateTags(preloadedTags)
                    } else {
                        preloadedTags = preloader.tags
                    }
                }

                let vm = TransactionsViewModel(modelContext: modelContext)
                viewModel = vm
                vm.loadTransactions()
            }
            .onChange(of: viewModel?.searchText) { _, newValue in
                // Debounce search to prevent excessive reloads
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        viewModel?.applyFilters()
                    }
                }
            }
            .onChange(of: viewMode) { _, newValue in
                guard newValue == .map else { return }
                isMapReady = false
                Task { await loadMapData() }
            }
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        Group {
            if let viewModel = viewModel {
                if viewModel.transactions.isEmpty {
                    EmptyTransactionsView()
                } else {
                    TransactionListContent(
                        viewModel: viewModel,
                        selectedTransaction: $selectedTransaction
                    )
                }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Calendar Content

    @ViewBuilder
    private var calendarContent: some View {
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
                transactions: combinedCalendarTransactions
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
        .task {
            await loadCalendarData()
        }
        .onChange(of: currentMonth) { _, _ in
            Task {
                await loadRecurringProjections()
                await loadMonthlyData()
            }
        }
        .onChange(of: selectedDate) { _, _ in
            Task { await loadDailyData() }
        }
    }

    // MARK: - Calendar Data Loading

    private func loadCalendarData() async {
        // Load all transactions for calendar grid (with reasonable limit)
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 3000

        do {
            let preloader = AppDataPreloader.shared
            if !preloader.transactions.isEmpty {
                calendarTransactions = Array(preloader.transactions.prefix(3000))
            } else {
                calendarTransactions = try modelContext.fetch(descriptor)
                preloader.updateTransactions(calendarTransactions)
            }
            await loadRecurringProjections()
            rebuildCalendarCache()
            await loadMonthlyData()
            await loadDailyData()
        } catch {
            calendarTransactions = []
        }
    }

    private func rebuildCalendarCache() {
        let combined = calendarTransactions + projectedRecurringTransactions
        combinedCalendarTransactions = combined
        dailyIndex = Dictionary(grouping: combined) { $0.date.startOfDay }
    }

    private func loadMonthlyData() async {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }

        // Filter from cached data instead of re-querying
        cachedMonthlyTransactions = combinedCalendarTransactions.filter { $0.date >= monthStart && $0.date <= monthEnd }

        // Calculate totals in single pass
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

    private func loadDailyData() async {
        cachedDailyTransactions = dailyIndex[selectedDate.startOfDay] ?? []
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
        rebuildCalendarCache()
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        if mapAnnotations.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "map.empty.title"), systemImage: "map")
            } description: {
                Text(String(localized: "map.empty.description"))
            }
            .task {
                await loadMapData()
            }
        } else if !isMapReady {
            // Show loading while map prepares
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(String(localized: "map.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                // Small delay to allow UI thread to breathe
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                isMapReady = true
            }
        } else {
            ZStack {
                Map(position: $mapPosition, selection: $mapSelectedTransaction) {
                    ForEach(mapAnnotations) { annotation in
                        Annotation(
                            annotation.title,
                            coordinate: annotation.coordinate,
                            anchor: .bottom
                        ) {
                            TransactionMapPinView(
                                transaction: annotation.transaction,
                                isSelected: mapSelectedTransaction?.id == annotation.transaction.id
                            )
                        }
                        .tag(annotation.transaction)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .all))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                // Selected transaction card
                if let transaction = mapSelectedTransaction {
                    VStack {
                        Spacer()
                        TransactionMapCardView(transaction: transaction) {
                            selectedTransaction = transaction
                            mapSelectedTransaction = nil
                        }
                        .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mapSelectedTransaction?.id)
            .onAppear {
                fitMapToTransactions()
            }
        }
    }

    private func loadMapData() async {
        // Fetch only transactions with location
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.latitude != nil && $0.longitude != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 500

        do {
            let preloader = AppDataPreloader.shared
            if !preloader.transactions.isEmpty {
                mapTransactions = preloader.transactions
                    .filter { $0.latitude != nil && $0.longitude != nil }
                    .prefix(500)
                    .map { $0 }
            } else {
                mapTransactions = try modelContext.fetch(descriptor)
            }
            mapAnnotations = mapTransactions.compactMap { transaction in
                guard let lat = transaction.latitude, let lon = transaction.longitude else { return nil }
                return TransactionMapAnnotation(
                    id: transaction.id,
                    transaction: transaction,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    title: transaction.locationName ?? transaction.category?.name ?? ""
                )
            }
        } catch {
            mapTransactions = []
            mapAnnotations = []
        }
    }

    private func fitMapToTransactions() {
        guard !mapAnnotations.isEmpty else { return }

        // Single pass to compute min/max
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        var hasValid = false

        for annotation in mapAnnotations {
            hasValid = true
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }

        guard hasValid else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapPosition = .region(region)
    }
}

// MARK: - Transaction Map Pin View

private struct TransactionMapPinView: View {
    let transaction: Transaction
    let isSelected: Bool

    private var pinColor: Color {
        if let category = transaction.category {
            return category.color
        }
        return transaction.type == .income ? .green : .red
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 8 : 4)

                if let category = transaction.category {
                    Image(systemName: category.icon)
                        .font(isSelected ? .body : .caption)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: transaction.type == .income ? "arrow.down" : "arrow.up")
                        .font(isSelected ? .body : .caption)
                        .foregroundStyle(.white)
                }
            }

            // Pin tail
            MapPinTailShape()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

private struct TransactionMapAnnotation: Identifiable {
    let id: UUID
    let transaction: Transaction
    let coordinate: CLLocationCoordinate2D
    let title: String
}

private struct MapPinTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Transaction Map Card View

private struct TransactionMapCardView: View {
    let transaction: Transaction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let category = transaction.category {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(category.color)
                        .frame(width: 44, height: 44)
                        .background(category.color.opacity(0.15))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.category?.name ?? String(localized: "categories.uncategorized"))
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(transaction.formattedSignedAmount)
                            .font(.subheadline.bold())
                            .foregroundStyle(transaction.type == .income ? .green : .primary)
                    }

                    HStack {
                        if let locationName = transaction.locationName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                Text(locationName)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction Filter Toggle
struct TransactionFilterToggle: View {
    @Bindable var viewModel: TransactionsViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                FilterToggleButton(
                    filter: filter,
                    isSelected: viewModel.selectedFilter == filter
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedFilter = filter
                        viewModel.applyFilters()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Toggle Button
struct FilterToggleButton: View {
    let filter: TransactionFilter
    let isSelected: Bool
    let action: () -> Void

    private var buttonColor: Color {
        switch filter {
        case .all: return .accentColor
        case .income: return .green
        case .expense: return .red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.toolbarIcon)
                    .font(.subheadline.weight(.medium))
                Text(filter.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? buttonColor.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? buttonColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Transaction List Content
struct TransactionListContent: View {
    @Bindable var viewModel: TransactionsViewModel
    @Binding var selectedTransaction: Transaction?

    var body: some View {
        List {
            ForEach(viewModel.sortedSectionKeys, id: \.self) { section in
                Section(header: Text(section)) {
                    if let transactions = viewModel.groupedTransactions[section] {
                        ForEach(transactions, id: \.id) { transaction in
                            TransactionListRowView(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTransaction = transaction
                                }
                        }
                        .onDelete { offsets in
                            viewModel.deleteTransactions(at: offsets, in: section)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Transaction List Row
struct TransactionListRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .frame(width: 40, height: 40)
                    .background(category.color.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.gray)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(transaction.category?.name ?? String(localized: "categories.uncategorized"))
                        .font(.body.weight(.medium))

                    if transaction.receiptImageData != nil {
                        Image(systemName: "doc.text.image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text(transaction.date.shortDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !transaction.note.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Amount with currency
            Text(transaction.formattedSignedAmount)
                .font(.body.bold())
                .foregroundStyle(transaction.type == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State
struct EmptyTransactionsView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "transactions.no_transactions"), systemImage: "tray")
        } description: {
            Text(String(localized: "dashboard.add_first_transaction"))
        }
    }
}

#Preview {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
