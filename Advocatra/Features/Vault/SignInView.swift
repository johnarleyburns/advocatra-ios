// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct SignInView: View {
    @Bindable var model: VaultFlowViewModel

    var body: some View {
        Form {
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
                Button("Sign In") {
                    Task { await model.signIn() }
                }
                .disabled(model.isLoading || model.tenantHost.isEmpty || model.email.isEmpty || model.password.isEmpty)
            }
        }
        .navigationTitle("Sign In")
    }
}
