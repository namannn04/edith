import Foundation

public enum RetiredLicenseCleanup {
    static let files = [
        "license-key", "license-receipt", "access-token", "refresh-credential",
        "entitlement", "trusted-time", "device-id", "device-key",
    ]

    static let defaultsKeys = ["licenseActivated", "licenseLabel", "licenseName"]

    public static func run(
        directory: URL = AppData.supportDir, defaults: UserDefaults = SharedDefaults.store
    ) {
        for file in files {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
        for key in defaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
