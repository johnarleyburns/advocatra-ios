// SPDX-License-Identifier: AGPL-3.0-only
import AdvocatraVault
import SwiftUI

struct VaultFlowView: View {
    @State private var model = VaultFlowViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .bootstrapping:
                    ProgressView()
                case .createVault:
                    CreateVaultView(model: model)
                case .locked:
                    UnlockVaultView(model: model)
                case let .showRecoveryCode(code):
                    RecoveryCodeView(model: model, recoveryCode: code)
                case let .connected(summary):
                    VaultConnectedView(model: model, summary: summary)
                }
            }
            .navigationTitle("Advocatra")
        }
        .task {
            await model.bootstrap()
        }
    }
}

#Preview {
    VaultFlowView()
}
