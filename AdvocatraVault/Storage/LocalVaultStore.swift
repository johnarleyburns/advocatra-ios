// SPDX-License-Identifier: AGPL-3.0-only
//
// The on-device vault — the authoritative copy, per the advocatra web
// repo's TECHNICAL-DESIGN.md §5 storage-model table ("Vault lives:
// on-device, authoritative; optionally also synced to the cloud"). Plain
// JSON on disk: the manifest's keyEnvelope is already wrapped key
// material (safe at rest without the passphrase), and the snapshot is
// already an AES-GCM envelope (ciphertext), so neither needs a second
// layer of encryption here. Excluded from iCloud backup for the same
// device-only posture as VaultKeychain's stored master key.
import Foundation

public struct LocalVaultStore: Sendable {
    private let directory: URL

    public static let `default` = LocalVaultStore(
        directory: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vault", isDirectory: true)
    )

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excludedDirectory = directory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? excludedDirectory.setResourceValues(resourceValues)
    }

    private var manifestURL: URL { directory.appendingPathComponent("manifest.json") }
    private var snapshotURL: URL { directory.appendingPathComponent("snapshot.json") }

    public func loadManifest() throws -> VaultManifest? {
        guard let data = try readIfExists(manifestURL) else { return nil }
        return try JSONDecoder().decode(VaultManifest.self, from: data)
    }

    public func saveManifest(_ manifest: VaultManifest) throws {
        try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
    }

    public func loadSnapshot() throws -> EncryptedEnvelope? {
        guard let data = try readIfExists(snapshotURL) else { return nil }
        return try JSONDecoder().decode(EncryptedEnvelope.self, from: data)
    }

    public func saveSnapshot(_ envelope: EncryptedEnvelope) throws {
        try JSONEncoder().encode(envelope).write(to: snapshotURL, options: .atomic)
    }

    private func readIfExists(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }
}
