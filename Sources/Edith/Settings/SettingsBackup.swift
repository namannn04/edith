import Foundation

enum AppData {
    /// The app's fixed data home: ~/Library/Application Support/Edith
    static let supportDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Edith")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// iCloud Drive folder — files here sync natively, no entitlements needed
    /// (CloudKit proper requires a provisioned app, which an ad-hoc build isn't).
    static let cloudDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Edith")

    static var cloudAvailable: Bool {
        FileManager.default.fileExists(
            atPath: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path)
    }
}

/// Mirrors the app's settings (UserDefaults) into Application Support/Edith/
/// settings.json and — when the iCloud toggle is on — into iCloud Drive.
/// Sync model: last writer wins. A newer iCloud copy is imported at launch;
/// afterwards every settings change re-exports, debounced and content-compared
/// so unchanged snapshots never touch mtimes.
@MainActor
final class SettingsBackup: ObservableObject {
    static let shared = SettingsBackup()

    @Published private(set) var musicBackupRunning = false

    /// Every persisted preference the app has. New settings join this list.
    private static let keys = [
        "theme", "tab", "presenterMode", "tabUsageEnabled", "tabMusicEnabled",
        "hotKeyCode", "hotKeyMods", "hotKeyLabel", "musicVolume", "repoPath",
        "icloudBackup", "musicBackup", "lastPaletteTheme",
    ]

    private var debounce: Timer?
    private var localFile: URL { AppData.supportDir.appendingPathComponent("settings.json") }
    private var cloudFile: URL { AppData.cloudDir.appendingPathComponent("settings.json") }

    func start() {
        importFromCloudIfNewer()
        export() // make sure the local mirror exists from day one
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleExport() }
        }
        if UserDefaults.standard.bool(forKey: "musicBackup") {
            backupMusic() // rsync no-ops fast when nothing changed
        }
    }

    /// Copy new/changed music files into iCloud Drive (additive, never deletes).
    func backupMusic() {
        guard !musicBackupRunning, AppData.cloudAvailable,
              FileManager.default.fileExists(atPath: Repo.musicDir.path) else { return }
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
                    UserDefaults.standard.set(
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

    private func scheduleExport() {
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            Task { @MainActor in SettingsBackup.shared.export() }
        }
    }

    private func snapshot() -> Data? {
        var dict: [String: Any] = [:]
        for key in Self.keys {
            if let value = UserDefaults.standard.object(forKey: key) { dict[key] = value }
        }
        return try? JSONSerialization.data(
            withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    func export() {
        guard let data = snapshot() else { return }
        if (try? Data(contentsOf: localFile)) != data {
            try? data.write(to: localFile)
        }
        guard UserDefaults.standard.bool(forKey: "icloudBackup"), AppData.cloudAvailable
        else { return }
        try? FileManager.default.createDirectory(
            at: AppData.cloudDir, withIntermediateDirectories: true)
        if (try? Data(contentsOf: cloudFile)) != data {
            try? data.write(to: cloudFile)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackupAt")
        }
    }

    private func importFromCloudIfNewer() {
        guard UserDefaults.standard.bool(forKey: "icloudBackup") else { return }
        let fm = FileManager.default
        guard let cloudDate = (try? fm.attributesOfItem(atPath: cloudFile.path))?[.modificationDate] as? Date
        else { return }
        let localDate = (try? fm.attributesOfItem(atPath: localFile.path))?[.modificationDate] as? Date
            ?? .distantPast
        guard cloudDate > localDate.addingTimeInterval(2) else { return }
        guard let data = try? Data(contentsOf: cloudFile),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // dataless iCloud placeholder — kick off the download for next launch
            try? fm.startDownloadingUbiquitousItem(at: cloudFile)
            return
        }
        for (key, value) in dict where Self.keys.contains(key) {
            UserDefaults.standard.set(value, forKey: key)
        }
        try? data.write(to: localFile)
        HotKey.register() // an imported shortcut takes effect immediately
    }
}
