import Testing
import EventKit
@testable import Edith

@Suite struct CalendarDayEventsTests {
    private static let scratchStore = EKEventStore()

    private static func event(title: String, start: Date, allDay: Bool = false) -> EKEvent {
        let event = EKEvent(eventStore: scratchStore)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(1800)
        event.isAllDay = allDay
        return event
    }

    @Test func sortsAllDayFirstThenByStartTime() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Self.event(title: "Later", start: base.addingTimeInterval(3600))
        let earlier = Self.event(title: "Earlier", start: base)
        let holiday = Self.event(title: "Holiday", start: base.addingTimeInterval(-3600), allDay: true)

        let sorted = CalendarDayEvents.sorted([later, earlier, holiday])

        #expect(sorted.map(\.title) == ["Holiday", "Earlier", "Later"])
    }

    @Test func stableWhenAlreadySorted() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = Self.event(title: "First", start: base)
        let second = Self.event(title: "Second", start: base.addingTimeInterval(1800))

        let sorted = CalendarDayEvents.sorted([first, second])

        #expect(sorted.map(\.title) == ["First", "Second"])
    }
}
