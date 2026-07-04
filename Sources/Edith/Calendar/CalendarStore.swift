import AppKit
import EventKit

/// Calendar tab: an upcoming-events agenda via EventKit, from the start of
/// today forward over a rolling window that grows as the user scrolls. Read-
/// only, all calendars, no polling - EventKit pushes `.EKEventStoreChanged`
/// on any edit and we also refresh on wake (matches UsageStore's wake-
/// refresh), both re-fetching the current window.
@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var authStatus: EKAuthorizationStatus

    // How many days ahead the agenda currently covers. Grows on scroll (see
    // loadMore) up to a ceiling so an empty calendar can't loop forever.
    private var daysLoaded = 14
    private static let maxDays = 120

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    init() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        if authStatus == .fullAccess { refresh() }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Tab disabled or app quitting: drop the live subscriptions.
    func shutdown() {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        changeObserver = nil
        wakeObserver = nil
    }

    /// The OS calendar prompt fires only once per app identity - same
    /// caveat as SystemStore's Accessibility/Input Monitoring requests - so
    /// Grant always also opens the right System Settings pane.
    func requestAccess() {
        Task { @MainActor in
            _ = try? await store.requestFullAccessToEvents()
            refreshAuthStatus()
        }
        openCalendarSettings()
    }

    func refreshAuthStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status != authStatus else { return }
        authStatus = status
        if status == .fullAccess { refresh() }
    }

    func refresh() {
        guard authStatus == .fullAccess else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: daysLoaded, to: start)!
        let predicate = store.predicateForEvents(
            withStart: start, end: end, calendars: store.calendars(for: .event))
        events = CalendarDayEvents.sorted(store.events(matching: predicate))
    }

    /// Scrolled to the bottom: widen the window and re-fetch. No-op once we've
    /// hit the ceiling, so a sparse calendar stops instead of loading forever.
    func loadMore() {
        guard daysLoaded < Self.maxDays else { return }
        daysLoaded = min(daysLoaded + 14, Self.maxDays)
        refresh()
    }

    func openCalendarSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }
}
