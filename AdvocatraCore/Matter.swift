// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/case/src/matter.ts`. Tax Court is first-class, not a
/// future add-on — see TECHNICAL-DESIGN.md §4.
public enum MatterCategory: String, Codable, Sendable {
    case examination
    case collection
    case cdp
    case appeals
    case penalties
    case innocentSpouse = "innocent-spouse"
    case employmentTax = "employment-tax"
    case informationReporting = "information-reporting"
    case taxCourt = "tax-court"
    case other
}

public enum MatterStatus: String, Codable, Sendable {
    case open
    case pending
    case closed
}

public struct TaxCourtDetails: Codable, Sendable, Equatable {
    public var court: String
    public var docketNumber: String?
    public var petitionDate: String?
    public var noticeOfDeficiencyDate: String?
    public var petitionDeadline: String?
    public var answerDate: String?
    public var assignedIrsCounsel: String?
    public var discoveryStatus: String?
    public var motions: [String]
    public var trialSession: String?
    public var settlementStatus: String?
    public var decision: String?
    public var appealInfo: String?

    public init(
        court: String = "United States Tax Court",
        docketNumber: String? = nil,
        petitionDate: String? = nil,
        noticeOfDeficiencyDate: String? = nil,
        petitionDeadline: String? = nil,
        answerDate: String? = nil,
        assignedIrsCounsel: String? = nil,
        discoveryStatus: String? = nil,
        motions: [String] = [],
        trialSession: String? = nil,
        settlementStatus: String? = nil,
        decision: String? = nil,
        appealInfo: String? = nil
    ) {
        self.court = court
        self.docketNumber = docketNumber
        self.petitionDate = petitionDate
        self.noticeOfDeficiencyDate = noticeOfDeficiencyDate
        self.petitionDeadline = petitionDeadline
        self.answerDate = answerDate
        self.assignedIrsCounsel = assignedIrsCounsel
        self.discoveryStatus = discoveryStatus
        self.motions = motions
        self.trialSession = trialSession
        self.settlementStatus = settlementStatus
        self.decision = decision
        self.appealInfo = appealInfo
    }
}

public struct Matter: Codable, Sendable, Equatable {
    public var id: String
    public var taxpayerId: String
    public var category: MatterCategory
    public var matterType: String
    public var status: MatterStatus
    public var taxYears: [Int]
    public var openedDate: String
    public var closedDate: String?
    public var assignedPractitioner: String?
    public var notes: String?
    public var taxCourtDetails: TaxCourtDetails?

    /// `taxCourtDetails` is required whenever `category == .taxCourt` — the
    /// same invariant `MatterSchema`'s `.refine` enforces in the TS package.
    public init(
        id: String,
        taxpayerId: String,
        category: MatterCategory,
        matterType: String,
        status: MatterStatus,
        taxYears: [Int] = [],
        openedDate: String,
        closedDate: String? = nil,
        assignedPractitioner: String? = nil,
        notes: String? = nil,
        taxCourtDetails: TaxCourtDetails? = nil
    ) throws {
        guard !matterType.isEmpty else {
            throw CaseValidationError.invalidField("matterType", "must not be empty")
        }
        if category == .taxCourt && taxCourtDetails == nil {
            throw CaseValidationError.invalidField(
                "taxCourtDetails",
                "required when category is \"tax-court\""
            )
        }
        self.id = id
        self.taxpayerId = taxpayerId
        self.category = category
        self.matterType = matterType
        self.status = status
        self.taxYears = taxYears
        self.openedDate = openedDate
        self.closedDate = closedDate
        self.assignedPractitioner = assignedPractitioner
        self.notes = notes
        self.taxCourtDetails = taxCourtDetails
    }
}
