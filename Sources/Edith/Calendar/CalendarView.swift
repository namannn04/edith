import EventKit
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: CalendarStore
    @AppStorage("theme") private var themeName = "accent"
    @State private var showDatePicker = false

    private var theme: Color { themeColor(themeName) }

    var body: some View {
        Group {
            if store.authStatus != .fullAccess {
                permissionPrompt
                    .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                        store.refreshAuthStatus()
                    }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    dateNavigation
                    if store.events.isEmpty {
                        Text("No events on \(dateLabel)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 28)
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(store.events, id: \.eventIdentifier) { event in
                                    row(for: event)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { store.refreshAuthStatus() }
    }

    private var dateNavigation: some View {
        // MenuBarExtra's panel is a non-activating NSPanel - SwiftUI's
        // .popover fails to anchor/show inside it, so the picker expands
        // inline instead of in a popover.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                chevronButton("chevron.left", help: "Previous day") { shiftDate(by: -1) }

                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showDatePicker.toggle() }
                } label: {
                    Text(dateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .frame(minWidth: 92)
                }
                .buttonStyle(HoverButtonStyle())

                chevronButton("chevron.right", help: "Next day") { shiftDate(by: 1) }
                Spacer()
            }
            if showDatePicker {
                DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .onChange(of: store.selectedDate) {
                        withAnimation(.easeOut(duration: 0.15)) { showDatePicker = false }
                    }
            }
        }
    }

    private func chevronButton(
        _ systemName: String, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(HoverButtonStyle())
        .help(help)
    }

    private func shiftDate(by days: Int) {
        store.selectedDate = Calendar.current.date(
            byAdding: .day, value: days, to: store.selectedDate) ?? store.selectedDate
    }

    private var dateLabel: String {
        store.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("CALENDAR ACCESS")
            Text("Edith needs calendar access to show your schedule.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "circle")
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
        .card()
    }

    private func row(for event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeLabel(for: event))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 13))
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                if let url = event.url {
                    Button("Join") { NSWorkspace.shared.open(url) }
                        .buttonStyle(HoverButtonStyle())
                        .font(.system(size: 11))
                        .foregroundStyle(theme)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: event))
    }

    private func timeLabel(for event: EKEvent) -> String {
        event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened)
    }

    private func accessibilityLabel(for event: EKEvent) -> String {
        var parts = [timeLabel(for: event), event.title ?? "Untitled"]
        if let location = event.location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: ", ")
    }
}
