// SPDX-License-Identifier: AGPL-3.0-only
import AdvocatraVault
import SwiftUI

struct VaultConnectedView: View {
    @Bindable var model: VaultFlowViewModel
    let summary: VaultRecordsSummary
    @State private var showingCloudSync = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Vault connected")
                .font(.title2.bold())
            Text("Stored and decrypted entirely on this device. Nothing leaves your phone unless you turn on cloud sync.")
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
            if let message = model.cloudSyncResultMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .padding()
        .navigationTitle("Advocatra")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Enable Cloud Sync") { showingCloudSync = true }
            }
        }
        .sheet(isPresented: $showingCloudSync) {
            NavigationStack {
                SignInView(model: model)
            }
        }
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
    VaultConnectedView(model: VaultFlowViewModel(), summary: .empty)
}
