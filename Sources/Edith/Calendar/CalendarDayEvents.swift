import EventKit

/// Sort order for a day's events: all-day events lead (they have no
/// meaningful start time to compare), then ascending by start time.
enum CalendarDayEvents {
    static func sorted(_ events: [EKEvent]) -> [EKEvent] {
        events.sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }
}
