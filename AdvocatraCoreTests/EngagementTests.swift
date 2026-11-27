// SPDX-License-Identifier: AGPL-3.0-only
import Testing
@testable import AdvocatraCore

@Suite struct EngagementTests {
    @Test func acceptsFlatEngagementWithCommittedAmount() throws {
        let engagement = try Engagement(
            id: "e1", taxpayerId: "t1", description: "2027 1040, W-2 only",
            pricingType: .flat, committedAmountCents: 8000, status: .accepted, createdAt: "2027-01-10"
        )
        #expect(engagement.committedAmountCents == 8000)
    }

    @Test func rejectsFlatEngagementWithNoCommittedAmount() {
        #expect(throws: CaseValidationError.self) {
            try Engagement(
                id: "e1", taxpayerId: "t1", description: "2027 1040, W-2 only",
                pricingType: .flat, status: .accepted, createdAt: "2027-01-10"
            )
        }
    }

    @Test func rejectsHourlyEngagementWithNoRate() {
        #expect(throws: CaseValidationError.self) {
            try Engagement(
                id: "e1", taxpayerId: "t1", description: "Ongoing representation",
                pricingType: .hourly, status: .accepted, createdAt: "2027-01-10"
            )
        }
    }

    @Test func acceptsRetainerEngagementWithNeitherField() throws {
        let engagement = try Engagement(
            id: "e1", taxpayerId: "t1", description: "Ongoing representation",
            pricingType: .retainer, status: .accepted, createdAt: "2027-01-10"
        )
        #expect(engagement.pricingType == .retainer)
    }
}
