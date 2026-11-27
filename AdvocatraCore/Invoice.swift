// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/billing/src/invoice.ts`.
public enum InvoiceStatus: String, Codable, Sendable {
    case draft
    case sent
    case partiallyPaid = "partially_paid"
    case paid
    case overdue
    case void
}

public struct InvoiceLineItem: Codable, Sendable, Equatable {
    public var description: String
    public var quantity: Double
    public var rateCents: Int
    public var amountCents: Int
    public var sourceTimeEntryIds: [String]
    public var engagementId: String?

    public init(
        description: String,
        quantity: Double,
        rateCents: Int,
        amountCents: Int,
        sourceTimeEntryIds: [String] = [],
        engagementId: String? = nil
    ) {
        self.description = description
        self.quantity = quantity
        self.rateCents = rateCents
        self.amountCents = amountCents
        self.sourceTimeEntryIds = sourceTimeEntryIds
        self.engagementId = engagementId
    }
}

public struct Invoice: Codable, Sendable, Equatable {
    public var id: String
    public var taxpayerId: String
    public var engagementIds: [String]
    public var invoiceNumber: Int
    public var issueDate: String
    public var dueDate: String
    public var lineItems: [InvoiceLineItem]
    public var status: InvoiceStatus

    public init(
        id: String,
        taxpayerId: String,
        engagementIds: [String],
        invoiceNumber: Int,
        issueDate: String,
        dueDate: String,
        lineItems: [InvoiceLineItem],
        status: InvoiceStatus
    ) throws {
        guard !engagementIds.isEmpty else {
            throw CaseValidationError.invalidField("engagementIds", "must have at least one id")
        }
        guard !lineItems.isEmpty else {
            throw CaseValidationError.invalidField("lineItems", "must have at least one item")
        }
        self.id = id
        self.taxpayerId = taxpayerId
        self.engagementIds = engagementIds
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.lineItems = lineItems
        self.status = status
    }
}

/// Sum of an invoice's line items, in integer cents.
public func invoiceSubtotalCents(_ invoice: Invoice) -> Int {
    invoice.lineItems.reduce(0) { $0 + $1.amountCents }
}
