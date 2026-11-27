// SPDX-License-Identifier: AGPL-3.0-only
import Testing
@testable import AdvocatraCore

@Suite struct TimeEntryTests {
    @Test func billsFractionalHourAtSnapshottedRate() throws {
        let entry = try TimeEntry(
            id: "te1", engagementId: "e1", date: "2027-03-01", durationHours: 0.25,
            description: "Reviewed CP2000 notice", rateAtEntryCentsPerHour: 25000
        )
        #expect(timeEntryAmountCents(entry) == 6250)
    }

    @Test func zeroWhenNotBillable() throws {
        let entry = try TimeEntry(
            id: "te1", engagementId: "e1", date: "2027-03-01", durationHours: 1,
            description: "Internal admin", billable: false, rateAtEntryCentsPerHour: 25000
        )
        #expect(timeEntryAmountCents(entry) == 0)
    }
}

@Suite struct RetainerTests {
    @Test func computesBalanceFromHistory() {
        let retainer = Retainer(
            id: "r1", taxpayerId: "t1", initialAmountCents: 500_000, currentBalanceCents: 350_000,
            deposits: [RetainerDeposit(date: "2027-01-01", amountCents: 100_000)],
            draws: [RetainerDraw(date: "2027-02-01", amountCents: 250_000, description: "Feb invoice")]
        )
        #expect(computeRetainerBalance(retainer) == 350_000)
        #expect(retainer.currentBalanceCents == computeRetainerBalance(retainer))
    }

    @Test func needsReplenishmentBelowThreshold() {
        let retainer = Retainer(
            id: "r1", taxpayerId: "t1", initialAmountCents: 500_000, currentBalanceCents: 10_000,
            replenishmentThresholdCents: 50_000
        )
        #expect(retainerNeedsReplenishment(retainer) == true)
    }
}

@Suite struct InvoicePaymentTests {
    @Test func partialPaymentLeavesOutstandingBalance() throws {
        let invoice = try Invoice(
            id: "inv1", taxpayerId: "t1", engagementIds: ["e1"], invoiceNumber: 1,
            issueDate: "2027-03-01", dueDate: "2027-03-31",
            lineItems: [InvoiceLineItem(description: "2027 1040 flat fee", quantity: 1, rateCents: 8000, amountCents: 8000)],
            status: .sent
        )
        let payments = [Payment(id: "p1", invoiceId: "inv1", date: "2027-03-05", amountCents: 3000, method: .card)]
        #expect(invoiceAmountPaidCents(invoice, payments: payments) == 3000)
        #expect(invoiceAmountOutstandingCents(invoice, payments: payments) == 5000)
    }

    @Test func outstandingFlooredAtZeroWhenOverpaid() throws {
        let invoice = try Invoice(
            id: "inv1", taxpayerId: "t1", engagementIds: ["e1"], invoiceNumber: 1,
            issueDate: "2027-03-01", dueDate: "2027-03-31",
            lineItems: [InvoiceLineItem(description: "2027 1040 flat fee", quantity: 1, rateCents: 8000, amountCents: 8000)],
            status: .sent
        )
        let payments = [Payment(id: "p1", invoiceId: "inv1", date: "2027-03-05", amountCents: 9000, method: .card)]
        #expect(invoiceAmountOutstandingCents(invoice, payments: payments) == 0)
    }
}
