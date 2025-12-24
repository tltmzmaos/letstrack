import Foundation
import UserNotifications
import os.log

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LetsTrack", category: "Notifications")

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Budget Alerts

    func scheduleBudgetWarningNotification(
        budgetName: String,
        spent: Decimal,
        budget: Decimal,
        percentage: Double
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.budget_warning.title")
        content.body = String(localized: "notification.budget_warning.body \(budgetName)")
        content.sound = .default
        content.categoryIdentifier = "BUDGET_WARNING"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "budget_warning_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule budget warning notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleBudgetExceededNotification(
        budgetName: String,
        overspent: Decimal
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.budget_exceeded.title")
        content.body = String(localized: "notification.budget_exceeded.body \(budgetName)")
        content.sound = .default
        content.categoryIdentifier = "BUDGET_EXCEEDED"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "budget_exceeded_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule budget exceeded notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(at hour: Int, minute: Int) {
        // Remove existing daily reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.daily_reminder.title")
        content.body = String(localized: "notification.daily_reminder.body")
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule daily reminder: \(error.localizedDescription)")
            }
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }

    // MARK: - Recurring Transaction Reminder

    func scheduleRecurringTransactionReminder(
        id: String,
        name: String,
        amount: Decimal,
        dueDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.recurring_reminder.title")
        content.body = String(localized: "notification.recurring_reminder.body \(name) \(amount.formatted())")
        content.sound = .default
        content.categoryIdentifier = "RECURRING_REMINDER"

        // Schedule for one day before
        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -1, to: dueDate) else { return }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "recurring_\(id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule recurring transaction reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Weekly Report

    /// Schedule weekly spending report for Monday morning
    func scheduleWeeklyReport(at hour: Int = 9, minute: Int = 0) {
        // Remove existing weekly report
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly_report"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.weekly_report.title")
        content.body = String(localized: "notification.weekly_report.body")
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REPORT"

        // Schedule for Monday (weekday = 2 in Gregorian calendar)
        var dateComponents = DateComponents()
        dateComponents.weekday = 2  // Monday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_report",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule weekly report: \(error.localizedDescription)")
            }
        }
    }

    /// Schedule weekly report with actual spending data
    func scheduleWeeklyReportWithData(
        totalSpent: Decimal,
        topCategory: String?,
        comparedToLastWeek: Double?  // percentage change
    ) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly_report"])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.weekly_report.title")

        // Build body with actual data
        let formattedAmount = CurrencySettings.shared.defaultCurrency.format(totalSpent)
        var bodyParts: [String] = [String(localized: "notification.weekly_report.spent \(formattedAmount)")]

        if let topCategory = topCategory {
            bodyParts.append(String(localized: "notification.weekly_report.top_category \(topCategory)"))
        }

        if let change = comparedToLastWeek {
            if change > 0 {
                bodyParts.append(String(localized: "notification.weekly_report.increased \(Int(abs(change)))"))
            } else if change < 0 {
                bodyParts.append(String(localized: "notification.weekly_report.decreased \(Int(abs(change)))"))
            }
        }

        content.body = bodyParts.joined(separator: " ")
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REPORT"

        // Schedule for Monday at 9 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_report",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to schedule weekly report with data: \(error.localizedDescription)")
            }
        }
    }

    func cancelWeeklyReport() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly_report"])
    }

    // MARK: - Clear All

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
