import AppKit
import Combine
import EdithKit
import SwiftUI

enum ExtensionPermissionState {
    static func readGrantedPermissions() -> [ExtensionPermission: Bool] {
        Dictionary(
            uniqueKeysWithValues: ExtensionPermission.allCases.map { permission in
                let granted: Bool
                if let key = permission.grantedDefaultsKey {
                    granted = SharedDefaults.store.bool(forKey: key)
                } else {
                    granted = false
                }
                return (permission, granted)
            })
    }
}

struct ExtensionsPane: View {
    @AppStorage("tabUsageEnabled", store: SharedDefaults.store) private var usageEnabled = false
    @AppStorage("claudeLimitsEnabled", store: SharedDefaults.store) private var claudeEnabled = true
    @AppStorage("codexLimitsEnabled", store: SharedDefaults.store) private var codexEnabled = true
    @AppStorage("limitsInMenuBar", store: SharedDefaults.store) private var limitsInMenuBar = true
    @AppStorage("notifyMaster", store: SharedDefaults.store) private var notifyMaster = false
    @AppStorage("limitsProvider", store: SharedDefaults.store) private var limitsProviderRaw =
        LimitProvider.claude.rawValue
    @AppStorage("tabMusicEnabled", store: SharedDefaults.store) private var musicEnabled = false
    @AppStorage("tabCalendarEnabled", store: SharedDefaults.store) private var calendarEnabled =
        false
    @AppStorage("tabSystemEnabled", store: SharedDefaults.store) private var systemEnabled = false
    @AppStorage("menuBarSystemStats", store: SharedDefaults.store) private var systemStats = false
    @AppStorage("notchShelfEnabled", store: SharedDefaults.store) private var notchShelfEnabled =
        false
    @AppStorage("clipboardEnabled", store: SharedDefaults.store) private var clipboardEnabled =
        false
    @AppStorage("focusDimEnabled", store: SharedDefaults.store) private var focusDimEnabled = false
    @AppStorage("micMuteEnabled", store: SharedDefaults.store) private var micMuteEnabled = false
    @AppStorage("colorPickerEnabled", store: SharedDefaults.store) private var colorPickerEnabled =
        false
    @AppStorage("presenterEnabled", store: SharedDefaults.store) private var presenterEnabled =
        false
    @AppStorage("preventSleep", store: SharedDefaults.store) private var preventSleep = false
    @State private var expanded: Set<String> = []
    @State private var grantedPermissions: [ExtensionPermission: Bool] = [:]
    @State private var permissionRequest: ExtensionPermissionRequest?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            ForEach(Array(ExtensionRegistry.entries.enumerated()), id: \.element.id) {
                index, entry in
                header(entry, group: groupTitle(at: index))
                if expanded.contains(entry.id) {
                    detailRows(for: entry)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Extensions")
        .animation(Motion.animation(Motion.snap, reduceMotion: reduceMotion), value: expanded)
        .onChange(of: systemEnabled) {
            if !systemEnabled { preventSleep = false }
        }
        .onChange(of: grantedPermissions) {
            enableRequestedExtensionIfReady()
        }
        .onAppear {
            refreshPermissionState()
            IPC.post(IPC.Name.requestPermissionsRefresh)
            markEnabledExtensionsSeen()
            if let id = SharedDefaults.store.string(forKey: "extensionsExpand") {
                expanded.insert(id)
                SharedDefaults.store.removeObject(forKey: "extensionsExpand")
            }
        }
        .sheet(item: $permissionRequest) { request in
            ExtensionPermissionSheet(
                request: request, grantedPermissions: grantedPermissions,
                grant: { IPC.post($0) }, cancel: { permissionRequest = nil },
                enable: { enableRequestedExtension(request) },
                refresh: requestPermissionRefresh)
        }
    }

    private var agentUsageBinding: Binding<Bool> {
        Binding(
            get: { usageEnabled },
            set: {
                applyAgentUsageState(AgentUsageSettingsFlow.setEnabled($0, in: agentUsageState))
            }
        )
    }

    private var agentUsageState: AgentUsageSettingsState {
        AgentUsageSettingsState(
            enabled: usageEnabled, claudeEnabled: claudeEnabled, codexEnabled: codexEnabled,
            menuBarEnabled: limitsInMenuBar, alertsEnabled: notifyMaster,
            selectedProvider: LimitProvider(rawValue: limitsProviderRaw) ?? .claude)
    }

    private func applyAgentUsageState(_ state: AgentUsageSettingsState) {
        usageEnabled = state.enabled
        claudeEnabled = state.claudeEnabled
        codexEnabled = state.codexEnabled
        limitsInMenuBar = state.menuBarEnabled
        notifyMaster = state.alertsEnabled
    }

    private func groupTitle(at index: Int) -> String? {
        let entry = ExtensionRegistry.entries[index]
        guard index == 0 || ExtensionRegistry.entries[index - 1].group != entry.group else {
            return nil
        }
        return entry.group.rawValue
    }

    private func enabledBinding(for entry: ExtensionRegistryEntry) -> Binding<Bool> {
        switch entry.defaultsKey {
        case "tabUsageEnabled": agentUsageBinding
        case "tabSystemEnabled": $systemEnabled
        case "menuBarSystemStats": $systemStats
        case "micMuteEnabled": $micMuteEnabled
        case "tabMusicEnabled": $musicEnabled
        case "tabCalendarEnabled": $calendarEnabled
        case "notchShelfEnabled": $notchShelfEnabled
        case "clipboardEnabled": $clipboardEnabled
        case "focusDimEnabled": $focusDimEnabled
        case "presenterEnabled": $presenterEnabled
        case "colorPickerEnabled": $colorPickerEnabled
        default: .constant(false)
        }
    }

    private func permissionAwareBinding(for entry: ExtensionRegistryEntry) -> Binding<Bool> {
        let enabled = enabledBinding(for: entry)
        return Binding(
            get: { enabled.wrappedValue },
            set: { newValue in
                guard newValue else {
                    if enabled.wrappedValue { markPermissionsSeen(for: entry) }
                    enabled.wrappedValue = false
                    return
                }
                let granted = ExtensionPermissionState.readGrantedPermissions()
                grantedPermissions = granted
                let decision = ExtensionPermissionFlow.decision(
                    for: entry, granted: granted,
                    hasSeenPermissions: hasSeenPermissions(for: entry))
                switch decision {
                case .enableDirectly:
                    enabled.wrappedValue = true
                    markPermissionsSeen(for: entry)
                case .showSheet(let required, let optional):
                    enabled.wrappedValue = false
                    permissionRequest = ExtensionPermissionRequest(
                        entry: entry, required: required, optional: optional)
                }
            })
    }

    private static func seenKey(for entry: ExtensionRegistryEntry) -> String {
        "extensionPermissionsSeen.\(entry.id)"
    }

    private func hasSeenPermissions(for entry: ExtensionRegistryEntry) -> Bool {
        SharedDefaults.store.bool(forKey: Self.seenKey(for: entry))
    }

    private func markPermissionsSeen(for entry: ExtensionRegistryEntry) {
        SharedDefaults.store.set(true, forKey: Self.seenKey(for: entry))
    }

    private func markEnabledExtensionsSeen() {
        for entry in ExtensionRegistry.entries
        where SharedDefaults.store.bool(forKey: entry.defaultsKey) {
            markPermissionsSeen(for: entry)
        }
    }

    private func refreshPermissionState() {
        grantedPermissions = ExtensionPermissionState.readGrantedPermissions()
    }

    private func requestPermissionRefresh() {
        IPC.post(IPC.Name.requestPermissionsRefresh)
        refreshPermissionState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard permissionRequest != nil else { return }
            refreshPermissionState()
        }
    }

