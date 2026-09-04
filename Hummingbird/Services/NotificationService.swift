import Foundation
import UserNotifications

/// Thin wrapper over local notifications for movement alerts.
enum NotificationService {
    @discardableResult
    static func requestAuthorization() async -> Bool {
        #if DEBUG
        // Never raise the system permission alert during a screenshot run — it
        // pops asynchronously over whatever screen is being captured.
        if TestSupport.isUITest { return false }
        #endif
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
        await add(request, label: "morning digest")
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
        await add(request, label: "call resolution")
    }

    static func cancelCallResolution(callID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [callIdentifier(callID)])
    }

    /// Movement alerts are the one notification path that can fan out in a
    /// single moment (many watchlist assets moving at once), so they're the
    /// only type gated by `NotificationBudget` — see its doc comment for why
    /// the other, already-self-limited paths aren't.
    static func deliver(_ alert: MovementAlert, id: String) async {
        guard NotificationBudget.canSendDiscretionary() else {
            #if DEBUG
            print("⚠️ NotificationService: daily movement-alert budget reached — skipping \(id)")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "move-\(id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil // deliver now
        )
        await add(request, label: "movement alert")
        NotificationBudget.recordSent()
    }

    private static let weeklyRecapIdentifier = "weekly-recap"

    /// Schedule (or replace) a repeating weekly recap, Sunday morning.
    static func scheduleWeeklyRecap(_ digest: Digest, weekday: Int = 1, hour: Int = 9, minute: Int = 0) async {
        let content = UNMutableNotificationContent()
        content.title = digest.title
        content.body = digest.body
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyRecapIdentifier])
        let request = UNNotificationRequest(identifier: weeklyRecapIdentifier, content: content, trigger: trigger)
        await add(request, label: "weekly recap")
    }

    static func cancelWeeklyRecap() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyRecapIdentifier])
    }

    /// Schedules a request and surfaces failures in DEBUG — these are silent
    /// come-back mechanisms (digest, call nudge, movement alert); a failed
    /// schedule should be observable to a developer, not invisible.
    private static func add(_ request: UNNotificationRequest, label: String) async {
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("⚠️ NotificationService: failed to schedule \(label) — \(error.localizedDescription)")
            #endif
        }
    }
}
