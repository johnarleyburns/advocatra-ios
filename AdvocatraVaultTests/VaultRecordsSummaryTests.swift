// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing

@testable import AdvocatraVault

@Suite struct VaultRecordsSummaryTests {
    @Test func countsEachTopLevelArrayIndependentlyOfItsElementShape() throws {
        let json = #"""
        {
          "taxpayers": [{"id":"t1","name":"Jane"},{"id":"t2","name":"Bob"}],
          "matters": [{"id":"m1"}],
          "documents": [],
          "correspondence": [{"id":"c1"},{"id":"c2"},{"id":"c3"}],
          "tasks": [{"id":"k1"}],
          "activity": [{"id":"a1"},{"id":"a2"}],
          "billing": {"feeSchedules":[],"engagements":[],"timeEntries":[],"retainers":[],"invoices":[],"payments":[]}
        }
        """#
        let summary = try JSONDecoder().decode(VaultRecordsSummary.self, from: Data(json.utf8))
        #expect(summary.taxpayerCount == 2)
        #expect(summary.matterCount == 1)
        #expect(summary.documentCount == 0)
        #expect(summary.correspondenceCount == 3)
        #expect(summary.taskCount == 1)
        #expect(summary.activityCount == 2)
    }

    @Test func defaultsEveryCountToZeroWhenKeysAreAbsent() throws {
        let summary = try JSONDecoder().decode(VaultRecordsSummary.self, from: Data("{}".utf8))
        #expect(summary == VaultRecordsSummary.empty)
    }
}