    private func enableRequestedExtensionIfReady() {
        guard let request = permissionRequest, !request.required.isEmpty,
            request.entry.requiredPermissions.allSatisfy({ grantedPermissions[$0] == true })
        else { return }
        enableRequestedExtension(request)
    }

    private func enableRequestedExtension(_ request: ExtensionPermissionRequest) {
        enabledBinding(for: request.entry).wrappedValue = true
        markPermissionsSeen(for: request.entry)
        permissionRequest = nil
    }

    @ViewBuilder
    private func detailRows(for entry: ExtensionRegistryEntry) -> some View {
        switch entry.id {
        case "usage": UsageRows()
        case "system": SystemRows()
        case "systemStats": SystemStatsRows()
        case "micMute": MicMuteRows()
        case "music": MusicRows()
        case "notchShelf": NotchShelfRows()
        case "clipboard": ClipboardRows()
        case "focusDim": FocusDimRows()
        case "presenter": PresenterRows()
        case "colorPicker": ColorPickerRows()
        default: EmptyView()
        }
    }

    private func permissionGranted(_ permission: ExtensionPermission) -> Bool {
        grantedPermissions[permission] == true
    }

    private func chipStyle(
        for entry: ExtensionRegistryEntry, missing: [ExtensionPermission]
    ) -> (label: String, color: Color) {
        if entry.requiredPermissions.isEmpty {
            if entry.optionalPermissions.isEmpty {
                return ("No permissions", Color(nsColor: .secondaryLabelColor))
            }
            let names = entry.optionalPermissions.map(\.displayName).joined(separator: ", ")
            return ("Optional: \(names)", Color(nsColor: .secondaryLabelColor))
        }
        if missing.isEmpty { return ("granted", .green) }
        return (missing.map(\.displayName).joined(separator: ", "), .orange)
    }

