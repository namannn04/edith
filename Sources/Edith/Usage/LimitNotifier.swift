import Foundation
import UserNotifications

/// Delivery layer around LimitNotifierLogic: persists edge-trigger state in
/// UserDefaults, posts UNNotifications, and (re)schedules reset reminders on
/// every poll so moving reset times never stack duplicates.
@MainActor
final class LimitNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let defaults = UserDefaults.standard
    private var center: UNUserNotificationCenter { .current() }

    override init() {
        super.init()
        // Claim the delegate at startup, not just on the settings toggle -
        // foreground banners must survive an app relaunch.
        center.delegate = self
    }

    func evaluate(session: LimitWindow?, week: LimitWindow?) {
        let settings = NotifySettings.fromDefaults()
        guard settings.master else {
            // Master off: drop pending reminders so re-enabling can't fire stale ones.
            center.removePendingNotificationRequests(withIdentifiers: ["reminder_session", "reminder_weekly"])
            return
        }
        var state = loadState()
        let before = state
        let alerts = LimitNotifierLogic.decide(
            session: session, week: week, settings: settings, state: &state, now: Date())
        if state != before { save(state) }
        for alert in alerts { send(alert) }
        scheduleReminders(session: session, week: week, settings: settings)
    }

    func notifyTokenExpired() {
        let settings = NotifySettings.fromDefaults()
        guard settings.master, settings.tokenExpired else { return }
        // ponytail: 1-per-hour dedupe via a plain timestamp, like TokenEater
        if let last = defaults.object(forKey: "notifTokenExpiredAt") as? Date,
           Date().timeIntervalSince(last) < 3600 { return }
        defaults.set(Date(), forKey: "notifTokenExpiredAt")
        send(LimitAlert(id: "token_expired",
                        title: "Claude token expired", body: "Run claude to log in again"))
    }

    func sendTest() {
        send(LimitAlert(id: "test_\(UUID().uuidString)",
                        title: "Hey, you're set", body: "If you see this, notifications work"))
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Banners + sound even while Edith is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - State persistence

    private func loadState() -> LimitNotifierState {
        var s = LimitNotifierState()
        s.sessionLevel = UsageLevel(rawValue: defaults.integer(forKey: "notifSessionLevel")) ?? .green
        s.weeklyLevel = UsageLevel(rawValue: defaults.integer(forKey: "notifWeeklyLevel")) ?? .green
        s.sessionPacing = PacingZone(rawValue: defaults.string(forKey: "notifSessionPacing") ?? "") ?? .onTrack
        s.weeklyPacing = PacingZone(rawValue: defaults.string(forKey: "notifWeeklyPacing") ?? "") ?? .onTrack
        return s
    }

    private func save(_ s: LimitNotifierState) {
        defaults.set(s.sessionLevel.rawValue, forKey: "notifSessionLevel")
        defaults.set(s.weeklyLevel.rawValue, forKey: "notifWeeklyLevel")
        defaults.set(s.sessionPacing.rawValue, forKey: "notifSessionPacing")
        defaults.set(s.weeklyPacing.rawValue, forKey: "notifWeeklyPacing")
    }

    // MARK: - Sending

    private func send(_ alert: LimitAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: nil))
    }

    private func scheduleReminders(session: LimitWindow?, week: LimitWindow?, settings: NotifySettings) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder_session", "reminder_weekly"])
        if settings.reminderSession, let reset = session?.resetsAt {
            schedule(id: "reminder_session",
                     title: "Session resets in \(offsetLabel(settings.reminderSessionOffsetMin))",
                     body: "Save your spot or send it",
                     at: reset.addingTimeInterval(-Double(settings.reminderSessionOffsetMin) * 60))
        }
        if settings.reminderWeekly, let reset = week?.resetsAt {
            schedule(id: "reminder_weekly",
                     title: "Weekly resets in \(offsetLabel(settings.reminderWeeklyOffsetMin))",
                     body: "Last lap on the cycle",
                     at: reset.addingTimeInterval(-Double(settings.reminderWeeklyOffsetMin) * 60))
        }
    }

    private func schedule(id: String, title: String, body: String, at fire: Date) {
        guard fire.timeIntervalSinceNow > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Matches the Settings picker labels: round hours as "2 h", else "30 min".
    private func offsetLabel(_ minutes: Int) -> String {
        minutes >= 60 && minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes) min"
    }
}
