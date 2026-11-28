// SPDX-License-Identifier: AGPL-3.0-only
import AdvocatraVault
import SwiftUI

struct VaultFlowView: View {
    @State private var model = VaultFlowViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .signIn:
                    SignInView(model: model)
                case .createVault:
                    CreateVaultView(model: model)
                case .unlockVault:
                    UnlockVaultView(model: model)
                case let .showRecoveryCode(code):
                    RecoveryCodeView(model: model, recoveryCode: code)
                case let .connected(summary):
                    VaultConnectedView(summary: summary)
                }
            }
            .navigationTitle("Advocatra")
        }
    }
}

#Preview {
    VaultFlowView()
}
