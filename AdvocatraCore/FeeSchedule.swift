// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Mirrors `packages/billing/src/fee-schedule.ts`.
public let minimumGuaranteeDays = 30

public enum LineItemPricingType: String, Codable, Sendable {
    case flat
    case hourly
}

public struct FeeScheduleLineItem: Codable, Sendable, Equatable {
    public var serviceCode: String
    public var label: String
    public var pricingType: LineItemPricingType
    /// Integer cents. Never a floating-point number for money.
    public var amountCents: Int

    public init(serviceCode: String, label: String, pricingType: LineItemPricingType, amountCents: Int) {
        self.serviceCode = serviceCode
        self.label = label
        self.pricingType = pricingType
        self.amountCents = amountCents
    }
}

public struct FeeSchedule: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var effectiveDate: String
    public var publishedAt: Date
    /// Minimum days this schedule must be honored once published. Defaults to 30.
    public var guaranteeDays: Int
    public var supersedesId: String?
    public var lineItems: [FeeScheduleLineItem]

    /// Create a validated FeeSchedule. Refuses `guaranteeDays` below
    /// `minimumGuaranteeDays` unless the caller supplies an explicit
    /// `overrideReason`, which the caller is responsible for persisting
    /// alongside the schedule as part of the audit trail.
    public init(
        id: String,
        title: String,
        effectiveDate: String,
        publishedAt: Date,
        guaranteeDays: Int = minimumGuaranteeDays,
        supersedesId: String? = nil,
        lineItems: [FeeScheduleLineItem],
        overrideReason: String? = nil
    ) throws {
        guard !title.isEmpty else {
            throw CaseValidationError.invalidField("title", "must not be empty")
        }
        guard !lineItems.isEmpty else {
            throw CaseValidationError.invalidField("lineItems", "must have at least one item")
        }
        if guaranteeDays < minimumGuaranteeDays && overrideReason == nil {
            throw CaseValidationError.invalidField(
                "guaranteeDays",
                "below \(minimumGuaranteeDays) requires an explicit, recorded overrideReason"
            )
        }
        self.id = id
        self.title = title
        self.effectiveDate = effectiveDate
        self.publishedAt = publishedAt
        self.guaranteeDays = guaranteeDays
        self.supersedesId = supersedesId
        self.lineItems = lineItems
    }
}

/// The date this schedule must be honored through.
public func feeScheduleHonorUntil(_ schedule: FeeSchedule) -> Date {
    schedule.publishedAt.addingTimeInterval(TimeInterval(schedule.guaranteeDays) * 24 * 60 * 60)
}

/// Whether this schedule may be superseded by a new one at time `now`.
public func canSupersedeFeeSchedule(_ schedule: FeeSchedule, now: Date) -> Bool {
    now >= feeScheduleHonorUntil(schedule)
}
