import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var showingResetAlert = false
    @State private var showingLanguageChangeAlert = false
    @State private var selectedCurrency: Currency = CurrencySettings.shared.defaultCurrency

    // Biometric settings cached locally
    @AppStorage("appLockEnabled") private var appLockEnabled: Bool = false
    @AppStorage("lockOnBackground") private var lockOnBackground: Bool = true

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 21
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @AppStorage("budgetAlertEnabled") private var budgetAlertEnabled = true
    @AppStorage("weeklyReportEnabled") private var weeklyReportEnabled = false
    @AppStorage("selectedLanguage") private var selectedLanguage: AppLanguage = .system

    // Cache biometric info to avoid repeated LAContext calls
    private let biometricType: BiometricType = BiometricService.shared.biometricType
    private let isBiometricAvailable: Bool = BiometricService.shared.isBiometricAvailable

    var body: some View {
        List {
            // General Section (Language & Currency)
            Section(String(localized: "settings.section.general")) {
                // Language Setting
                Picker(selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                } label: {
                    Label(String(localized: "settings.language"), systemImage: "globe")
                }
                .onChange(of: selectedLanguage) { _, newValue in
                    newValue.apply()
                    showingLanguageChangeAlert = true
                }

                // Default Currency Setting
                Picker(selection: $selectedCurrency) {
                    ForEach(Currency.allCases) { currency in
                        Text("\(currency.symbol) \(currency.name)").tag(currency)
                    }
                } label: {
                    Label(String(localized: "currency.default"), systemImage: "dollarsign.circle")
                }
                .onChange(of: selectedCurrency) { _, newValue in
                    CurrencySettings.shared.defaultCurrency = newValue
                }
            }

            // Appearance Section
            Section(String(localized: "settings.section.appearance")) {
                Picker(String(localized: "settings.theme"), selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            // Notifications Section
            Section(String(localized: "settings.section.notifications")) {
                Toggle(String(localized: "settings.budget_alert"), isOn: $budgetAlertEnabled)
                    .onChange(of: budgetAlertEnabled) { _, newValue in
                        guard newValue else { return }
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            if !granted {
                                budgetAlertEnabled = false
                            }
                        }
                    }

                Toggle(String(localized: "settings.daily_reminder"), isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, newValue in
                        Task {
                            if newValue {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleDailyReminder(
                                        at: dailyReminderHour,
                                        minute: dailyReminderMinute
                                    )
                                } else {
                                    dailyReminderEnabled = false
                                }
                            } else {
                                NotificationService.shared.cancelDailyReminder()
                            }
                        }
                    }

                if dailyReminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminder_time"),
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    bySettingHour: dailyReminderHour,
                                    minute: dailyReminderMinute,
                                    second: 0,
                                    of: Date()
                                ) ?? Date()
                            },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                dailyReminderHour = components.hour ?? 21
                                dailyReminderMinute = components.minute ?? 0
                                NotificationService.shared.scheduleDailyReminder(
                                    at: dailyReminderHour,
                                    minute: dailyReminderMinute
                                )
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle(String(localized: "settings.weekly_report"), isOn: $weeklyReportEnabled)
                    .onChange(of: weeklyReportEnabled) { _, newValue in
                        Task {
                            if newValue {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleWeeklyReport()
                                } else {
                                    weeklyReportEnabled = false
                                }
                            } else {
                                NotificationService.shared.cancelWeeklyReport()
                            }
                        }
                    }
            }

            // Security Section
            Section(String(localized: "settings.section.security")) {
                if isBiometricAvailable {
                    Toggle(isOn: $appLockEnabled) {
                        Label(
                            String(localized: "settings.app_lock \(biometricType.displayName)"),
                            systemImage: biometricType.icon
                        )
                    }

                    if appLockEnabled {
                        Toggle(isOn: $lockOnBackground) {
                            Label(String(localized: "settings.lock_on_background"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } else {
                    HStack {
                        Label(String(localized: "settings.biometric_unavailable"), systemImage: "lock.slash")
                        Spacer()
                        Text(String(localized: "settings.not_available"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label(String(localized: "settings.delete_all_data"), systemImage: "trash")
                }
            }

            // About Section
            Section(String(localized: "settings.section.about")) {
                Button {
                    requestReview()
                } label: {
                    Label(String(localized: "settings.rate_app"), systemImage: "star.fill")
                }

                HStack {
                    Text(String(localized: "settings.version"))
                    Spacer()
                    Text(Bundle.main.appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "settings.title"))
        .alert(String(localized: "settings.delete_data_title"), isPresented: $showingResetAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                resetAllData()
            }
        } message: {
            Text(String(localized: "settings.delete_data_message"))
        }
        .alert(String(localized: "settings.language.change_title"), isPresented: $showingLanguageChangeAlert) {
            Button(String(localized: "common.ok")) {}
        } message: {
            Text(String(localized: "settings.language.change_message"))
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.save()
        } catch {
            print("Failed to delete data: \(error)")
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "settings.theme.system")
        case .light:
            return String(localized: "settings.theme.light")
        case .dark:
            return String(localized: "settings.theme.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - App Language
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "settings.language.system")
        case .english:
            return "English"
        case .korean:
            return "한국어"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .korean:
            return "ko"
        }
    }

    func apply() {
        if let identifier = localeIdentifier {
            UserDefaults.standard.set([identifier], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        // Note: Language change will take effect on next app launch
        // Show alert to restart app for full effect
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Export View
struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text(String(localized: "export.title"))
                    .font(.title2.bold())

                Text(String(localized: "export.description"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Spacer()

                if isExporting {
                    ProgressView()
                } else {
                    ShareLink(item: generateCSV()) {
                        Label(String(localized: "export.csv"), systemImage: "doc.text")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateCSV() -> URL {
        let repository = TransactionRepository(modelContext: modelContext)
        let transactions = (try? repository.fetchAll()) ?? []

        var csvString = "Date,Type,Category,Amount,Note\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.date)
            let type = transaction.type == .income ? "Income" : "Expense"
            let category = transaction.category?.name ?? "Uncategorized"
            let amount = "\(transaction.amount)"
            let note = transaction.note.replacingOccurrences(of: ",", with: ";")

            csvString += "\(date),\(type),\(category),\(amount),\(note)\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("LetsTrack_Export.csv")

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV: \(error)")
        }

        return tempURL
    }
}

// MARK: - Backup View

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var backupData: Data?
    @State private var backupURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isExporting = false
    @State private var lastBackupDate: Date? = BackupService.shared.lastBackupDate

    private let backupService = BackupService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text(String(localized: "backup.title"))
                    .font(.title2.bold())

                Text(String(localized: "backup.description"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let lastBackup = lastBackupDate {
                    Text(String(localized: "backup.last_backup \(lastBackup.formatted(date: .abbreviated, time: .shortened))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isExporting {
                    ProgressView()
                } else if let url = backupURL {
                    ShareLink(item: url) {
                        Label(String(localized: "backup.share"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button {
                        createBackup()
                    } label: {
                        Label(String(localized: "backup.create"), systemImage: "doc.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "error.unknown"), isPresented: $showError) {
                Button(String(localized: "common.ok")) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createBackup() {
        isExporting = true
        defer { isExporting = false }

        do {
            let data = try backupService.exportBackup(modelContext: modelContext)
            let url = backupService.getBackupFileURL()
            try data.write(to: url)
            backupURL = url
            lastBackupDate = backupService.lastBackupDate
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Bundle Extension
extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
