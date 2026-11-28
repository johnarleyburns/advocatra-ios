// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/vault/src/vault-access.test.ts's structure.
import Foundation
import Testing

@testable import AdvocatraVault

@Suite struct VaultAccessTests {
    private func makeVault(passphrase: String = "correct horse battery staple") throws -> CreateVaultResult {
        try VaultAccess.createVault(
            vaultId: "vault-1",
            appVersion: "0.1.0",
            createdAt: "2027-01-01T00:00:00Z",
            passphrase: passphrase
        )
    }

    @Test func manifestKeyEnvelopeRoundTripsViaThePassphrase() throws {
        let result = try makeVault()
        let unlocked = try VaultAccess.unlockWithPassphrase(
            manifest: result.manifest,
            passphrase: "correct horse battery staple"
        )
        #expect(unlocked == result.masterKeyMaterial)
    }

    @Test func sameMasterKeyAlsoUnlocksViaTheRecoveryCode() throws {
        let result = try makeVault()
        let unlocked = try VaultAccess.unlockWithRecoveryCode(
            manifest: result.manifest,
            recoveryCode: result.recoveryCode
        )
        #expect(unlocked == result.masterKeyMaterial)
    }

    @Test func generatesAFreshRecoveryCodeAndMasterKeyOnEveryCall() throws {
        let a = try makeVault()
        let b = try makeVault()
        #expect(a.recoveryCode != b.recoveryCode)
        #expect(a.masterKeyMaterial != b.masterKeyMaterial)
    }

    @Test func carriesTheVaultIdAndDefaultsIntoTheManifest() throws {
        let result = try makeVault()
        #expect(result.manifest.vaultId == "vault-1")
        #expect(result.manifest.keyEnvelope.passphrase.kdf == "PBKDF2-SHA256")
        #expect(result.manifest.keyEnvelope.passphrase.iterations == VaultAccess.defaultPbkdf2Iterations)
    }

    @Test func rejectsTheWrongPassphrase() throws {
        let result = try makeVault()
        #expect(throws: VaultUnlockError.self) {
            try VaultAccess.unlockWithPassphrase(manifest: result.manifest, passphrase: "wrong passphrase entirely")
        }
    }

    @Test func rejectsADifferentRecoveryCode() throws {
        let result = try makeVault()
        #expect(throws: VaultUnlockError.self) {
            try VaultAccess.unlockWithRecoveryCode(
                manifest: result.manifest,
                recoveryCode: "0000-0000-0000-0000-0000"
            )
        }
    }

    @Test func losingThePassphraseDoesNotAffectRecoveryCodeUnlock() throws {
        let result = try makeVault()
        let unlocked = try VaultAccess.unlockWithRecoveryCode(
            manifest: result.manifest,
            recoveryCode: result.recoveryCode
        )
        #expect(unlocked == result.masterKeyMaterial)
    }
}
