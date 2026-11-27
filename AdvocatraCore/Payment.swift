// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/billing/src/payment.ts`.
public enum PaymentMethod: String, Codable, Sendable {
    case check
    case ach
    case card
    case cash
    case retainerDraw = "retainer-draw"
}

public struct Payment: Codable, Sendable, Equatable {
    public var id: String
    public var invoiceId: String
    public var date: String
    public var amountCents: Int
    public var method: PaymentMethod
    public var reference: String?

    public init(
        id: String,
        invoiceId: String,
        date: String,
        amountCents: Int,
        method: PaymentMethod,
        reference: String? = nil
    ) {
        self.id = id
        self.invoiceId = invoiceId
        self.date = date
        self.amountCents = amountCents
        self.method = method
        self.reference = reference
    }
}

/// Total paid toward one invoice, in integer cents. Supports partial payments.
public func invoiceAmountPaidCents(_ invoice: Invoice, payments: [Payment]) -> Int {
    payments.filter { $0.invoiceId == invoice.id }.reduce(0) { $0 + $1.amountCents }
}

/// Remaining balance on an invoice, in integer cents, floored at zero.
public func invoiceAmountOutstandingCents(_ invoice: Invoice, payments: [Payment]) -> Int {
    max(invoiceSubtotalCents(invoice) - invoiceAmountPaidCents(invoice, payments: payments), 0)
}
