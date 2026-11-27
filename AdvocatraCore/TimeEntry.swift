// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/billing/src/time-entry.ts`.
public struct TimeEntry: Codable, Sendable, Equatable {
    public var id: String
    public var engagementId: String
    public var date: String
    /// Fractional hours (e.g. 0.25). Not a money type, so a Double is fine here.
    public var durationHours: Double
    public var description: String
    public var billable: Bool
    /// Integer cents per hour, snapshotted at entry time.
    public var rateAtEntryCentsPerHour: Int
    public var invoiceId: String?

    public init(
        id: String,
        engagementId: String,
        date: String,
        durationHours: Double,
        description: String,
        billable: Bool = true,
        rateAtEntryCentsPerHour: Int,
        invoiceId: String? = nil
    ) throws {
        guard durationHours > 0 else {
            throw CaseValidationError.invalidField("durationHours", "must be positive")
        }
        guard !description.isEmpty else {
            throw CaseValidationError.invalidField("description", "must not be empty")
        }
        self.id = id
        self.engagementId = engagementId
        self.date = date
        self.durationHours = durationHours
        self.description = description
        self.billable = billable
        self.rateAtEntryCentsPerHour = rateAtEntryCentsPerHour
        self.invoiceId = invoiceId
    }
}

/// Billable amount for one time entry, in integer cents, rounded to the nearest cent.
public func timeEntryAmountCents(_ entry: TimeEntry) -> Int {
    guard entry.billable else { return 0 }
    return Int((entry.durationHours * Double(entry.rateAtEntryCentsPerHour)).rounded())
}
