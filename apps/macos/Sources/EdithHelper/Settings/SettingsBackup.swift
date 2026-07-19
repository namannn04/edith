import AppKit
import EdithKit
import Foundation

enum SettingsBackupDataClass: CaseIterable {
    case settings
    case usage
    case limits
    case music
    case clipboard
}

struct SettingsBackupTransferDecision: Equatable {
    let shouldRestore: Bool
    let shouldExport: Bool
}

func settingsBackupTransferDecision(
    for dataClass: SettingsBackupDataClass,
    masterEnabled: Bool,
    subToggleEnabled: Bool,
    extensionEnabled: Bool
) -> SettingsBackupTransferDecision {
    switch dataClass {
    case .settings, .usage, .limits, .music, .clipboard:
        let shouldRestore = masterEnabled && subToggleEnabled
        return SettingsBackupTransferDecision(
            shouldRestore: shouldRestore,
            shouldExport: shouldRestore && extensionEnabled)
    }
}

@MainActor
final class SettingsBackup: ObservableObject {
    static let shared = SettingsBackup()

    @Published private(set) var musicBackupRunning = false
    @Published private(set) var clipboardBackupRunning = false

    nonisolated static let backedKeys = [
        "theme", "tab", "presenterMode", "presenterBlurMusic", "presenterBlurMoney",
        "presenterBlurUsage",
        "presenterEnabled",
        "presenterAutoEnabled", "presenterHideMenuBarNumbers", "presenterDetectRecording",
        "presenterDetectScreenSharing", "presenterDetectMirroring",
        "presenterHotKeyCode", "presenterHotKeyMods", "presenterHotKeyLabel",
        "tabUsageEnabled", "tabMusicEnabled",
        "hotKeyCode", "hotKeyMods", "hotKeyLabel", "musicVolume", "repoPath",
        "icloudBackup", "musicBackup", "lastPaletteTheme", "appearance",
        "tabSystemEnabled", "preventSleep", "tabOrder",
        "backupSettings", "backupUsage", "backupLimits",
        "budgetEnabled", "budgetMode", "budgetKind", "budgetCapPercent", "budgetDeadline",
        "claudeLimitsEnabled", "codexLimitsEnabled", "limitsProvider",
        "limitsInMenuBar", "menuBarColorMode", "smartColor",
        "menuBarSubColorHex", "menuBarLowColorHex", "menuBarMidColorHex", "menuBarHighColorHex",
        "menuBarStatsColorHex", "warnPercent", "critPercent", "pacingMargin",
        "notifyMaster", "notifyTrackSession", "notifyTrackWeekly",
        "notifyRecovery", "notifyPacingWarning", "notifyPacingHot",
        "notifyReminderSession", "notifyReminderSessionOffsetMin",
        "notifyReminderWeekly", "notifyReminderWeeklyOffsetMin",
        "notifyTokenExpired",
        "dashRange", "dashSources", "dashKnownSources", "dashSourceSelectionVersion", "dashModels",
        "dashBillingDay", "dashSort", "dashSortAsc",
        "dashHeatMetric", "projSort", "projSortAsc", "systemAppsSort", "systemAppsSortAsc",
        "menuBarSystemStats", "micMuteEnabled", "micMuteInMenuBar",
        "micHotKeyCode", "micHotKeyMods", "micHotKeyLabel", "cleanerSelectionOverrides",
        "cleanerCategoryDefaults",
        "cleanerSelectedDrives", "cleanerCustomFolders",
        "notchShelfEnabled", "notchShelfOpenOnDrag", "notchShelfOpenOnHover",
        "notchShelfRequireOption", "notchShelfKeepDuration", "notchShelfRemoveAfterDragOut",
        "notchShelfShowOnExternal", "notchShelfHaptics", "notchShelfShowMusic",
        "notchAlertsEnabled", "notchAlertAudio", "notchAlertPower", "notchAlertBattery",
        "notchAlertBluetooth", "notchAudioMixerEnabled",
        "clipboardEnabled", "clipboardHotKeyCode", "clipboardHotKeyMods", "clipboardHotKeyLabel",
        "clipboardMaxItems", "clipboardMaxItemBytes", "clipboardMaxAgeDays",
        "clipboardIgnoredApps", "clipboardAutoPaste", "clipboardPastePlainText",
        "clipboardCheckInterval", "clipboardBackup", "lastClipboardBackupAt",
        "clipboardPopupAt", "clipboardPinTo", "clipboardShowFooter",
        "clipboardSaveFiles", "clipboardSaveImages", "clipboardSaveText",
        "clipboardWindowPositionX", "clipboardWindowPositionY",
        "focusDimEnabled", "focusDimIntensity", "focusDimAnimationDuration",
        "focusDimOtherDisplaysMode", "focusDimHotKeyCode", "focusDimHotKeyMods",
        "focusDimHotKeyLabel",
        "colorPickerEnabled", "colorPickerCopyFormat", "colorPickerProfile",
        "colorPickerHistorySize", "colorPickerHotKeyCode", "colorPickerHotKeyMods",
        "colorPickerHotKeyLabel",
        "creditHidden", "homeClockZones", "presenterBlurCalendar", "showDockIcon",
        "tabCalendarEnabled", "musicLooping",
        "mainWindowSection", "settingsTab", "mainSidebarOpen", "mainSidebarWidth",
    ]

