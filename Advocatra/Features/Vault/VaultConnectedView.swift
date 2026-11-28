// SPDX-License-Identifier: AGPL-3.0-only
import AdvocatraVault
import SwiftUI

struct VaultConnectedView: View {
    let summary: VaultRecordsSummary

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Vault connected")
                .font(.title2.bold())
            Text("Decrypted entirely on this device. Advocatra's servers never see a passphrase, a key, or your unencrypted data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                summaryRow("Taxpayers", summary.taxpayerCount)
                summaryRow("Matters", summary.matterCount)
                summaryRow("Documents", summary.documentCount)
                summaryRow("Correspondence", summary.correspondenceCount)
                summaryRow("Tasks", summary.taskCount)
                summaryRow("Activity", summary.activityCount)
            }
            .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Advocatra")
    }

    @ViewBuilder
    private func summaryRow(_ label: String, _ count: Int) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text("\(count)").fontWeight(.semibold).gridColumnAlignment(.trailing)
        }
    }
}

#Preview {
    VaultConnectedView(summary: .empty)
}
