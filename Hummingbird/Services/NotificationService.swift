import Foundation
import UserNotifications

/// Thin wrapper over local notifications for movement alerts.
enum NotificationService {
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private static let digestIdentifier = "morning-digest"

    /// Schedule (or replace) a repeating daily "morning read" at the given
    /// hour/minute, with content composed from the latest local snapshots.
    static func scheduleMorningDigest(_ digest: Digest, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = digest.title
        content.body = digest.body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [digestIdentifier])
        let request = UNNotificationRequest(identifier: digestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelMorningDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [digestIdentifier])
    }

    private static func callIdentifier(_ id: UUID) -> String { "call-\(id.uuidString)" }

    /// Nudge the user to come back when a call's horizon is up. One-shot.
    static func scheduleCallResolution(callID: UUID, symbol: String, at date: Date) async {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }   // already due — nothing to schedule

        let content = UNMutableNotificationContent()
        content.title = "Your \(symbol.uppercased()) call is ready to check"
        content.body = "See how it turned out — a record of the past, never advice."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: callIdentifier(callID), content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelCallResolution(callID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [callIdentifier(callID)])
    }

    static func deliver(_ alert: MovementAlert, id: String) async {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "move-\(id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil // deliver now
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
