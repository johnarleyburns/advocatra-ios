// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/crypto/src/envelope.test.ts's structure.
import CryptoKit
import Foundation
import Testing

@testable import AdvocatraVault

@Suite struct EnvelopeTests {
    @Test func decryptsWhatItEncrypted() throws {
        let key = SymmetricKey(size: .bits256)
        let aad = EnvelopeAad(vaultId: "vault-1", purpose: .records, schemaVersion: 1)
        let plaintext = Data("hello vault".utf8)
        let envelope = try Envelope.encrypt(plaintext: plaintext, key: key, aad: aad)
        let decrypted = try Envelope.decrypt(envelope, key: key, expectedAad: aad)
        #expect(decrypted == plaintext)
    }

    @Test func rejectsAMismatchedAad() throws {
        let key = SymmetricKey(size: .bits256)
        let envelope = try Envelope.encrypt(
            plaintext: Data("hello".utf8),
            key: key,
            aad: EnvelopeAad(vaultId: "vault-1", purpose: .records, schemaVersion: 1)
        )
        #expect(throws: EnvelopeError.self) {
            try Envelope.decrypt(
                envelope,
                key: key,
                expectedAad: EnvelopeAad(vaultId: "vault-2", purpose: .records, schemaVersion: 1)
            )
        }
    }

    @Test func rejectsTheWrongKey() throws {
        let envelope = try Envelope.encrypt(
            plaintext: Data("hello".utf8),
            key: SymmetricKey(size: .bits256),
            aad: EnvelopeAad(vaultId: "vault-1", purpose: .records, schemaVersion: 1)
        )
        #expect(throws: (any Error).self) {
            try Envelope.decrypt(
                envelope,
                key: SymmetricKey(size: .bits256),
                expectedAad: EnvelopeAad(vaultId: "vault-1", purpose: .records, schemaVersion: 1)
            )
        }
    }
}
