// SPDX-License-Identifier: AGPL-3.0-only
//
// Drives sign-in -> create-or-unlock vault -> connected. Read-only: this
// never uploads a snapshot or acquires the editing lease (that's
// separate, not-yet-started work — see TECHNICAL-DESIGN.md's milestone
// order). Business logic lives here, not in the views, so it stays
// testable in principle — though the real network/Keychain calls mean
// most of this is only verified by the owner on a real device, not by
// AdvocatraVaultTests (which exercises AdvocatraVault's own logic against
// fakes, not this view model).
import AdvocatraVault
import Foundation
import Observation

@MainActor
@Observable
final class VaultFlowViewModel {
    enum Stage: Equatable {
        case signIn
        case createVault
        case unlockVault
        case showRecoveryCode(String)
        case connected(VaultRecordsSummary)
    }

    var stage: Stage = .signIn
    var tenantHost = ""
    var email = ""
    var password = ""
    var totpCode = ""
    var passphrase = ""
    var passphraseConfirmation = ""
    var recoveryCodeInput = ""
    var errorMessage: String?
    var isLoading = false

    private var cloud: AdvocatraCloudClient?
    private var vaultId: String?
    private var pendingManifest: VaultManifest?
    private var masterKeyMaterial: Data?

    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        let client = AdvocatraCloudClient(tenantHost: tenantHost)
        do {
            try await client.login(email: email, password: password, totpCode: totpCode)
            let session = try await client.fetchSession()
            cloud = client
            vaultId = session.tenantId
            if let manifestJson = try await client.fetchManifest() {
                pendingManifest = try JSONDecoder().decode(VaultManifest.self, from: Data(manifestJson.utf8))
                stage = .unlockVault
            } else {
                stage = .createVault
            }
        } catch {
            errorMessage = "Could not sign in: \(error)"
        }
    }

    func createVault() async {
        guard !passphrase.isEmpty, passphrase == passphraseConfirmation else {
            errorMessage = "Passphrases do not match."
            return
        }
        guard let cloud, let vaultId else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try VaultAccess.createVault(
                vaultId: vaultId,
                appVersion: "0.1.0",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                passphrase: passphrase
            )
            let manifestJson = String(decoding: try JSONEncoder().encode(result.manifest), as: UTF8.self)
            try await cloud.putManifest(json: manifestJson)
            masterKeyMaterial = result.masterKeyMaterial
            try? VaultKeychain.store(masterKeyMaterial: result.masterKeyMaterial, account: tenantHost)
            stage = .showRecoveryCode(result.recoveryCode)
        } catch {
            errorMessage = "Could not create the vault: \(error)"
        }
    }

    func confirmRecoveryCodeSaved() async {
        await loadConnectedSummary()
    }

    func unlockVault() async {
        guard let manifest = pendingManifest else { return }
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
            try? VaultKeychain.store(masterKeyMaterial: material, account: tenantHost)
            await loadConnectedSummary()
        } catch {
            errorMessage = "Incorrect passphrase or recovery code."
        }
    }

    private func loadConnectedSummary() async {
        guard let cloud, let masterKeyMaterial, let vaultId else { return }
        do {
            let download = try await cloud.fetchSnapshot()
            let summary =
                if let snapshot = download.snapshot {
                    try VaultSnapshot.decryptRecordsSummary(
                        envelope: snapshot,
                        masterKeyMaterial: masterKeyMaterial,
                        vaultId: vaultId
                    )
                } else {
                    VaultRecordsSummary.empty
                }
            stage = .connected(summary)
        } catch {
            errorMessage = "Vault unlocked, but couldn't load its contents: \(error)"
        }
    }
}
