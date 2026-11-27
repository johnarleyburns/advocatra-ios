// SPDX-License-Identifier: AGPL-3.0-only
import Testing
@testable import AdvocatraCore

@Suite struct MatterTests {
    @Test func acceptsNonTaxCourtMatterWithoutDetails() throws {
        let matter = try Matter(
            id: "m1", taxpayerId: "t1", category: .examination, matterType: "Field audit",
            status: .open, openedDate: "2027-01-01"
        )
        #expect(matter.taxCourtDetails == nil)
    }

    @Test func rejectsTaxCourtMatterWithNoDetails() {
        #expect(throws: CaseValidationError.self) {
            try Matter(
                id: "m1", taxpayerId: "t1", category: .taxCourt, matterType: "Deficiency",
                status: .open, openedDate: "2027-01-01"
            )
        }
    }

    @Test func acceptsTaxCourtMatterWithDetails() throws {
        let matter = try Matter(
            id: "m1", taxpayerId: "t1", category: .taxCourt, matterType: "Deficiency",
            status: .open, openedDate: "2027-01-01",
            taxCourtDetails: TaxCourtDetails(docketNumber: "12345-27")
        )
        #expect(matter.taxCourtDetails?.docketNumber == "12345-27")
        #expect(matter.taxCourtDetails?.court == "United States Tax Court")
    }
}
