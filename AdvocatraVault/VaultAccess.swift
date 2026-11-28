// SPDX-License-Identifier: AGPL-3.0-only
//
// Create and unlock a vault via passphrase or recovery code. Mirrors
// packages/vault/src/vault-access.ts's createVault/unlockVaultWith*
// exactly (same two-independent-KEKs mechanism), independently
// implemented in Swift — verified byte-identical where cross-platform
// interop matters (the KEK derivation and the wrap step) against the
// real web implementation, not just internally consistent. See
// AdvocatraVaultTests/CrossPlatformFixtureTests.swift.
import CryptoKit
import Foundation

public enum VaultUnlockError: Error {
    case incorrectSecret
}

public struct CreateVaultResult: Sendable {
    public let manifest: VaultManifest
    public let masterKeyMaterial: Data
    /// Shown to the user exactly once, here. Never stored, never uploaded.
    public let recoveryCode: String
}

public enum VaultAccess {
    public static let defaultPbkdf2Iterations = 600_000
    private static let passphraseSaltLength = 16

    /// Create a brand-new vault: a random master key, wrapped under both a passphrase and a recovery code.
    public static func createVault(
        vaultId: String,
        appVersion: String,
        createdAt: String,
        passphrase: String
    ) throws -> CreateVaultResult {
        let masterKeyMaterial = VaultKey.generateMasterKeyMaterial()

        let salt = randomBytes(passphraseSaltLength)
        let passphraseKek = derivePassphraseKek(
            passphrase: passphrase,
            salt: salt,
            iterations: defaultPbkdf2Iterations
        )
        let wrappedByPassphrase = try VaultKey.wrap(material: masterKeyMaterial, kek: passphraseKek)

        let recoveryCode = RecoveryCode.generate()
        let recoveryKek = deriveRecoveryKek(recoveryCode: recoveryCode)
        let wrappedByRecovery = try VaultKey.wrap(material: masterKeyMaterial, kek: recoveryKek)

        let keyEnvelope = KeyEnvelope(
            version: 1,
            passphrase: PassphraseKeyEnvelope(
                kdf: "PBKDF2-SHA256",
                iterations: defaultPbkdf2Iterations,
                saltBase64: salt.base64EncodedString(),
                wrappedMasterKeyBase64: wrappedByPassphrase.base64EncodedString()
            ),
            recovery: RecoveryKeyEnvelope(wrappedMasterKeyBase64: wrappedByRecovery.base64EncodedString())
        )

        let manifest = VaultManifest(
            vaultId: vaultId,
            appVersion: appVersion,
            createdAt: createdAt,
            keyEnvelope: keyEnvelope
        )

        return CreateVaultResult(
            manifest: manifest,
            masterKeyMaterial: masterKeyMaterial,
            recoveryCode: recoveryCode
        )
    }

    /// Unlock a vault with its passphrase, returning the vault master key material.
    public static func unlockWithPassphrase(manifest: VaultManifest, passphrase: String) throws -> Data {
        let envelope = manifest.keyEnvelope.passphrase
        guard let salt = Data(base64Encoded: envelope.saltBase64) else {
            throw VaultUnlockError.incorrectSecret
        }
        let kek = derivePassphraseKek(passphrase: passphrase, salt: salt, iterations: envelope.iterations)
        return try unwrap(envelope.wrappedMasterKeyBase64, kek: kek)
    }

    /// Unlock a vault with its recovery code, returning the vault master key material.
    public static func unlockWithRecoveryCode(manifest: VaultManifest, recoveryCode: String) throws -> Data {
        let kek = deriveRecoveryKek(recoveryCode: recoveryCode)
        return try unwrap(manifest.keyEnvelope.recovery.wrappedMasterKeyBase64, kek: kek)
    }

    private static func unwrap(_ wrappedBase64: String, kek: SymmetricKey) throws -> Data {
        guard let wrapped = Data(base64Encoded: wrappedBase64) else {
            throw VaultUnlockError.incorrectSecret
        }
        do {
            return try VaultKey.unwrap(wrapped: wrapped, kek: kek)
        } catch {
            throw VaultUnlockError.incorrectSecret
        }
    }

    private static func derivePassphraseKek(passphrase: String, salt: Data, iterations: Int) -> SymmetricKey {
        let bits = PBKDF2.deriveBits(
            password: Data(passphrase.utf8),
            salt: salt,
            iterations: iterations,
            byteCount: 32
        )
        return SymmetricKey(data: bits)
    }

    private static func deriveRecoveryKek(recoveryCode: String) -> SymmetricKey {
        let normalized = recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let inputKey = SymmetricKey(data: Data(normalized.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(),
            info: Data("advocatra/vault/recovery/v1".utf8),
            outputByteCount: 32
        )
    }

    private static func randomBytes(_ count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }
}
