// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/crypto/src/envelope.ts: a versioned AES-256-GCM
// envelope with AAD binding ({vaultId, purpose, schemaVersion}),
// canonicalized as the exact same JSON key order and escaping so the
// authenticated bytes match the web implementation's byte for byte.
import CryptoKit
import Foundation

public enum EnvelopePurpose: String, Codable, Sendable {
    case records
    case documents
}

public struct EnvelopeAad: Codable, Sendable, Equatable {
    public let vaultId: String
    public let purpose: EnvelopePurpose
    public let schemaVersion: Int

    public init(vaultId: String, purpose: EnvelopePurpose, schemaVersion: Int) {
        self.vaultId = vaultId
        self.purpose = purpose
        self.schemaVersion = schemaVersion
    }
}

public struct EncryptedEnvelope: Codable, Sendable, Equatable {
    public let version: Int
    public let algorithm: String
    public let iv: String
    public let ciphertext: String
    public let aad: EnvelopeAad

    public init(
        version: Int = 1,
        algorithm: String = "AES-256-GCM",
        iv: String,
        ciphertext: String,
        aad: EnvelopeAad
    ) {
        self.version = version
        self.algorithm = algorithm
        self.iv = iv
        self.ciphertext = ciphertext
        self.aad = aad
    }
}

public enum EnvelopeError: Error {
    case aadMismatch
    case malformedEnvelope
}

enum Envelope {
    private static let tagLength = 16

    private static func jsonEscape(_ string: String) -> String {
        var escaped = ""
        for character in string {
            switch character {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    /// Stable key order {vaultId, purpose, schemaVersion} — must match
    /// envelope.ts's `canonicalAad` exactly, since this is authenticated
    /// as AES-GCM additional data.
    private static func canonicalAad(_ aad: EnvelopeAad) -> Data {
        let json =
            "{\"vaultId\":\"\(jsonEscape(aad.vaultId))\",\"purpose\":\"\(aad.purpose.rawValue)\",\"schemaVersion\":\(aad.schemaVersion)}"
        return Data(json.utf8)
    }

    static func encrypt(plaintext: Data, key: SymmetricKey, aad: EnvelopeAad) throws -> EncryptedEnvelope {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: canonicalAad(aad))
        return EncryptedEnvelope(
            iv: Data(nonce).base64EncodedString(),
            ciphertext: (sealed.ciphertext + sealed.tag).base64EncodedString(),
            aad: aad
        )
    }

    static func decrypt(_ envelope: EncryptedEnvelope, key: SymmetricKey, expectedAad: EnvelopeAad) throws -> Data {
        guard envelope.aad == expectedAad else { throw EnvelopeError.aadMismatch }
        guard let ivData = Data(base64Encoded: envelope.iv),
            let combined = Data(base64Encoded: envelope.ciphertext),
            combined.count >= tagLength
        else {
            throw EnvelopeError.malformedEnvelope
        }
        let nonce = try AES.GCM.Nonce(data: ivData)
        let ciphertext = combined.prefix(combined.count - tagLength)
        let tag = combined.suffix(tagLength)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key, authenticating: canonicalAad(expectedAad))
    }
}
