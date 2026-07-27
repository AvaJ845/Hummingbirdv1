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
