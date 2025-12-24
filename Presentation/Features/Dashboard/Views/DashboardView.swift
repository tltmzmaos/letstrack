import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectedTab) private var selectedTab
    @State private var viewModel: DashboardViewModel?
    @State private var showingAddTransaction = false
    @State private var showingVoiceTransaction = false
    @State private var showAddPopover = false
    @State private var showingError = false
    @State private var hasAppeared = false

    // Preloaded categories for faster sheet opening
    @State private var preloadedCategories: [Category] = []
    @State private var preloadedTags: [Tag] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let viewModel = viewModel {
                        if viewModel.isLoading {
                            // Loading state
                            DashboardLoadingView()
                        } else if viewModel.isEmpty {
                            // Empty state
                            DashboardEmptyView {
                                showingAddTransaction = true
                            }
                        } else {
                            // Balance Card
                            BalanceCardView(
                                totalBalance: viewModel.totalBalance,
                                monthlyIncome: viewModel.monthlyIncome,
                                monthlyExpense: viewModel.monthlyExpense
                            )

                            // Monthly Summary
                            MonthlySummaryView(
                                month: viewModel.currentMonthString,
                                income: viewModel.monthlyIncome,
                                expense: viewModel.monthlyExpense,
                                balance: viewModel.monthlyBalance
                            )

                            // Category Breakdown
                            if !viewModel.expenseByCategory.isEmpty {
                                CategoryBreakdownView(
                                    categories: viewModel.expenseByCategory,
                                    total: viewModel.monthlyExpense
                                )
                            }

                            // Recent Transactions
                            if !viewModel.recentTransactions.isEmpty {
                                RecentTransactionsView(
                                    transactions: viewModel.recentTransactions,
                                    onViewAll: {
                                        selectedTab.wrappedValue = .transactions
                                    }
                                )
                            }
                        }
                    } else {
                        // Initial loading before viewModel is created
                        DashboardLoadingView()
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "dashboard.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
            .fullScreenCover(isPresented: $showingAddTransaction) {
                AddTransactionView(
                    preloadedCategories: preloadedCategories,
                    preloadedTags: preloadedTags
                )
                    .onDisappear {
                        viewModel?.loadData()
                    }
            }
            .fullScreenCover(isPresented: $showingVoiceTransaction) {
                VoiceTransactionView(preloadedCategories: preloadedCategories)
                    .onDisappear {
                        viewModel?.loadData()
                    }
            }
            .alert(String(localized: "error.unknown"), isPresented: $showingError) {
                Button(String(localized: "error.retry")) {
                    viewModel?.loadData()
                }
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel?.errorMessage ?? "")
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

                let vm = DashboardViewModel(modelContext: modelContext)
                viewModel = vm
                vm.loadData()
            }
            .onChange(of: viewModel?.errorMessage) { _, newValue in
                showingError = newValue != nil
            }
        }
    }
}

// MARK: - Empty State View

private struct DashboardEmptyView: View {
    let onAddTransaction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "wallet.pass")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(String(localized: "dashboard.no_transactions"))
                    .font(.title3.bold())

                Text(String(localized: "dashboard.add_first_transaction"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                onAddTransaction()
            } label: {
                Label(String(localized: "transactions.add"), systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Loading State View

private struct DashboardLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Balance card placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(height: 160)

            // Summary placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(height: 120)

            // Category breakdown placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(height: 200)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
