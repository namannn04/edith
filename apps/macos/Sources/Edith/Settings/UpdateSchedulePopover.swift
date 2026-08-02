import EdithKit
import SwiftUI

struct UpdateSchedulePopover: View {
    @ObservedObject var updater: UpdaterModel
    @State private var editingCustom = false
    @State private var customSeconds = ""
    @State private var clampNotice: String?
    @FocusState private var customFocused: Bool

    private var showsCustomField: Bool {
        editingCustom || !UpdateCheckInterval.isPreset(updater.checkInterval)
    }

    private var interval: Binding<TimeInterval> {
        Binding(
            get: {
                showsCustomField
                    ? UpdateCheckInterval.customTag : updater.checkInterval
            },
            set: { value in
                guard value != UpdateCheckInterval.customTag else {
                    customSeconds = String(Int(updater.checkInterval))
                    clampNotice = nil
                    editingCustom = true
                    customFocused = true
                    return
                }
                editingCustom = false
                clampNotice = nil
                updater.checkInterval = value
            })
    }

    private func commitCustomSeconds() {
        let typed = customSeconds.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty, let entered = TimeInterval(typed) else {
            customSeconds = String(Int(updater.checkInterval))
            clampNotice = nil
            return
        }
        let clamped = UpdateCheckInterval.clamp(entered)
        updater.checkInterval = clamped
        customSeconds = String(Int(clamped))
        clampNotice = UpdateCheckInterval.clampNotice(entered: entered, applied: clamped)
    }

    private var automaticChecks: Binding<Bool> {
        Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.automaticallyChecksForUpdates = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(14)) {
            header
            Divider()
            schedule
            Divider()
            history
        }
        .padding(UIScale.pt(16))
        .frame(width: UIScale.pt(360))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(2)) {
            Text("Update checks")
                .font(.system(size: UIScale.pt(13), weight: .semibold))
            Text(countSummary)
                .font(.system(size: UIScale.pt(11)))
                .foregroundStyle(.secondary)
        }
    }

    private var countSummary: String {
        let automatic = updater.automaticCheckCount
        let total = updater.checkHistory.count
        if total == 0 { return "No checks recorded yet" }
        let auto = automatic == 1 ? "1 automatic check" : "\(automatic) automatic checks"
        return "\(auto) of \(total) recorded"
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(10)) {
            Toggle("Check automatically", isOn: automaticChecks)
                .pointerCursor()
            Picker("Frequency", selection: interval) {
                ForEach(UpdateCheckInterval.choices) { choice in
                    Text(choice.label).tag(choice.seconds)
                }
                Divider()
                Text("Custom…").tag(UpdateCheckInterval.customTag)
            }
            .pickerStyle(.menu)
            .pointerCursor()
            .disabled(!updater.automaticallyChecksForUpdates)
            if showsCustomField { customField }
            HStack(spacing: UIScale.pt(6)) {
                Button("Run a background check now", action: updater.checkForUpdatesInBackground)
                    .controlSize(.small)
                    .pointerCursor()
                    .disabled(!updater.canCheckForUpdates)
                Text("same path as the scheduled check")
                    .font(.system(size: UIScale.pt(10)))
                    .foregroundStyle(.tertiary)
            }
            if let next = nextCheckDescription {
                Text(next)
                    .font(.system(size: UIScale.pt(10)))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var rangeHint: String {
        let low = Int(UpdateCheckInterval.minimumSeconds)
        let high = Int(UpdateCheckInterval.maximumSeconds)
        return "Between \(low) and \(high) seconds."
    }

    private var noticeStyle: AnyShapeStyle {
        clampNotice == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange)
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(4)) {
            HStack(spacing: UIScale.pt(6)) {
                TextField("", text: $customSeconds)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: UIScale.pt(96))
                    .focused($customFocused)
                    .onSubmit(commitCustomSeconds)
                    .onChange(of: customFocused) { _, focused in
                        if !focused { commitCustomSeconds() }
                    }
                Text("seconds")
                    .font(.system(size: UIScale.pt(11)))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(UpdateCheckInterval.describe(updater.checkInterval))
                    .font(.system(size: UIScale.pt(10)))
                    .foregroundStyle(.tertiary)
            }
            Text(clampNotice ?? rangeHint)
                .font(.system(size: UIScale.pt(10)))
                .foregroundStyle(noticeStyle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!updater.automaticallyChecksForUpdates)
    }

    private var nextCheckDescription: String? {
        guard updater.automaticallyChecksForUpdates else { return "Automatic checks are off" }
        guard let last = updater.lastUpdateCheckDate else { return nil }
        let next = last.addingTimeInterval(updater.checkInterval)
        let formatted = next.formatted(.dateTime.month().day().hour().minute())
        return "Next check around \(formatted)"
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: UIScale.pt(8)) {
            HStack {
                Text("History")
                    .font(.system(size: UIScale.pt(11), weight: .medium))
                Spacer()
                if !updater.checkHistory.isEmpty {
                    Button("Clear", action: updater.clearCheckHistory)
                        .buttonStyle(.link)
                        .font(.system(size: UIScale.pt(10)))
                        .pointerCursor()
                }
            }
            if updater.checkHistory.isEmpty {
                Text("Checks appear here once Edith has looked for an update.")
                    .font(.system(size: UIScale.pt(11)))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UIScale.pt(6)) {
                        ForEach(updater.checkHistory) { record in
                            row(record)
                        }
                    }
                }
                .frame(maxHeight: UIScale.pt(190))
            }
        }
    }

    private func row(_ record: UpdateCheckRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: UIScale.pt(8)) {
            Circle()
                .fill(color(for: record.outcome))
                .frame(width: UIScale.pt(6), height: UIScale.pt(6))
            VStack(alignment: .leading, spacing: UIScale.pt(1)) {
                Text(record.date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.system(size: UIScale.pt(11), design: .monospaced))
                Text(record.summary)
                    .font(.system(size: UIScale.pt(10)))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.kind.label)
                .font(.system(size: UIScale.pt(9)))
                .foregroundStyle(.tertiary)
        }
    }

    private func color(for outcome: UpdateCheckRecord.Outcome) -> Color {
        switch outcome {
        case .upToDate: return .secondary
        case .updateFound: return .accentColor
        case .failed: return .red
        }
    }
}
