// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

/// Optional and separate from the local vault — reached only via
/// VaultConnectedView's "Enable Cloud Sync" action, never the app's
/// entry point. See VaultFlowViewModel.enableCloudSync.
struct SignInView: View {
    @Bindable var model: VaultFlowViewModel

    var body: some View {
        Form {
            Section {
                Text("Your vault already works fully offline. This backs up your vault key to the cloud so it can sync across devices later — it's optional.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Tenant") {
                TextField("janedoe.advocatra.com", text: $model.tenantHost)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            Section("Sign in") {
                TextField("Email", text: $model.email)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("Password", text: $model.password)
                    .textContentType(.password)
                TextField("Two-factor code (if enabled)", text: $model.totpCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Section {
                Button("Enable Cloud Sync") {
                    Task { await model.enableCloudSync() }
                }
                .disabled(model.isLoading || model.tenantHost.isEmpty || model.email.isEmpty || model.password.isEmpty)
            }
        }
        .navigationTitle("Cloud Sync")
    }
}
