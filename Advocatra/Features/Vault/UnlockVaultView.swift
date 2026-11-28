// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct UnlockVaultView: View {
    @Bindable var model: VaultFlowViewModel

    var body: some View {
        Form {
            Section("Unlock with passphrase") {
                SecureField("Passphrase", text: $model.passphrase)
                    .textContentType(.password)
            }
            Section("Or with your recovery code") {
                TextField("XXXXX-XXXXX-XXXXX-XXXXX-XXXXX", text: $model.recoveryCodeInput)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Section {
                Button("Unlock Vault") {
                    Task { await model.unlockVault() }
                }
                .disabled(model.isLoading || (model.passphrase.isEmpty && model.recoveryCodeInput.isEmpty))
            }
        }
        .navigationTitle("Unlock Vault")
    }
}
