import EventKit
import Foundation

/// Sort order for a day's events: all-day events lead (they have no
/// meaningful start time to compare), then ascending by start time.
enum CalendarDayEvents {
    static func sorted(_ events: [EKEvent]) -> [EKEvent] {
        events.sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }

    /// Events bucketed by calendar day, days ascending. Within a day the sort
    /// order is preserved (all-day first, then by start time). A multi-day
    /// event lands only on its start day - fine for a menu-bar agenda.
    static func groupedByDay(
        _ events: [EKEvent], calendar: Calendar = .current
    ) -> [(day: Date, events: [EKEvent])] {
        let byDay = Dictionary(grouping: sorted(events)) {
            calendar.startOfDay(for: $0.startDate)
        }
        return byDay.keys.sorted().map { (day: $0, events: byDay[$0]!) }
    }
}

/// The video-call link for an event, the way Raycast surfaces one: EventKit has
/// no conference-URL field for Google/Exchange events, so the link is dug out of
/// url / location / notes by matching a known conferencing host.
enum MeetingLink {
    private static let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "meet.jit.si", "chime.aws",
        "gotomeeting.com", "bluejeans.com", "8x8.vc",
    ]

    static func url(for event: EKEvent) -> URL? {
        if let url = event.url, isMeeting(url) { return url }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        return find(in: text)
    }

    /// First link to a known conferencing host in free text. NSDataDetector
    /// handles the messy URL extraction (trailing punctuation, brackets, etc.).
    static func find(in text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(
                  types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            if let url = match.url, isMeeting(url) { return url }
        }
        return nil
    }

    // Exact host or a subdomain of it - not a substring match, so a lookalike
    // like "zoom.us.phishy.example" doesn't pass.
    private static func isMeeting(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
