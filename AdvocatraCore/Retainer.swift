// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/billing/src/retainer.ts`.
public struct RetainerDeposit: Codable, Sendable, Equatable {
    public var date: String
    public var amountCents: Int
    public var paymentId: String?

    public init(date: String, amountCents: Int, paymentId: String? = nil) {
        self.date = date
        self.amountCents = amountCents
        self.paymentId = paymentId
    }
}

public struct RetainerDraw: Codable, Sendable, Equatable {
    public var date: String
    public var amountCents: Int
    public var invoiceId: String?
    public var description: String?

    public init(date: String, amountCents: Int, invoiceId: String? = nil, description: String? = nil) {
        self.date = date
        self.amountCents = amountCents
        self.invoiceId = invoiceId
        self.description = description
    }
}

public struct Retainer: Codable, Sendable, Equatable {
    public var id: String
    public var taxpayerId: String
    public var engagementId: String?
    public var initialAmountCents: Int
    public var currentBalanceCents: Int
    public var replenishmentThresholdCents: Int?
    public var deposits: [RetainerDeposit]
    public var draws: [RetainerDraw]

    public init(
        id: String,
        taxpayerId: String,
        engagementId: String? = nil,
        initialAmountCents: Int,
        currentBalanceCents: Int,
        replenishmentThresholdCents: Int? = nil,
        deposits: [RetainerDeposit] = [],
        draws: [RetainerDraw] = []
    ) {
        self.id = id
        self.taxpayerId = taxpayerId
        self.engagementId = engagementId
        self.initialAmountCents = initialAmountCents
        self.currentBalanceCents = currentBalanceCents
        self.replenishmentThresholdCents = replenishmentThresholdCents
        self.deposits = deposits
        self.draws = draws
    }
}

/// Recompute the balance from history, independent of the stored `currentBalanceCents`.
public func computeRetainerBalance(_ retainer: Retainer) -> Int {
    let deposited = retainer.deposits.reduce(0) { $0 + $1.amountCents }
    let drawn = retainer.draws.reduce(0) { $0 + $1.amountCents }
    return retainer.initialAmountCents + deposited - drawn
}

/// Whether the retainer balance is at or below its replenishment threshold.
public func retainerNeedsReplenishment(_ retainer: Retainer) -> Bool {
    guard let threshold = retainer.replenishmentThresholdCents else { return false }
    return retainer.currentBalanceCents <= threshold
}