    nonisolated static let sharedKeys: Set<String> = [
        "theme", "lastPaletteTheme", "appearance",
        "presenterMode", "presenterEnabled", "presenterBlurMusic", "presenterBlurMoney",
        "presenterBlurUsage",
        "presenterAutoEnabled", "presenterHideMenuBarNumbers", "presenterDetectRecording",
        "presenterDetectScreenSharing", "presenterDetectMirroring",
        "presenterHotKeyCode", "presenterHotKeyMods", "presenterHotKeyLabel",
        "tabUsageEnabled", "tabMusicEnabled", "tabSystemEnabled", "tabCalendarEnabled", "tabOrder",
        "icloudBackup", "lastBackupAt", "musicBackup", "lastMusicBackupAt",
        "backupSettings", "backupUsage", "backupLimits",
        "budgetEnabled", "budgetMode", "budgetKind", "budgetCapPercent", "budgetDeadline",
        "claudeLimitsEnabled", "codexLimitsEnabled", "limitsProvider",
        "limitsInMenuBar", "menuBarColorMode", "smartColor",
        "menuBarSubColorHex", "menuBarLowColorHex", "menuBarMidColorHex", "menuBarHighColorHex",
        "menuBarStatsColorHex", "warnPercent", "critPercent", "pacingMargin",
        "notifyMaster", "notifyTrackSession", "notifyTrackWeekly",
        "notifyRecovery", "notifyPacingWarning", "notifyPacingHot",
        "notifyReminderSession", "notifyReminderSessionOffsetMin",
        "notifyReminderWeekly", "notifyReminderWeeklyOffsetMin",
        "notifyTokenExpired", "hotKeyCode", "hotKeyMods", "hotKeyLabel",
        "dashRange", "dashSources", "dashKnownSources", "dashSourceSelectionVersion", "dashModels",
        "dashBillingDay", "dashSort", "dashSortAsc",
        "dashHeatMetric", "projSort", "projSortAsc", "systemAppsSort", "systemAppsSortAsc",
        "menuBarSystemStats", "micMuteEnabled", "micMuteInMenuBar",
        "micHotKeyCode", "micHotKeyMods", "micHotKeyLabel", "cleanerSelectionOverrides",
        "cleanerCategoryDefaults",
        "cleanerSelectedDrives", "cleanerCustomFolders",
        "preventSleep", "repoPath",
        "notchShelfEnabled", "notchShelfOpenOnDrag", "notchShelfOpenOnHover",
        "notchShelfRequireOption", "notchShelfKeepDuration", "notchShelfRemoveAfterDragOut",
        "notchShelfShowOnExternal", "notchShelfHaptics", "notchShelfShowMusic",
        "notchAlertsEnabled", "notchAlertAudio", "notchAlertPower", "notchAlertBattery",
        "notchAlertBluetooth", "notchAudioMixerEnabled",
        "clipboardEnabled", "clipboardHotKeyCode", "clipboardHotKeyMods", "clipboardHotKeyLabel",
        "clipboardMaxItems", "clipboardMaxItemBytes", "clipboardMaxAgeDays",
        "clipboardIgnoredApps", "clipboardAutoPaste", "clipboardPastePlainText",
        "clipboardCheckInterval", "clipboardBackup", "lastClipboardBackupAt",
        "clipboardPopupAt", "clipboardPinTo", "clipboardShowFooter",
        "clipboardSaveFiles", "clipboardSaveImages", "clipboardSaveText",
        "clipboardWindowPositionX", "clipboardWindowPositionY",
        "focusDimEnabled", "focusDimIntensity", "focusDimAnimationDuration",
        "focusDimOtherDisplaysMode", "focusDimHotKeyCode", "focusDimHotKeyMods",
        "focusDimHotKeyLabel",
        "colorPickerEnabled", "colorPickerCopyFormat", "colorPickerProfile",
        "colorPickerHistorySize", "colorPickerHotKeyCode", "colorPickerHotKeyMods",
        "colorPickerHotKeyLabel",
        "creditHidden", "homeClockZones", "presenterBlurCalendar", "showDockIcon",
        "mainWindowSection", "settingsTab", "mainSidebarOpen", "mainSidebarWidth",
    ]

