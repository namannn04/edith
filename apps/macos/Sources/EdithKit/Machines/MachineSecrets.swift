import Foundation
import Security

public enum MachineSecretKind: String, Sendable {
    case password
    case passphrase
}

public enum MachineSecrets {
    public static let service = "com.pulkit.edith.machines"

    public static func account(machineID: UUID, kind: MachineSecretKind) -> String {
        "\(machineID.uuidString).\(kind.rawValue)"
    }

    public static func set(_ secret: String, machineID: UUID, kind: MachineSecretKind) {
        let name = account(machineID: machineID, kind: kind)
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "Edith Machines"
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    public static func get(machineID: UUID, kind: MachineSecretKind) -> String? {
        get(account: account(machineID: machineID, kind: kind))
    }

    public static func get(account name: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(machineID: UUID, kind: MachineSecretKind) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(machineID: machineID, kind: kind),
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func deleteAll(machineID: UUID) {
        delete(machineID: machineID, kind: .password)
        delete(machineID: machineID, kind: .passphrase)
    }
}