    @ViewBuilder
    private func permissionChip(for entry: ExtensionRegistryEntry) -> some View {
        let missing = entry.requiredPermissions.filter { !permissionGranted($0) }
        let (label, color) = chipStyle(for: entry, missing: missing)
        if missing.isEmpty {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        } else {
            PermissionInfoButton(permissions: missing, label: label, color: color)
        }
    }

    private func header(_ entry: ExtensionRegistryEntry, group: String?) -> some View {
        let expandable = entry.id != "calendar"
        return Section {
            HStack(spacing: 12) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                    Text(entry.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                permissionChip(for: entry)
                Toggle("", isOn: permissionAwareBinding(for: entry))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .pointerCursor()
                if expandable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded.contains(entry.id) ? 90 : 0))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard expandable else { return }
                if expanded.contains(entry.id) {
                    expanded.remove(entry.id)
                } else {
                    expanded.insert(entry.id)
                }
            }
            .pointerCursor()
        } header: {
            if let group { Text(group) }
        }
    }
}

private struct ExtensionPermissionRequest: Identifiable {
    let entry: ExtensionRegistryEntry
    let required: [ExtensionPermission]
    let optional: [ExtensionPermission]

    var id: String { entry.id }
}

private struct ExtensionPermissionSheet: View {
    let request: ExtensionPermissionRequest
    let grantedPermissions: [ExtensionPermission: Bool]
    let grant: (Notification.Name) -> Void
    let cancel: () -> Void
    let enable: () -> Void
    let refresh: () -> Void