    nonisolated static let deviceLocalKeys: Set<String> = [
        "extensionsExpand", "hasPromptedPermissions", "lastBackupAt", "lastMusicBackupAt",
        "lastClipboardBackupAt", "micMuted", "migratedFromControlCenter",
        "notifSessionLevel", "notifSessionPacing", "notifTokenExpiredAt", "notifWeeklyLevel",
        "notifWeeklyPacing", "permAccessibilityGranted", "permCalendarGranted",
        "permCameraGranted", "permFullDiskGranted", "permInputMonitoringGranted",
        "permNotificationsGranted",
        "permScreenRecordingGranted", "presenterAutoActive", "presenterAutoPaused",
        "presenterAutoReason", "settingsSection",
    ]

    private func store(for key: String) -> UserDefaults {
        Self.sharedKeys.contains(key) ? SharedDefaults.store : .standard
    }

    private var debounce: Timer?
    private var localFile: URL { AppData.supportDir.appendingPathComponent("settings.json") }
    private var cloudFile: URL { AppData.cloudDir.appendingPathComponent("settings.json") }

    private var localLimits: URL { LimitsHistory.url }
    private var cloudLimits: URL {
        AppData.cloudDir.appendingPathComponent("data/limits-history.jsonl")
    }
    private var localUsage: URL { Repo.usageJSON }
    private var cloudUsage: URL { AppData.cloudDir.appendingPathComponent("data/usage.json") }
    private var observedICloudBackup = false

    private func flag(_ key: String) -> Bool {
        store(for: key).object(forKey: key) as? Bool ?? true
    }

    private func transferDecision(
        for dataClass: SettingsBackupDataClass
    ) -> SettingsBackupTransferDecision {
        let subToggleEnabled: Bool
        let extensionEnabled: Bool
        switch dataClass {
        case .settings:
            subToggleEnabled = flag("backupSettings")
            extensionEnabled = true
        case .usage:
            subToggleEnabled = flag("backupUsage")
            extensionEnabled = SharedDefaults.store.bool(forKey: "tabUsageEnabled")
        case .limits:
            subToggleEnabled = flag("backupLimits")
            extensionEnabled = SharedDefaults.store.bool(forKey: "tabUsageEnabled")
        case .music:
            subToggleEnabled = SharedDefaults.store.bool(forKey: "musicBackup")
            extensionEnabled = SharedDefaults.store.bool(forKey: "tabMusicEnabled")
        case .clipboard:
            subToggleEnabled = SharedDefaults.store.bool(forKey: "clipboardBackup")
            extensionEnabled = SharedDefaults.store.bool(forKey: "clipboardEnabled")
        }
        return settingsBackupTransferDecision(
            for: dataClass,
            masterEnabled: SharedDefaults.store.bool(forKey: "icloudBackup"),
            subToggleEnabled: subToggleEnabled,
            extensionEnabled: extensionEnabled)
    }

    private func isApplicationSupportURL(_ url: URL) -> Bool {
        let supportPath = AppData.supportDir.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == supportPath || path.hasPrefix(supportPath + "/")
    }

