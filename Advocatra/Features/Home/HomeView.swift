// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

/// Placeholder screen: enough for the app target to compile and archive.
/// Real case-management UI is separate, not-yet-started work — see
/// TECHNICAL-DESIGN.md's milestone order.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.person.crop")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Advocatra")
                    .font(.title2.bold())
                Text("Local vault and case management are not built yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("Advocatra")
        }
    }
}

#Preview {
    HomeView()
}
