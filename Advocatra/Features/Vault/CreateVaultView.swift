// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct CreateVaultView: View {
    @Bindable var model: VaultFlowViewModel

    var body: some View {
        Form {
            Section {
                Text(
                    "No vault exists yet for this account. Choose a passphrase to encrypt it — "
                        + "Advocatra never sees it, and there is no way to recover it if you lose "
                        + "both it and the recovery code you'll be shown next."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Section("Vault passphrase") {
                SecureField("Passphrase", text: $model.passphrase)
                    .textContentType(.newPassword)
                SecureField("Confirm passphrase", text: $model.passphraseConfirmation)
                    .textContentType(.newPassword)
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Section {
                Button("Create Vault") {
                    Task { await model.createVault() }
                }
                .disabled(model.isLoading || model.passphrase.isEmpty)
            }
        }
        .navigationTitle("Set Up Vault")
    }
}
