import CryptoKit
import Foundation

public struct LicenseReceipt: Codable, Equatable, Sendable {
    public let machine: String
    public let label: String
    public let issuedAt: Int64
    public let expiresAt: Int64
    public let keyLast4: String

    public init(
        machine: String, label: String, issuedAt: Int64, expiresAt: Int64, keyLast4: String
    ) {
        self.machine = machine
        self.label = label
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.keyLast4 = keyLast4
    }
}

public protocol LicenseSignatureVerifying {
    func isValidSignature(_ signature: Data, for data: Data) -> Bool
}

public enum LicenseReceiptValidation: Equatable {
    case valid
    case expired
    case invalid
}

public struct LicenseReceiptVerifier {
    public static let signingPublicKeyBase64 = "fUAon12NuznWmJArye1CMLnfozHkyoNQGDaqYziUSSo="

    private let publicKey: any LicenseSignatureVerifying
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        let rawKey = Data(base64Encoded: Self.signingPublicKeyBase64)!
        publicKey = EmbeddedLicensePublicKey(
            key: try! Curve25519.Signing.PublicKey(rawRepresentation: rawKey))
        self.now = now
    }

    public init(publicKey: any LicenseSignatureVerifying, now: @escaping () -> Date = Date.init) {
        self.publicKey = publicKey
        self.now = now
    }

    public func verify(receipt: String, expectedMachine: String) -> Bool {
        validation(receipt: receipt, expectedMachine: expectedMachine) == .valid
    }

    public func validation(receipt: String, expectedMachine: String)
        -> LicenseReceiptValidation
    {
        guard
            let payload = verifiedReceipt(receipt: receipt, expectedMachine: expectedMachine)
        else {
            return .invalid
        }
        return now().timeIntervalSince1970 < Double(payload.expiresAt) ? .valid : .expired
    }

    public func verifiedReceipt(receipt: String, expectedMachine: String) -> LicenseReceipt? {
        let components = receipt.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2,
            let payloadData = Self.base64URLData(String(components[0])),
            let signatureData = Self.base64URLData(String(components[1])),
            publicKey.isValidSignature(signatureData, for: payloadData),
            let payload = try? JSONDecoder().decode(LicenseReceipt.self, from: payloadData),
            payload.machine == expectedMachine
        else {
            return nil
        }
        return payload
    }

    private static func base64URLData(_ value: String) -> Data? {
        guard !value.isEmpty,
            value.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
            })
        else {
            return nil
        }
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        guard remainder != 1 else { return nil }
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

private struct EmbeddedLicensePublicKey: LicenseSignatureVerifying {
    let key: Curve25519.Signing.PublicKey

    func isValidSignature(_ signature: Data, for data: Data) -> Bool {
        key.isValidSignature(signature, for: data)
    }
}
