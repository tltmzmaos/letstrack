import SwiftUI
import SwiftData

@main
struct LetsTrackApp: App {
    @State private var showDatabaseError = false
    @State private var databaseErrorMessage = ""
    @State private var isInitialized = false

    var sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            RecurringTransaction.self,
            SavingsGoal.self,
            Wallet.self,
            Tag.self,
            TransactionTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If normal initialization fails, try in-memory as fallback
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.sharedModelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                self._databaseErrorMessage = State(initialValue: String(localized: "error.database_fallback"))
                self._showDatabaseError = State(initialValue: true)
            } catch {
                // This should never happen, but if it does, crash with a meaningful message
                fatalError("Critical: Failed to initialize database: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                } else {
                    LaunchScreenView()
                }
            }
            .task {
                await initializeApp()
            }
            .alert(String(localized: "error.database_title"), isPresented: $showDatabaseError) {
                Button(String(localized: "common.ok")) {}
            } message: {
                Text(databaseErrorMessage)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func initializeApp() async {
        let context = sharedModelContainer.mainContext

        // Check if already initialized using UserDefaults cache
        let hasInitializedCategories = UserDefaults.standard.bool(forKey: "hasInitializedCategories")

        if !hasInitializedCategories {
            // Setup default categories only on first launch
            let repository = CategoryRepository(modelContext: context)
            try? repository.setupDefaultCategoriesIfNeeded()
            UserDefaults.standard.set(true, forKey: "hasInitializedCategories")
        }

        AppDataPreloader.shared.preload(using: context)

        // Skip prewarm - go directly to main content
        isInitialized = true
    }
}

// MARK: - Launch Screen View

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
}
