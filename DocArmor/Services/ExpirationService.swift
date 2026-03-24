import Foundation
import UserNotifications

enum ExpirationService {

    // MARK: - Request Permission

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule Reminder

    static func scheduleReminder(for document: Document) {
        guard
            let expirationDate = document.expirationDate,
            let reminderDays = document.expirationReminderDays,
            reminderDays > 0
        else { return }

        guard let triggerDate = Calendar.current.date(
            byAdding: .day,
            value: -reminderDays,
            to: expirationDate
        ) else { return }

        // Don't schedule if trigger date is in the past
        guard triggerDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Document Expiring Soon"
        // Use the actual expiration date in the body rather than the reminder lead
        // time. The device may deliver the notification late (e.g. after DND/reboot),
        // so a concrete date is more accurate than "in X days".
        let formatted = expirationDate.formatted(date: .abbreviated, time: .omitted)
        content.body = "\(document.name) expires on \(formatted). Tap to view."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationID(for: document),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel Reminder

    static func cancelReminder(for document: Document) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID(for: document)])
    }

    // MARK: - Update Reminder

    static func updateReminder(for document: Document) {
        cancelReminder(for: document)
        scheduleReminder(for: document)
    }

    // MARK: - Cancel All

    static func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private static func notificationID(for document: Document) -> String {
        "docarmor.expiry.\(document.id.uuidString)"
    }
}
