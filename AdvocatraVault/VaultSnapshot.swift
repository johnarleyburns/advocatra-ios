// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/vault/src/snapshot.ts's decryptVaultSnapshot: derive
// the "records" purpose data key from the master key, decrypt the
// envelope, and decode just enough of the JSON to report record counts.
import Foundation

/// The records schema version bound into the envelope's AAD — must match
/// RECORDS_SCHEMA_VERSION in packages/vault/src/snapshot.ts.
public let recordsSchemaVersion = 1

public enum VaultSnapshot {
    public static func decryptRecordsSummary(
        envelope: EncryptedEnvelope,
        masterKeyMaterial: Data,
        vaultId: String
    ) throws -> VaultRecordsSummary {
        let key = DataKey.derive(masterKeyMaterial: masterKeyMaterial, purpose: .records)
        let expectedAad = EnvelopeAad(vaultId: vaultId, purpose: .records, schemaVersion: recordsSchemaVersion)
        let plaintext = try Envelope.decrypt(envelope, key: key, expectedAad: expectedAad)
        return try JSONDecoder().decode(VaultRecordsSummary.self, from: plaintext)
    }
}
