// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/vault/src/manifest.ts's VaultManifestSchema/
// KeyEnvelopeSchema field-for-field, so the JSON this produces is
// interchangeable with the web client's (and any other platform's).

public struct PassphraseKeyEnvelope: Codable, Sendable, Equatable {
    public let kdf: String
    public let iterations: Int
    public let saltBase64: String
    public let wrappedMasterKeyBase64: String

    public init(kdf: String, iterations: Int, saltBase64: String, wrappedMasterKeyBase64: String) {
        self.kdf = kdf
        self.iterations = iterations
        self.saltBase64 = saltBase64
        self.wrappedMasterKeyBase64 = wrappedMasterKeyBase64
    }
}

public struct RecoveryKeyEnvelope: Codable, Sendable, Equatable {
    public let wrappedMasterKeyBase64: String

    public init(wrappedMasterKeyBase64: String) {
        self.wrappedMasterKeyBase64 = wrappedMasterKeyBase64
    }
}

/// The vault master key, wrapped two independent ways — either secret
/// alone unlocks the vault; losing both makes it permanently
/// unrecoverable, by design.
public struct KeyEnvelope: Codable, Sendable, Equatable {
    public let version: Int
    public let passphrase: PassphraseKeyEnvelope
    public let recovery: RecoveryKeyEnvelope

    public init(version: Int, passphrase: PassphraseKeyEnvelope, recovery: RecoveryKeyEnvelope) {
        self.version = version
        self.passphrase = passphrase
        self.recovery = recovery
    }
}

public struct VaultManifest: Codable, Sendable, Equatable {
    public let formatVersion: Int
    public let vaultId: String
    public let appVersion: String
    public let schemaVersion: Int
    public let encryptionAlgorithm: String
    public let createdAt: String
    public let keyEnvelope: KeyEnvelope
    /// Absent for a vault that has never been synced to the cloud.
    public let lastSyncedRevision: Int?

    public init(
        formatVersion: Int = 1,
        vaultId: String,
        appVersion: String,
        schemaVersion: Int = 1,
        encryptionAlgorithm: String = "AES-256-GCM",
        createdAt: String,
        keyEnvelope: KeyEnvelope,
        lastSyncedRevision: Int? = nil
    ) {
        self.formatVersion = formatVersion
        self.vaultId = vaultId
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
        self.encryptionAlgorithm = encryptionAlgorithm
        self.createdAt = createdAt
        self.keyEnvelope = keyEnvelope
        self.lastSyncedRevision = lastSyncedRevision
    }
}
