import AppKit
import EdithKit
import EventKit
import SwiftUI

struct CalendarPage: View {
    @StateObject private var store = CalendarStore()
    @StateObject private var presenterState = PresenterState.shared
    @AppStorage("theme", store: SharedDefaults.store) private var themeName = "accent"
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }
    private var theme: Color { themeColor(themeName) }

    private var groupedDays: [(day: Date, events: [EKEvent])] {
        CalendarDayEvents.groupedByDay(store.events)
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
            if store.authStatus != .fullAccess {
                permissionPrompt
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onReceive(
                        Timer.publish(every: 2, on: .main, in: .common).autoconnect()
                    ) { _ in
                        store.refreshAuthStatus()
                    }
            } else {
                agenda
            }
        }
        .background(DashSkin.paper(dark).ignoresSafeArea(edges: .vertical))
        .navigationTitle("Calendar")
        .onAppear { store.refreshAuthStatus() }
    }

    private var pageHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Calendar")
                .font(DashSkin.serif(34))
                .foregroundStyle(DashSkin.ink(dark))
            Spacer()
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            } label: {
                Label("Open Calendar", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(HoverButtonStyle())
        }
    }

    private var agenda: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if groupedDays.isEmpty {
                    Text("Nothing coming up")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(groupedDays, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            dayHeader(group.day)
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(group.events, id: \.eventIdentifier) { event in
                                    row(for: event)
                                    if event != group.events.last {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .background(
                                DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(DashSkin.line(dark), lineWidth: 1)
                            )
                        }
                    }
                }
                Color.clear.frame(height: 1).onAppear { store.loadMore() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        let date = day.formatted(.dateTime.month(.abbreviated).day())
        return Text("\(dayName(day)) · \(date)".uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }

    private func row(for event: EKEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(timeRange(for: event))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 13.5))
                    .lineLimit(1)
                    .presenterBlur(presenterState.active)
                if let location = event.location, !location.isEmpty,
                    !location.hasPrefix("http")
                {
                    Text(location)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let url = MeetingLink.url(for: event) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(providerColor(url))
                }
                .buttonStyle(HoverButtonStyle())
                .help(url.absoluteString)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: event))
    }

    private func dayName(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private func timeRange(for event: EKEvent) -> String {
        guard !event.isAllDay else { return "All day" }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func providerColor(_ url: URL) -> Color {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom.us") { return Color(red: 0.18, green: 0.55, blue: 1.0) }
        if host.contains("meet.google.com") { return Color(red: 0.0, green: 0.67, blue: 0.28) }
        if host.contains("teams.") { return Color(red: 0.38, green: 0.39, blue: 0.65) }
        if host.contains("webex.com") { return Color(red: 0.0, green: 0.74, blue: 0.92) }
        return theme
    }

    private func accessibilityLabel(for event: EKEvent) -> String {
        var parts = [timeRange(for: event), event.title ?? "Untitled"]
        if let location = event.location, !location.isEmpty, !location.hasPrefix("http") {
            parts.append(location)
        }
        if MeetingLink.url(for: event) != nil { parts.append("has meeting link") }
        return parts.joined(separator: ", ")
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CALENDAR ACCESS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text("Edith needs calendar access to show your schedule here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Calendars")
                    .font(.system(size: 12))
                Spacer()
                Button("Grant…") { store.requestAccess() }
                    .buttonStyle(HoverButtonStyle())
                    .font(.system(size: 11))
                    .foregroundStyle(theme)
                    .help("Opens System Settings on the right pane")
            }
        }
        .padding(16)
        .background(DashSkin.paper2(dark), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(DashSkin.line(dark), lineWidth: 1))
    }
}
