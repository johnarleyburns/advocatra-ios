// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/billing/src/engagement.ts`.
public enum EngagementPricingType: String, Codable, Sendable {
    case flat
    case hourly
    case retainer
}

public enum EngagementStatus: String, Codable, Sendable {
    case proposed
    case accepted
    case active
    case completed
    case cancelled
}

public struct Engagement: Codable, Sendable, Equatable {
    public var id: String
    public var taxpayerId: String
    public var matterId: String?
    public var taxYear: Int?
    public var description: String
    public var pricingType: EngagementPricingType
    /// Integer cents. Required when `pricingType == .flat`.
    public var committedAmountCents: Int?
    /// Integer cents per hour. Required when `pricingType == .hourly`.
    public var hourlyRateCentsPerHour: Int?
    public var quotedFromFeeScheduleId: String?
    public var quotedFromLineItemId: String?
    public var customQuoteReason: String?
    public var status: EngagementStatus
    public var createdAt: String
    public var acceptedAt: String?

    public init(
        id: String,
        taxpayerId: String,
        matterId: String? = nil,
        taxYear: Int? = nil,
        description: String,
        pricingType: EngagementPricingType,
        committedAmountCents: Int? = nil,
        hourlyRateCentsPerHour: Int? = nil,
        quotedFromFeeScheduleId: String? = nil,
        quotedFromLineItemId: String? = nil,
        customQuoteReason: String? = nil,
        status: EngagementStatus,
        createdAt: String,
        acceptedAt: String? = nil
    ) throws {
        guard !description.isEmpty else {
            throw CaseValidationError.invalidField("description", "must not be empty")
        }
        if pricingType == .flat && committedAmountCents == nil {
            throw CaseValidationError.invalidField(
                "committedAmountCents", "required when pricingType is \"flat\"")
        }
        if pricingType == .hourly && hourlyRateCentsPerHour == nil {
            throw CaseValidationError.invalidField(
                "hourlyRateCentsPerHour", "required when pricingType is \"hourly\"")
        }
        self.id = id
        self.taxpayerId = taxpayerId
        self.matterId = matterId
        self.taxYear = taxYear
        self.description = description
        self.pricingType = pricingType
        self.committedAmountCents = committedAmountCents
        self.hourlyRateCentsPerHour = hourlyRateCentsPerHour
        self.quotedFromFeeScheduleId = quotedFromFeeScheduleId
        self.quotedFromLineItemId = quotedFromLineItemId
        self.customQuoteReason = customQuoteReason
        self.status = status
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
    }
}
