import Foundation
import Testing
@testable import EdithHelper
@testable import EdithKit

@Suite struct SettingsBackupTests {
    @Test func everyAppStoragePreferenceIsBackedUpOrDeviceLocal() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: nil)
        let regex = try NSRegularExpression(pattern: #"@AppStorage\("([^"]+)""#)
        var keys = Set<String>()
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                let source = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            let range = NSRange(source.startIndex..., in: source)
            for match in regex.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                keys.insert(String(source[keyRange]))
            }
        }
        let covered = Set(SettingsBackup.backedKeys).union(SettingsBackup.deviceLocalKeys)
        #expect(keys.subtracting(covered).isEmpty)
        #expect(
            keys.intersection(SettingsBackup.backedKeys).isSubset(of: SettingsBackup.sharedKeys))
    }

    @Test func configurableNonAppStoragePreferencesAreBackedUp() {
        let expected: Set<String> = [
            "micHotKeyCode", "micHotKeyMods", "micHotKeyLabel", "notchAudioMixerEnabled",
        ]
        #expect(expected.isSubset(of: Set(SettingsBackup.backedKeys)))
        #expect(expected.isSubset(of: SettingsBackup.sharedKeys))
    }

    @Test func transferDecisionMatrix() {
        for dataClass in SettingsBackupDataClass.allCases {
            for masterEnabled in [false, true] {
                for subToggleEnabled in [false, true] {
                    for extensionEnabled in [false, true] {
                        let decision = settingsBackupTransferDecision(
                            for: dataClass,
                            masterEnabled: masterEnabled,
                            subToggleEnabled: subToggleEnabled,
                            extensionEnabled: extensionEnabled)
                        let shouldRestore = masterEnabled && subToggleEnabled
                        #expect(decision.shouldRestore == shouldRestore)
                        #expect(
                            decision.shouldExport == (shouldRestore && extensionEnabled))
                    }
                }
            }
        }
    }

    @Test func enableTimeRestoreDecisionMatrix() {
        let extensionDataClasses: [SettingsBackupDataClass] = [
            .usage, .limits, .music, .clipboard,
        ]
        for dataClass in extensionDataClasses {
            for cloudDataExists in [false, true] {
                for masterEnabled in [false, true] {
                    #expect(
                        settingsBackupEnableRestoreDecision(
                            for: dataClass, cloudDataExists: cloudDataExists,
                            masterEnabled: masterEnabled) == cloudDataExists)
                }
            }
        }
    }

    @Test func restoredPathValidationMatrix() {
        let home = URL(fileURLWithPath: "/Users/example")
        let cases: [(String, RestoredPathVerdict)] = [
            ("/", .keep),
            ("/Library/Application Support/Edith", .keep),
            ("/Users/example", .keep),
            ("/Users/example/Music", .keep),
            ("/Volumes/X", .drop),
            ("/Volumes/X/Music", .drop),
        ]
        for (path, expected) in cases {
            #expect(RestoredPathValidation.verdict(for: path, homeDirectory: home) == expected)
        }
    }
}
