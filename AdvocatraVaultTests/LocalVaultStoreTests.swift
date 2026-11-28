// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing

@testable import AdvocatraVault

@Suite struct LocalVaultStoreTests {
    private func makeStore() -> LocalVaultStore {
        LocalVaultStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    @Test func manifestIsNilWhenNothingHasBeenSaved() throws {
        #expect(try makeStore().loadManifest() == nil)
    }

    @Test func manifestRoundTrips() throws {
        let store = makeStore()
        let created = try VaultAccess.createVault(
            vaultId: "local-1",
            appVersion: "0.1.0",
            createdAt: "2027-01-01T00:00:00Z",
            passphrase: "correct horse battery staple"
        )
        try store.saveManifest(created.manifest)
        #expect(try store.loadManifest() == created.manifest)
    }

    @Test func savingAManifestTwiceReplacesItWholesale() throws {
        let store = makeStore()
        let first = try VaultAccess.createVault(
            vaultId: "local-1",
            appVersion: "0.1.0",
            createdAt: "2027-01-01T00:00:00Z",
            passphrase: "first passphrase"
        )
        let second = try VaultAccess.createVault(
            vaultId: "local-2",
            appVersion: "0.1.0",
            createdAt: "2027-01-02T00:00:00Z",
            passphrase: "second passphrase"
        )
        try store.saveManifest(first.manifest)
        try store.saveManifest(second.manifest)
        #expect(try store.loadManifest() == second.manifest)
    }

    @Test func snapshotIsNilWhenNothingHasBeenSaved() throws {
        #expect(try makeStore().loadSnapshot() == nil)
    }

    @Test func snapshotRoundTrips() throws {
        let store = makeStore()
        let envelope = EncryptedEnvelope(
            iv: "AAAAAAAAAAAAAAAA",
            ciphertext: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            aad: EnvelopeAad(vaultId: "local-1", purpose: .records, schemaVersion: 1)
        )
        try store.saveSnapshot(envelope)
        #expect(try store.loadSnapshot() == envelope)
    }

    @Test func twoStoresWithDifferentDirectoriesDoNotSeeEachOthersData() throws {
        let storeA = makeStore()
        let storeB = makeStore()
        let created = try VaultAccess.createVault(
            vaultId: "local-1",
            appVersion: "0.1.0",
            createdAt: "2027-01-01T00:00:00Z",
            passphrase: "correct horse battery staple"
        )
        try storeA.saveManifest(created.manifest)
        #expect(try storeB.loadManifest() == nil)
    }
}
