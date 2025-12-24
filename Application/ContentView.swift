import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard
    @AppStorage("appLockEnabled") private var appLockEnabled: Bool = false
    @AppStorage("lockOnBackground") private var lockOnBackground: Bool = true
    @State private var isLocked: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "house.fill")
                    }
                    .tag(Tab.dashboard)

                TransactionListView()
                    .tabItem {
                        Image(systemName: "list.bullet")
                    }
                    .tag(Tab.transactions)

                InsightsView()
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .tag(Tab.insights)

                MoreView()
                    .tabItem {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tag(Tab.more)
            }
            .environment(\.selectedTab, $selectedTab)

            if isLocked && appLockEnabled {
                LockScreenView(isLocked: $isLocked)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isLocked)
        .onAppear {
            if appLockEnabled {
                isLocked = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && lockOnBackground && appLockEnabled {
                isLocked = true
            }
        }
    }
}

// MARK: - Add Menu Popover

struct AddMenuPopover: View {
    @Binding var showManualAdd: Bool
    @Binding var showVoiceAdd: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showManualAdd = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "fab.manual"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(String(localized: "add.manual_description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 52)

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showVoiceAdd = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "fab.voice"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(String(localized: "add.voice_description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
    }
}

// MARK: - More View

struct MoreView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingExportSheet = false
    @State private var showingBackupSheet = false
    @State private var showingImportSheet = false
    @State private var showingImportResult = false
    @State private var showingFeedbackSheet = false
    @State private var importResultMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // Finance Management
                Section(String(localized: "more.finance")) {
                    NavigationLink(value: MoreDestination.budget) {
                        Label(String(localized: "tab.budget"), systemImage: "creditcard.fill")
                    }

                    NavigationLink(value: MoreDestination.savings) {
                        Label(String(localized: "tab.savings"), systemImage: "target")
                    }

                    NavigationLink(value: MoreDestination.recurring) {
                        Label(String(localized: "settings.recurring_transactions"), systemImage: "repeat")
                    }
                }

                // Organization
                Section(String(localized: "more.organize")) {
                    NavigationLink(value: MoreDestination.categories) {
                        Label(String(localized: "settings.category_management"), systemImage: "folder.fill")
                    }

                    NavigationLink(value: MoreDestination.tags) {
                        Label(String(localized: "tags.title"), systemImage: "tag.fill")
                    }
                }

                // Data
                Section(String(localized: "more.data")) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label(String(localized: "settings.export_data"), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingBackupSheet = true
                    } label: {
                        Label(String(localized: "settings.backup"), systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        showingImportSheet = true
                    } label: {
                        Label(String(localized: "settings.restore"), systemImage: "icloud.and.arrow.down")
                    }
                }

                // Support
                Section(String(localized: "more.support")) {
                    Button {
                        showingFeedbackSheet = true
                    } label: {
                        Label(String(localized: "feedback.title"), systemImage: "envelope.fill")
                    }
                }

                // Settings
                Section {
                    NavigationLink(value: MoreDestination.settings) {
                        Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle(String(localized: "tab.more"))
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .budget:
                    BudgetView()
                case .savings:
                    SavingsGoalsView()
                case .recurring:
                    RecurringTransactionsView()
                case .categories:
                    CategoriesView()
                case .tags:
                    TagsView()
                case .settings:
                    SettingsView()
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
            .sheet(isPresented: $showingBackupSheet) {
                BackupView()
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackView()
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(String(localized: "settings.restore_result"), isPresented: $showingImportResult) {
                Button(String(localized: "common.ok")) {}
            } message: {
                Text(importResultMessage)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                guard url.startAccessingSecurityScopedResource() else {
                    importResultMessage = String(localized: "settings.restore_error")
                    showingImportResult = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                let importResult = try BackupService.shared.importBackup(from: data, modelContext: modelContext)
                importResultMessage = String(localized: "settings.restore_success \(importResult.totalImported)")
                showingImportResult = true
            } catch {
                importResultMessage = String(localized: "settings.restore_error")
                showingImportResult = true
            }

        case .failure:
            importResultMessage = String(localized: "settings.restore_error")
            showingImportResult = true
        }
    }
}

enum Tab: Hashable {
    case dashboard
    case transactions
    case insights
    case more
}

enum MoreDestination: Hashable {
    case budget
    case savings
    case recurring
    case categories
    case tags
    case settings
}

// MARK: - Tab Selection Environment Key

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Tab> = .constant(.dashboard)
}

extension EnvironmentValues {
    var selectedTab: Binding<Tab> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self, Wallet.self, SavingsGoal.self, Tag.self], inMemory: true)
}