    private var requiredGranted: Bool {
        request.entry.requiredPermissions.allSatisfy { grantedPermissions[$0] == true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: request.entry.symbolName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable \(request.entry.title)")
                        .font(.title2.weight(.semibold))
                    Text(request.entry.subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            VStack(spacing: 10) {
                ForEach(request.required, id: \.self) { permission in
                    permissionCard(permission, required: true)
                }
                ForEach(request.optional, id: \.self) { permission in
                    permissionCard(permission, required: false)
                }
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .pointerCursor()
                if request.required.isEmpty {
                    Button("Enable anyway", action: enable)
                        .keyboardShortcut(.defaultAction)
                        .pointerCursor()
                } else {
                    Button("Enable when granted", action: enable)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!requiredGranted)
                        .pointerCursor()
                }
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refresh()
        }
    }

    private func permissionCard(_ permission: ExtensionPermission, required: Bool) -> some View {
        let isGranted = grantedPermissions[permission] == true
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    (isGranted ? Color.green : Color.secondary).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(permission.displayName)
                        .fontWeight(.medium)
                    PermissionInfoButton(permission)
                    Text(required ? "Required" : "Optional")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(required ? .orange : .secondary)
                }
                Text(permission.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let firstUseExplanation = permission.firstUseExplanation {
                    Text(firstUseExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else if let request = permission.grantRequest {
                Button("Grant") { grant(request) }
                    .controlSize(.small)
                    .pointerCursor()
            }
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct UsageRows: View {
    @AppStorage("tabUsageEnabled", store: SharedDefaults.store) private var enabled = false
    @AppStorage("limitsInMenuBar", store: SharedDefaults.store) private var limitsInMenuBar = true
    @AppStorage("claudeLimitsEnabled", store: SharedDefaults.store) private var claudeEnabled = true
    @AppStorage("codexLimitsEnabled", store: SharedDefaults.store) private var codexEnabled = true
    @AppStorage("limitsProvider", store: SharedDefaults.store) private var limitsProviderRaw =
        LimitProvider.claude.rawValue
    @AppStorage("menuBarColorMode", store: SharedDefaults.store) private var menuBarColorMode =
        "auto"
    @AppStorage("smartColor", store: SharedDefaults.store) private var smartColor = true
    @AppStorage("menuBarSubColorHex", store: SharedDefaults.store) private var subColorHex =
        "8E8E93"
    @AppStorage("menuBarLowColorHex", store: SharedDefaults.store) private var lowColorHex =
        "34C759"
    @AppStorage("menuBarMidColorHex", store: SharedDefaults.store) private var midColorHex =
        "FF9500"
    @AppStorage("menuBarHighColorHex", store: SharedDefaults.store) private var highColorHex =
        "FF3B30"
    @AppStorage("warnPercent", store: SharedDefaults.store) private var warnPercent = 60
    @AppStorage("critPercent", store: SharedDefaults.store) private var critPercent = 85
    @AppStorage("pacingMargin", store: SharedDefaults.store) private var pacingMargin = 10.0
    @AppStorage("budgetEnabled", store: SharedDefaults.store) private var budgetEnabled = false
    @AppStorage("budgetMode", store: SharedDefaults.store) private var budgetMode = "pace"
    @AppStorage("budgetKind", store: SharedDefaults.store) private var budgetKind = "weekly"
    @AppStorage("budgetCapPercent", store: SharedDefaults.store) private var budgetCap = 50.0
    @AppStorage("budgetDeadline", store: SharedDefaults.store) private var budgetDeadlineTS = 0.0
    @AppStorage("notifyMaster", store: SharedDefaults.store) private var notifyMaster = false
    @AppStorage("notifyTrackSession", store: SharedDefaults.store) private var trackSession = true
    @AppStorage("notifyTrackWeekly", store: SharedDefaults.store) private var trackWeekly = true
    @AppStorage("notifyRecovery", store: SharedDefaults.store) private var recovery = true
    @AppStorage("notifyPacingWarning", store: SharedDefaults.store) private var pacingWarning = true
    @AppStorage("notifyPacingHot", store: SharedDefaults.store) private var pacingHot = true
    @AppStorage("notifyReminderSession", store: SharedDefaults.store) private var reminderSession =
        false
    @AppStorage("notifyReminderSessionOffsetMin", store: SharedDefaults.store)
    private var reminderSessionOffset = 30
    @AppStorage("notifyReminderWeekly", store: SharedDefaults.store) private var reminderWeekly =
        false
    @AppStorage("notifyReminderWeeklyOffsetMin", store: SharedDefaults.store)
    private var reminderWeeklyOffset = 120
    @AppStorage("notifyTokenExpired", store: SharedDefaults.store) private var tokenExpired = true
    @State private var testSent = false

    private var hasProvider: Bool { claudeEnabled || codexEnabled }

    var body: some View {
        Section {
            Group {
                Toggle("Claude limits", isOn: $claudeEnabled)
                    .pointerCursor()
                Toggle("Codex limits", isOn: $codexEnabled)
                    .pointerCursor()
                Toggle("Show limits in the menu bar", isOn: $limitsInMenuBar)
                    .pointerCursor()

                if limitsInMenuBar {
                    Picker("Color", selection: colorModeBinding) {
                        Text("White").tag("white")
                        Text("Black").tag("black")
                        Text("Custom").tag("custom")
                    }
                    .pointerCursor()

                    if isCustomColor {
                        ColorPicker(
                            "Text (5h / 7d)", selection: hexBinding($subColorHex),
                            supportsOpacity: false)
                        ColorPicker(
                            "Low risk", selection: hexBinding($lowColorHex),
                            supportsOpacity: false)
                        ColorPicker(
                            "Medium risk", selection: hexBinding($midColorHex),
                            supportsOpacity: false)
                        ColorPicker(
                            "High risk", selection: hexBinding($highColorHex),
                            supportsOpacity: false)
                        Toggle("Smart color", isOn: $smartColor)
                            .pointerCursor()
                        if !smartColor {
                            HStack {
                                Text("Thresholds")
                                Spacer()
                                Stepper(
                                    "Warn \(warnPercent)%", value: $warnPercent,
                                    in: 10...critPercent - 5, step: 5
                                )
                                .pointerCursor()
                                Stepper(
                                    "Critical \(critPercent)%", value: $critPercent,
                                    in: warnPercent + 5...100, step: 5
                                )
                                .pointerCursor()
                            }
                        }
                    }
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
            if !hasProvider {
                Label("Agent Usage is paused", systemImage: "pause.circle.fill")
                    .foregroundStyle(.secondary)
                Text(
                    "Turn on Agent Usage above to restore \(selectedProvider.label) limits. Menu bar limits and alerts are off."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Readout styling")
        } footer: {
            if limitsInMenuBar {
                Text(
                    isCustomColor
                        ? "The percentage shifts from Low to High risk as usage climbs. Smart color drives that shift by time-aware pacing instead of the raw percentage."
                        : "White and Black force a single tint. Pick Custom to color by risk stage."
                )
                .font(.caption)
            }
        }

        Section {
            Toggle("Pace my Claude usage", isOn: $budgetEnabled)
                .pointerCursor()
            Text(
                "Set a personal cap under the real limit and get told if you're spending too fast."
            )
            .font(.caption).foregroundStyle(.secondary)
            if budgetEnabled {
                Picker("Mode", selection: $budgetMode) {
                    Text("Auto daily pace").tag("pace")
                    Text("Cap by a deadline").tag("cap")
                }.pointerCursor()
                Picker("Window", selection: $budgetKind) {
                    Text("Weekly").tag("weekly")
                    Text("Session (5h)").tag("session")
                }.pointerCursor()
                HStack {
                    Text("Cap")
                    Slider(value: $budgetCap, in: 10...100, step: 5)
                    Text("\(Int(budgetCap))%").monospacedDigit().frame(
                        width: 40, alignment: .trailing)
                }
                if budgetMode == "cap" {
                    DatePicker(
                        "Stay under until",
                        selection: Binding(
                            get: {
                                budgetDeadlineTS > 0
                                    ? Date(timeIntervalSinceReferenceDate: budgetDeadlineTS)
                                    : Date().addingTimeInterval(2 * 86400)
                            },
                            set: { budgetDeadlineTS = $0.timeIntervalSinceReferenceDate }),
                        displayedComponents: [.date, .hourAndMinute])
                }
            }
        } header: {
            Text("Budget and pacing")
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)

        Section {
            Toggle("Enable alerts", isOn: alertsBinding)
                .pointerCursor()
            Group {
                Toggle(isOn: $trackSession) {
                    HStack(spacing: 6) {
                        Text("Session (5h) alerts")
                        InfoDot(
                            "Fires once when the session window crosses warn or critical - it won't repeat while you stay in that zone."
                        )
                    }
                }
                .pointerCursor()
                Toggle(isOn: $trackWeekly) {
                    HStack(spacing: 6) {
                        Text("Weekly alerts")
                        InfoDot(
                            "Fires once when the weekly window crosses warn or critical - same one-shot-per-zone behavior as session alerts."
                        )
                    }
                }
                .pointerCursor()
                Toggle("Back to green", isOn: $recovery)
                    .pointerCursor()
                HStack {
                    Text("Pacing margin")
                    Spacer()
                    Stepper(
                        "±\(Int(pacingMargin)) pp", value: $pacingMargin, in: 5...25, step: 5
                    )
                    .pointerCursor()
                }
                Toggle(isOn: $pacingWarning) {
                    HStack(spacing: 6) {
                        Text("Drifting / burning hot")
                        InfoDot(
                            "A separate signal from the level alerts above: how far ahead of an even burn-rate pace you are, regardless of the absolute percentage."
                        )
                    }
                }
                .pointerCursor()
                Toggle("Token expired", isOn: $tokenExpired)
                    .pointerCursor()
                HStack {
                    Toggle("Remind before session reset", isOn: $reminderSession)
                        .pointerCursor()
                    Picker("", selection: $reminderSessionOffset) {
                        Text("5 min").tag(5)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 h").tag(60)
                    }
                    .labelsHidden().pointerCursor().disabled(!reminderSession)
                }
                HStack {
                    Toggle("Remind before weekly reset", isOn: $reminderWeekly)
                        .pointerCursor()
                    Picker("", selection: $reminderWeeklyOffset) {
                        Text("1 h").tag(60)
                        Text("2 h").tag(120)
                        Text("6 h").tag(360)
                        Text("12 h").tag(720)
                    }
                    .labelsHidden().pointerCursor().disabled(!reminderWeekly)
                }
            }
            .disabled(!notifyMaster)
            .opacity(notifyMaster ? 1 : 0.5)

            HStack {
                Button("Send test notification") {
                    IPC.post(IPC.Name.requestTestNotification)
                    testSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { testSent = false }
                }
                .pointerCursor()
                if testSent {
                    Text("Sent - check Notification Center")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Alerts")
        } footer: {
            Text(
                "Alerts fire once per level or zone crossing, not on a repeating timer - staying in the same zone won't page you again."
            )
            .font(.caption)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .onChange(of: claudeEnabled) { reconcileProviders() }
        .onChange(of: codexEnabled) { reconcileProviders() }
    }

    private var alertsBinding: Binding<Bool> {
        Binding(
            get: { notifyMaster },
            set: { enabled in
                notifyMaster = enabled
                if enabled && !SharedDefaults.store.bool(forKey: "permNotificationsGranted") {
                    IPC.post(IPC.Name.grantNotifications)
                }
            })
    }

    private var isCustomColor: Bool {
        menuBarColorMode == "custom" || menuBarColorMode == "auto"
    }

    private var colorModeBinding: Binding<String> {
        Binding(
            get: { isCustomColor ? "custom" : menuBarColorMode },
            set: { menuBarColorMode = $0 })
    }

    private func hexBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { DashPalette.color(hex.wrappedValue) },
            set: { hex.wrappedValue = $0.hex6 })
    }

    private var selectedProvider: LimitProvider {
        LimitProvider(rawValue: limitsProviderRaw) ?? .claude
    }

    private func reconcileProviders() {
        let state = AgentUsageSettingsFlow.providersChanged(
            AgentUsageSettingsState(
                enabled: enabled, claudeEnabled: claudeEnabled, codexEnabled: codexEnabled,
                menuBarEnabled: limitsInMenuBar, alertsEnabled: notifyMaster,
                selectedProvider: selectedProvider))
        enabled = state.enabled
        limitsInMenuBar = state.menuBarEnabled
        notifyMaster = state.alertsEnabled
    }
}

private struct SystemStatsRows: View {
    @AppStorage("menuBarSystemStats", store: SharedDefaults.store) private var enabled = false
    @AppStorage("menuBarStatsColorHex", store: SharedDefaults.store) private var statsColorHex =
        "FFFFFF"

    var body: some View {
        Section {
            ColorPicker(
                "Color",
                selection: Binding(
                    get: { DashPalette.color(statsColorHex) },
                    set: { statsColorHex = $0.hex6 }),
                supportsOpacity: false)
            Text("Sampled every couple of seconds; costs nothing measurable.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

private struct MusicRows: View {
    @AppStorage("tabMusicEnabled", store: SharedDefaults.store) private var enabled = false

    var body: some View {
        Section {
            LabeledContent("Music folder") {
                Button("Open in Finder") {
                    try? FileManager.default.createDirectory(
                        at: Repo.musicDir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(Repo.musicDir)
                }
                .pointerCursor()
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

private struct MicMuteRows: View {
    @AppStorage("micMuteEnabled", store: SharedDefaults.store) private var enabled = false
    @AppStorage("micMuteInMenuBar", store: SharedDefaults.store) private var inMenuBar = true

    var body: some View {
        Section {
            Toggle("Show in the menu bar", isOn: $inMenuBar)
                .pointerCursor()
            Text("The menu bar icon shows the current mute state and toggles it on click.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

private struct SystemRows: View {
    @AppStorage("tabSystemEnabled", store: SharedDefaults.store) private var enabled = false
    @AppStorage("preventSleep", store: SharedDefaults.store) private var preventSleep = false
    @State private var cleaningStarted = false

    var body: some View {
        Section {
            Toggle(isOn: $preventSleep) {
                HStack(spacing: 6) {
                    Text("Keep awake")
                    InfoDot(
                        "Keeps your Mac awake until you turn this off again, even with the lid closed on power."
                    )
                }
            }
            .pointerCursor()
            HStack {
                Text("Keyboard cleaning")
                InfoDot(
                    "Locks the keyboard so you can wipe it without typing anything. Press the on-screen button or wait for the timer to unlock."
                )
                Spacer()
                if cleaningStarted {
                    Text("Locked - check the overlay")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Clean now") {
                    IPC.post(IPC.Name.requestKeyboardClean)
                    cleaningStarted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        cleaningStarted = false
                    }
                }
                .pointerCursor()
            }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}
