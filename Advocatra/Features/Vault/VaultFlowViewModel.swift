// SPDX-License-Identifier: AGPL-3.0-only
//
// Local-first, per advocatra's TECHNICAL-DESIGN.md §5: "Vault lives:
// on-device, authoritative; optionally also synced to the cloud." The
// default path (bootstrap/createVault/unlockVault) never makes a
// network call. Cloud sync is a separate, explicit, optional action
// (enableCloudSync) reachable from the connected screen, not a gate in
// front of the vault.
//
// Business logic lives here, not in the views, so it stays testable in
// principle — though the real Keychain/filesystem calls mean most of
// this is only verified by the owner on a real device, not by
// AdvocatraVaultTests (which exercises AdvocatraVault's own logic
// against fakes/temp directories, not this view model).
import AdvocatraVault
import Foundation
import Observation

@MainActor
@Observable
final class VaultFlowViewModel {
    enum Stage: Equatable {
        case bootstrapping
        case createVault
        case locked
        case showRecoveryCode(String)
        case connected(VaultRecordsSummary)
    }

    private static let keychainAccount = "local-vault"

    var stage: Stage = .bootstrapping
    var passphrase = ""
    var passphraseConfirmation = ""
    var recoveryCodeInput = ""
    var errorMessage: String?
    var isLoading = false

    // Cloud sync fields — only used by enableCloudSync(), an optional
    // action separate from the local vault above.
    var tenantHost = ""
    var email = ""
    var password = ""
    var totpCode = ""
    var cloudSyncResultMessage: String?

    private let localStore: LocalVaultStore
    private var localManifest: VaultManifest?
    private var masterKeyMaterial: Data?

    init(localStore: LocalVaultStore = .default) {
        self.localStore = localStore
    }

    /// Checks for an on-device vault and, if one exists, tries to unlock it
    /// via the Keychain-stored key (prompting Face ID/Touch ID/passcode) before
    /// falling back to manual passphrase/recovery-code entry. No network call.
    func bootstrap() async {
        do {
            guard let manifest = try localStore.loadManifest() else {
                stage = .createVault
                return
            }
            localManifest = manifest
            if let key = try? VaultKeychain.load(account: Self.keychainAccount) {
                masterKeyMaterial = key
                await loadConnectedSummary(vaultId: manifest.vaultId)
            } else {
                stage = .locked
            }
        } catch {
            errorMessage = "Could not read the local vault: \(error)"
            stage = .locked
        }
    }

    func createVault() async {
        guard !passphrase.isEmpty, passphrase == passphraseConfirmation else {
            errorMessage = "Passphrases do not match."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try VaultAccess.createVault(
                vaultId: UUID().uuidString,
                appVersion: "0.1.0",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                passphrase: passphrase
            )
            try localStore.saveManifest(result.manifest)
            localManifest = result.manifest
            masterKeyMaterial = result.masterKeyMaterial
            try? VaultKeychain.store(masterKeyMaterial: result.masterKeyMaterial, account: Self.keychainAccount)
            stage = .showRecoveryCode(result.recoveryCode)
        } catch {
            errorMessage = "Could not create the vault: \(error)"
        }
    }

    func confirmRecoveryCodeSaved() async {
        guard let manifest = localManifest else { return }
        await loadConnectedSummary(vaultId: manifest.vaultId)
    }

    func unlockVault() async {
        guard let manifest = localManifest else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let material: Data =
                if !recoveryCodeInput.isEmpty {
                    try VaultAccess.unlockWithRecoveryCode(manifest: manifest, recoveryCode: recoveryCodeInput)
                } else {
                    try VaultAccess.unlockWithPassphrase(manifest: manifest, passphrase: passphrase)
                }
            masterKeyMaterial = material
            try? VaultKeychain.store(masterKeyMaterial: material, account: Self.keychainAccount)
            await loadConnectedSummary(vaultId: manifest.vaultId)
        } catch {
            errorMessage = "Incorrect passphrase or recovery code."
        }
    }

    private func loadConnectedSummary(vaultId: String) async {
        guard let masterKeyMaterial else { return }
        do {
            let summary: VaultRecordsSummary =
                if let snapshot = try localStore.loadSnapshot() {
                    try VaultSnapshot.decryptRecordsSummary(
                        envelope: snapshot,
                        masterKeyMaterial: masterKeyMaterial,
                        vaultId: vaultId
                    )
                } else {
                    .empty
                }
            stage = .connected(summary)
        } catch {
            errorMessage = "Vault unlocked, but couldn't read its contents: \(error)"
        }
    }

    /// Optional, explicit, separate from the local vault above: signs into
    /// the cloud and seeds its manifest from the local one if the account
    /// doesn't already have a vault. Never pulls or merges an existing
    /// cloud vault — that's still separate, not-yet-started work (no
    /// automatic conflict resolution, matching TECHNICAL-DESIGN.md §7).
    func enableCloudSync() async {
        guard let localManifest else { return }
        errorMessage = nil
        cloudSyncResultMessage = nil
        isLoading = true
        defer { isLoading = false }
        let client = AdvocatraCloudClient(tenantHost: tenantHost)
        do {
            try await client.login(email: email, password: password, totpCode: totpCode)
            let session = try await client.fetchSession()
            if try await client.fetchManifest() != nil {
                cloudSyncResultMessage = """
                    This account already has a cloud vault. Pulling an existing cloud vault \
                    onto this device isn't supported yet.
                    """
                return
            }
            let manifestToUpload = VaultManifest(
                vaultId: session.tenantId,
                appVersion: localManifest.appVersion,
                createdAt: localManifest.createdAt,
                keyEnvelope: localManifest.keyEnvelope,
                lastSyncedRevision: localManifest.lastSyncedRevision
            )
            let json = String(decoding: try JSONEncoder().encode(manifestToUpload), as: UTF8.self)
            try await client.putManifest(json: json)
            cloudSyncResultMessage = "Cloud sync enabled. Your vault key is backed up — full data sync is coming soon."
        } catch {
            errorMessage = "Could not enable cloud sync: \(error)"
        }
    }
}
