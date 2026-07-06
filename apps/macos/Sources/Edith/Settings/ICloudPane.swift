import AppKit
import EdithKit
import SwiftUI

struct ICloudPane: View {
    @AppStorage("icloudBackup", store: SharedDefaults.store) private var icloudBackup = false
    @AppStorage("lastBackupAt", store: SharedDefaults.store) private var lastBackupAt = 0.0
    @AppStorage("backupSettings", store: SharedDefaults.store) private var backupSettings = true
    @AppStorage("backupUsage", store: SharedDefaults.store) private var backupUsage = true
    @AppStorage("backupLimits", store: SharedDefaults.store) private var backupLimits = true
    @AppStorage("musicBackup", store: SharedDefaults.store) private var musicBackup = false
    @AppStorage("lastMusicBackupAt", store: SharedDefaults.store) private var lastMusicBackupAt =
        0.0
    @AppStorage("clipboardBackup", store: SharedDefaults.store) private var clipboardBackup = false
    @AppStorage("lastClipboardBackupAt", store: SharedDefaults.store)
    private var lastClipboardBackupAt = 0.0

    private var cloudAvailable: Bool { AppData.cloudAvailable }

    var body: some View {
        Form {
            Section {
                HStack {
                    Toggle("Back up to iCloud", isOn: $icloudBackup)
                        .pointerCursor()
                        .disabled(!cloudAvailable)
                    InfoDot(
                        "Keeps your data in iCloud Drive so a reinstall or another Mac can restore it. Newest copy wins - it's a backup, not a live sync."
                    )
                }
                Text(backupSubtitle).font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("iCloud backup")
            } footer: {
                if !cloudAvailable {
                    Text("iCloud Drive is not available on this Mac.")
                }
            }

            Section {
                Toggle("Settings", isOn: $backupSettings)
                    .pointerCursor()
                    .disabled(!icloudBackup)
                Toggle("Usage data", isOn: $backupUsage)
                    .pointerCursor()
                    .disabled(!icloudBackup)
                Toggle("Session history", isOn: $backupLimits)
                    .pointerCursor()
                    .disabled(!icloudBackup)
            } header: {
                Text("App data")
            }

            Section {
                Toggle("Music folder", isOn: $musicBackup)
                    .pointerCursor()
                    .disabled(!cloudAvailable)
                Text(musicSubtitle).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Toggle("Clipboard history", isOn: $clipboardBackup)
                        .pointerCursor()
                        .disabled(!cloudAvailable)
                    InfoDot(
                        "Text history only, items up to 1 MB each - larger copies stay on this Mac."
                    )
                }
                Text(clipboardSubtitle).font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Extensions")
            }

            Section {
                LabeledContent("App data folder") {
                    Button("Open") {
                        NSWorkspace.shared.open(AppData.supportDir)
                    }
                    .pointerCursor()
                }
                if cloudAvailable {
                    LabeledContent("iCloud folder") {
                        Button("Open") {
                            try? FileManager.default.createDirectory(
                                at: AppData.cloudDir, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(AppData.cloudDir)
                        }
                        .pointerCursor()
                    }
                }
            } header: {
                Text("On disk")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("iCloud")
    }

    private var backupSubtitle: String {
        if !cloudAvailable { return "iCloud Drive is not available on this Mac" }
        if !icloudBackup { return "Syncs via iCloud Drive; newest copy wins across Macs" }
        if lastBackupAt > 0 {
            let at = Date(timeIntervalSince1970: lastBackupAt)
            return "Backed up \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Waiting for first backup…"
    }

    private var musicSubtitle: String {
        if !cloudAvailable { return "iCloud Drive is not available on this Mac" }
        if musicBackup, lastMusicBackupAt > 0 {
            let at = Date(timeIntervalSince1970: lastMusicBackupAt)
            return "Backed up \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Backs up your local music folder"
    }

    private var clipboardSubtitle: String {
        if !cloudAvailable { return "iCloud Drive is not available on this Mac" }
        if clipboardBackup, lastClipboardBackupAt > 0 {
            let at = Date(timeIntervalSince1970: lastClipboardBackupAt)
            return "Backed up \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Restores clipboard history on reinstall"
    }
}