    func start() {
        observedICloudBackup = SharedDefaults.store.bool(forKey: "icloudBackup")
        let restored = restoreFromCloud()
        export()
        exportLimits()
        exportUsage()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleExport() }
        }
        if !restored.music {
            backupMusic()
        }
        if !restored.clipboard {
            backupClipboard()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SettingsBackup.shared.debounceFlush()
                SettingsBackup.shared.syncLimits()
            }
        }
    }

    func settingsDidChange() {
        let icloudBackup = SharedDefaults.store.bool(forKey: "icloudBackup")
        let shouldRestore = icloudBackup && !observedICloudBackup
        observedICloudBackup = icloudBackup
        if shouldRestore {
            _ = restoreFromCloud()
            observedICloudBackup = SharedDefaults.store.bool(forKey: "icloudBackup")
        }
        scheduleExport()
        scheduleClipboardBackup()
    }

    @discardableResult
    private func restoreFromCloud() -> (music: Bool, clipboard: Bool) {
        guard SharedDefaults.store.bool(forKey: "icloudBackup"), AppData.cloudAvailable else {
            return (false, false)
        }
        let decisions = Dictionary(
            uniqueKeysWithValues: SettingsBackupDataClass.allCases.map {
                ($0, transferDecision(for: $0))
            })
        importFromCloudIfNewer(decision: decisions[.settings]!)
        transferLimits(
            decision: decisions[.limits]!, restore: true, export: false,
            requireApplicationSupportRestore: true)
        transferUsage(
            decision: decisions[.usage]!, restore: true, export: false,
            requireApplicationSupportRestore: true)
        let music = restoreMusic(
            decision: decisions[.music]!, requireApplicationSupportDestination: true)
        let clipboard = restoreClipboard(decision: decisions[.clipboard]!)
        return (music, clipboard)
    }

    func debounceFlush() {
        if debounce?.isValid == true {
            debounce?.invalidate()
            export()
        }
    }

    func backupMusic() {
        guard !musicBackupRunning, AppData.cloudAvailable,
            transferDecision(for: .music).shouldExport,
            FileManager.default.fileExists(atPath: Repo.musicDir.path)
        else { return }
        musicBackupRunning = true
        let destination = AppData.cloudDir.appendingPathComponent("music")
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        p.arguments = ["-a", Repo.musicDir.path + "/", destination.path + "/"]
        p.qualityOfService = .utility
        p.terminationHandler = { process in
            Task { @MainActor in
                self.musicBackupRunning = false
                if process.terminationStatus == 0 {
                    SharedDefaults.store.set(
                        Date().timeIntervalSince1970, forKey: "lastMusicBackupAt")
                }
            }
        }
        do {
            try p.run()
        } catch {
            musicBackupRunning = false
        }
    }

    @discardableResult
    private func restoreMusic(
        decision: SettingsBackupTransferDecision,
        requireApplicationSupportDestination: Bool
    ) -> Bool {
        let destination = Repo.musicDir
        guard decision.shouldRestore,
            !requireApplicationSupportDestination || isApplicationSupportURL(destination)
        else { return false }
        let source = AppData.cloudDir.appendingPathComponent("music")
        let fm = FileManager.default
        func hasAudio(_ dir: URL) -> Bool {
            let exts: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "aiff", "flac"]
            return ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
                .contains { exts.contains(($0 as NSString).pathExtension.lowercased()) }
        }
        guard hasAudio(source), !hasAudio(destination) else { return false }
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        p.arguments = ["-a", "--exclude", ".DS_Store", source.path + "/", destination.path + "/"]
        p.qualityOfService = .utility
        p.terminationHandler = { proc in
            if proc.terminationStatus == 0 {
                NotificationCenter.default.post(name: .musicFolderChanged, object: nil)
            }
        }
        do {
            try p.run()
            return true
        } catch {
            return false
        }
    }

    private var localClipboardDir: URL { ClipboardPaths.dir }
    private var cloudClipboardDir: URL { AppData.cloudDir.appendingPathComponent("clipboard") }
    private var clipboardDebounce: Timer?

    func scheduleClipboardBackup() {
        guard AppData.cloudAvailable, transferDecision(for: .clipboard).shouldExport else {
            clipboardDebounce?.invalidate()
            clipboardDebounce = nil
            return
        }
        clipboardDebounce?.invalidate()
        clipboardDebounce = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            Task { @MainActor in SettingsBackup.shared.backupClipboard() }
        }
    }

    func backupClipboard() {
        guard !clipboardBackupRunning, AppData.cloudAvailable,
            transferDecision(for: .clipboard).shouldExport,
            FileManager.default.fileExists(atPath: localClipboardDir.path)
        else { return }
        clipboardBackupRunning = true
        try? FileManager.default.createDirectory(
            at: cloudClipboardDir, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        p.arguments = [
            "-a", "--delete", "--max-size=1m",
            "--include", "*/", "--include", "index.jsonl",
            "--include", "*.txt", "--include", "*.rtf", "--include", "*.html",
            "--include", "*.url", "--include", "*.png", "--include", "*.tiff",
            "--exclude", "*",
            localClipboardDir.path + "/", cloudClipboardDir.path + "/",
        ]
        p.qualityOfService = .utility
        p.terminationHandler = { process in
            Task { @MainActor in
                self.clipboardBackupRunning = false
                if process.terminationStatus == 0 {
                    SharedDefaults.store.set(
                        Date().timeIntervalSince1970, forKey: "lastClipboardBackupAt")
                }
            }
        }
        do {
            try p.run()
        } catch {
            clipboardBackupRunning = false
        }
    }

    @discardableResult
    private func restoreClipboard(
        decision: SettingsBackupTransferDecision,
        attempts: Int = 3
    ) -> Bool {
        guard decision.shouldRestore else { return false }
        let fm = FileManager.default
        let cloudIndex = cloudClipboardDir.appendingPathComponent("index.jsonl")
        let localIndex = localClipboardDir.appendingPathComponent("index.jsonl")
        guard !fm.fileExists(atPath: localIndex.path) else { return false }
        guard fm.fileExists(atPath: cloudIndex.path) else {
            let placeholder = cloudClipboardDir.appendingPathComponent(".index.jsonl.icloud")
            guard attempts > 0, fm.fileExists(atPath: placeholder.path) else { return false }
            try? fm.startDownloadingUbiquitousItem(at: cloudClipboardDir)
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                Task { @MainActor in
                    let decision = SettingsBackup.shared.transferDecision(for: .clipboard)
                    SettingsBackup.shared.restoreClipboard(
                        decision: decision, attempts: attempts - 1)
                }
            }
            return true
        }
        try? fm.startDownloadingUbiquitousItem(at: cloudClipboardDir)
        try? fm.createDirectory(at: localClipboardDir, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        p.arguments = ["-a", cloudClipboardDir.path + "/", localClipboardDir.path + "/"]
        p.qualityOfService = .utility
        p.terminationHandler = { process in
            if process.terminationStatus == 0 {
                ClipboardRepository.pruneEntriesMissingBlobs()
                IPC.post(IPC.Name.clipboardChanged)
            }
        }
        do {
            try p.run()
            return true
        } catch {
            return false
        }
    }

    func scheduleExport() {
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            Task { @MainActor in SettingsBackup.shared.export() }
        }
    }

    private func snapshot() -> Data? {
        var dict: [String: Any] = [:]
        for key in Self.backedKeys {
            if let value = store(for: key).object(forKey: key) { dict[key] = value }
        }
        return try? JSONSerialization.data(
            withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    func export() {
        guard let data = snapshot() else { return }
        if (try? Data(contentsOf: localFile)) != data {
            try? data.write(to: localFile)
        }
        guard AppData.cloudAvailable, transferDecision(for: .settings).shouldExport else { return }
        try? FileManager.default.createDirectory(
            at: AppData.cloudDir, withIntermediateDirectories: true)
        if (try? Data(contentsOf: cloudFile)) != data {
            try? data.write(to: cloudFile)
            SharedDefaults.store.set(Date().timeIntervalSince1970, forKey: "lastBackupAt")
        }
    }

    func syncData() {
        syncLimits()
        syncUsage()
    }

    func syncLimits() {
        transferLimits(
            decision: transferDecision(for: .limits), restore: true, export: true,
            requireApplicationSupportRestore: false)
    }

    private func exportLimits() {
        transferLimits(
            decision: transferDecision(for: .limits), restore: false, export: true,
            requireApplicationSupportRestore: false)
    }

    private func transferLimits(
        decision: SettingsBackupTransferDecision,
        restore: Bool,
        export: Bool,
        requireApplicationSupportRestore: Bool
    ) {
        guard AppData.cloudAvailable else { return }
        let shouldRestore =
            restore && decision.shouldRestore
            && (!requireApplicationSupportRestore || isApplicationSupportURL(localLimits))
        let shouldExport = export && decision.shouldExport
        guard shouldRestore || shouldExport else { return }
        let fm = FileManager.default
        let localText = (try? String(contentsOf: localLimits, encoding: .utf8)) ?? ""
        var cloudText = ""
        if fm.fileExists(atPath: cloudLimits.path) {
            if let t = try? String(contentsOf: cloudLimits, encoding: .utf8) {
                cloudText = t
            } else {
                try? fm.startDownloadingUbiquitousItem(at: cloudLimits)
                return
            }
        }
        let merged = LimitsHistory.merge(localText, cloudText)
        guard !merged.isEmpty else { return }
        let data = Data(merged.utf8)
        try? fm.createDirectory(
            at: localLimits.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.createDirectory(
            at: cloudLimits.deletingLastPathComponent(), withIntermediateDirectories: true)
        if shouldRestore, (try? Data(contentsOf: localLimits)) != data {
            try? data.write(to: localLimits)
        }
        if shouldExport, (try? Data(contentsOf: cloudLimits)) != data {
            try? data.write(to: cloudLimits)
        }
    }

    func syncUsage() {
        transferUsage(
            decision: transferDecision(for: .usage), restore: true, export: true,
            requireApplicationSupportRestore: false)
    }

    private func exportUsage() {
        transferUsage(
            decision: transferDecision(for: .usage), restore: false, export: true,
            requireApplicationSupportRestore: false)
    }

    private func transferUsage(
        decision: SettingsBackupTransferDecision,
        restore: Bool,
        export: Bool,
        requireApplicationSupportRestore: Bool
    ) {
        guard AppData.cloudAvailable else { return }
        let shouldRestore =
            restore && decision.shouldRestore
            && (!requireApplicationSupportRestore || isApplicationSupportURL(localUsage))
        let shouldExport = export && decision.shouldExport
        guard shouldRestore || shouldExport else { return }
        let fm = FileManager.default
        let localData = try? Data(contentsOf: localUsage)
        var cloudData: Data?
        if fm.fileExists(atPath: cloudUsage.path) {
            cloudData = try? Data(contentsOf: cloudUsage)
            if cloudData == nil {
                try? fm.startDownloadingUbiquitousItem(at: cloudUsage)
                return
            }
        }
        guard let merged = UsageHistory.merge(local: localData, cloud: cloudData) else { return }
        if shouldRestore {
            try? fm.createDirectory(
                at: localUsage.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? Data(contentsOf: localUsage)) != merged { try? merged.write(to: localUsage) }
        }
        if shouldExport {
            try? fm.createDirectory(
                at: cloudUsage.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? Data(contentsOf: cloudUsage)) != merged { try? merged.write(to: cloudUsage) }
        }
    }

    private func importFromCloudIfNewer(decision: SettingsBackupTransferDecision) {
        guard decision.shouldRestore else { return }
        let fm = FileManager.default
        let firstRun = !fm.fileExists(atPath: localFile.path)
        guard
            let cloudDate = (try? fm.attributesOfItem(atPath: cloudFile.path))?[.modificationDate]
                as? Date
        else { return }
        let localDate =
            (try? fm.attributesOfItem(atPath: localFile.path))?[.modificationDate] as? Date
            ?? .distantPast
        guard firstRun || cloudDate > localDate.addingTimeInterval(2) else { return }
        guard let data = try? Data(contentsOf: cloudFile),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            try? fm.startDownloadingUbiquitousItem(at: cloudFile)
            return
        }
        for (key, value) in dict where Self.backedKeys.contains(key) {
            store(for: key).set(value, forKey: key)
        }
        try? data.write(to: localFile)
        HotKey.register()
    }
}
