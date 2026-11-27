// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
@testable import AdvocatraCore

private let published = ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")!
private let lineItems = [
    FeeScheduleLineItem(serviceCode: "1040-W2", label: "1040, W-2 only", pricingType: .flat, amountCents: 8000),
    FeeScheduleLineItem(serviceCode: "1040-SCHC-INVEST", label: "1040, business + investment", pricingType: .flat, amountCents: 50000),
]

@Suite struct FeeScheduleTests {
    @Test func defaultsGuaranteeDaysToMinimum() throws {
        let schedule = try FeeSchedule(
            id: "fs1", title: "2027 Standard Fee Schedule", effectiveDate: "2027-01-01",
            publishedAt: published, lineItems: lineItems
        )
        #expect(schedule.guaranteeDays == minimumGuaranteeDays)
    }

    @Test func refusesShorterGuaranteeWithoutOverride() {
        #expect(throws: CaseValidationError.self) {
            try FeeSchedule(
                id: "fs1", title: "2027 Standard Fee Schedule", effectiveDate: "2027-01-01",
                publishedAt: published, guaranteeDays: 7, lineItems: lineItems
            )
        }
    }

    @Test func allowsShorterGuaranteeWithOverrideReason() throws {
        let schedule = try FeeSchedule(
            id: "fs1", title: "2027 Standard Fee Schedule", effectiveDate: "2027-01-01",
            publishedAt: published, guaranteeDays: 7, lineItems: lineItems,
            overrideReason: "counsel-approved exception, see matter #123"
        )
        #expect(schedule.guaranteeDays == 7)
    }

    @Test func cannotSupersedeBeforeGuaranteeWindowElapses() throws {
        let schedule = try FeeSchedule(
            id: "fs1", title: "2027 Standard Fee Schedule", effectiveDate: "2027-01-01",
            publishedAt: published, lineItems: lineItems
        )
        let fifteenDaysLater = ISO8601DateFormatter().date(from: "2027-01-15T00:00:00Z")!
        #expect(canSupersedeFeeSchedule(schedule, now: fifteenDaysLater) == false)
    }

    @Test func canSupersedeOnceGuaranteeWindowElapses() throws {
        let schedule = try FeeSchedule(
            id: "fs1", title: "2027 Standard Fee Schedule", effectiveDate: "2027-01-01",
            publishedAt: published, lineItems: lineItems
        )
        let honorUntil = feeScheduleHonorUntil(schedule)
        #expect(canSupersedeFeeSchedule(schedule, now: honorUntil) == true)
    }
}
