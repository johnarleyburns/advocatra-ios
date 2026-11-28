// SPDX-License-Identifier: AGPL-3.0-only
//
// End-to-end against fakes (ManifestSource/SnapshotSource), never a real
// network call — mirrors advocatra-mcp's vault-session.test.ts /
// unlock.test.ts style. Proves createVault -> manifest JSON -> unlock ->
// fetch -> decrypt works as one real sequence, not just each step in
// isolation.
import Foundation
import Testing

@testable import AdvocatraVault

private struct FakeManifestSource: ManifestSource {
    let manifestJson: String?
    func fetchManifest() async throws -> String? { manifestJson }
}

private struct FakeSnapshotSource: SnapshotSource {
    let download: SnapshotDownload
    func fetchSnapshot() async throws -> SnapshotDownload { download }
}

@Suite struct VaultUnlockFlowTests {
    @Test func fullSequenceCreateEncodeUnlockFetchDecrypt() async throws {
        let created = try VaultAccess.createVault(
            vaultId: "vault-1",
            appVersion: "0.1.0",
            createdAt: "2027-01-01T00:00:00Z",
            passphrase: "correct horse battery staple"
        )
        let manifestJson = String(decoding: try JSONEncoder().encode(created.manifest), as: UTF8.self)

        // A different client (e.g. after re-login) only has the manifest JSON off the wire.
        let fetchedManifest = try JSONDecoder().decode(VaultManifest.self, from: Data(manifestJson.utf8))
        let unlocked = try VaultAccess.unlockWithPassphrase(
            manifest: fetchedManifest,
            passphrase: "correct horse battery staple"
        )
        #expect(unlocked == created.masterKeyMaterial)

        let records = #"{"taxpayers":[{"id":"t1"}],"matters":[],"documents":[]}"#
        let key = DataKey.derive(masterKeyMaterial: unlocked, purpose: .records)
        let envelope = try Envelope.encrypt(
            plaintext: Data(records.utf8),
            key: key,
            aad: EnvelopeAad(vaultId: "vault-1", purpose: .records, schemaVersion: recordsSchemaVersion)
        )
        let snapshotSource = FakeSnapshotSource(download: SnapshotDownload(revision: 1, snapshot: envelope))
        let download = try await snapshotSource.fetchSnapshot()
        let summary = try VaultSnapshot.decryptRecordsSummary(
            envelope: download.snapshot!,
            masterKeyMaterial: unlocked,
            vaultId: "vault-1"
        )
        #expect(summary.taxpayerCount == 1)
    }

    @Test func noManifestMeansNoVaultYet() async throws {
        let source = FakeManifestSource(manifestJson: nil)
        #expect(try await source.fetchManifest() == nil)
    }

    @Test func emptySnapshotSummaryIsAllZeros() throws {
        let summary = VaultRecordsSummary.empty
        #expect(summary.taxpayerCount == 0)
        #expect(summary.matterCount == 0)
    }
}
