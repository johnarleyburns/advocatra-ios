// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
@testable import AdvocatraCore

@Suite struct CaseTaskTests {
    @Test func notOverdueWithNoDueDate() throws {
        let task = try CaseTask(id: "k1", matterId: "m1", title: "Call client", status: .open)
        #expect(isTaskOverdue(task, now: Date()) == false)
    }

    @Test func notOverdueWhenDone() throws {
        let task = try CaseTask(
            id: "k1", matterId: "m1", title: "Call client", dueDate: "2027-01-01", status: .done
        )
        #expect(isTaskOverdue(task, now: Date()) == false)
    }

    @Test func overdueWhenOpenAndPastDue() throws {
        let task = try CaseTask(
            id: "k1", matterId: "m1", title: "Call client", dueDate: "2027-01-01", status: .open
        )
        let afterDue = parseCaseDateOnly("2027-06-01")!
        #expect(isTaskOverdue(task, now: afterDue) == true)
    }

    @Test func notOverdueWhenOpenAndBeforeDue() throws {
        let task = try CaseTask(
            id: "k1", matterId: "m1", title: "Call client", dueDate: "2027-12-01", status: .open
        )
        let beforeDue = parseCaseDateOnly("2027-06-01")!
        #expect(isTaskOverdue(task, now: beforeDue) == false)
    }
}
