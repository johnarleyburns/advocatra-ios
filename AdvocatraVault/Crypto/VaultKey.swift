// SPDX-License-Identifier: AGPL-3.0-only
//
// Generate, wrap and unwrap the vault master key. Wrapping is AES-256-GCM
// (`iv || ciphertext+tag`), not AES-KW -- switched for cross-platform
// interop since CryptoKit has no AES-KW primitive; see
// TECHNICAL-DESIGN.md §5 and packages/crypto/src/vault-key.ts, which this
// mirrors exactly (independently implemented, verified byte-identical —
// see AdvocatraVaultTests/CrossPlatformFixtureTests.swift).
import CryptoKit
import Foundation

enum VaultKeyError: Error {
    case malformedWrappedKey
}

enum VaultKey {
    private static let ivLength = 12
    private static let tagLength = 16

    static func generateMasterKeyMaterial() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    static func wrap(material: Data, kek: SymmetricKey) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(material, using: kek, nonce: nonce)
        return Data(nonce) + sealed.ciphertext + sealed.tag
    }

    static func unwrap(wrapped: Data, kek: SymmetricKey) throws -> Data {
        guard wrapped.count > ivLength + tagLength else { throw VaultKeyError.malformedWrappedKey }
        let iv = wrapped.prefix(ivLength)
        let rest = wrapped.dropFirst(ivLength)
        let ciphertext = rest.prefix(rest.count - tagLength)
        let tag = rest.suffix(tagLength)
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: kek)
    }
}
