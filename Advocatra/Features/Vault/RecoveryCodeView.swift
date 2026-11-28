// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct RecoveryCodeView: View {
    let model: VaultFlowViewModel
    let recoveryCode: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Save your recovery code")
                .font(.title2.bold())
            Text("This is shown only once. If you lose both your passphrase and this code, your vault cannot be recovered — by design.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text(recoveryCode)
                .font(.system(.title3, design: .monospaced))
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            Button("I've saved this") {
                Task { await model.confirmRecoveryCodeSaved() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Vault Created")
    }
}
