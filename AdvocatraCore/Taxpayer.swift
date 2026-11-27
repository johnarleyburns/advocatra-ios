// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/case/src/taxpayer.ts` in the web repo. Hand-ported, not
/// shared code — see TECHNICAL-DESIGN.md §2 for why.
public enum TaxpayerType: String, Codable, Sendable {
    case individual
    case business
}

public struct RepresentationAuthorization: Codable, Sendable, Equatable {
    public var onFile: Bool
    public var form: String?
    public var signedDate: String?

    public init(onFile: Bool, form: String? = nil, signedDate: String? = nil) {
        self.onFile = onFile
        self.form = form
        self.signedDate = signedDate
    }
}

public struct Taxpayer: Codable, Sendable, Equatable {
    public var id: String
    public var type: TaxpayerType
    public var name: String
    /// SSN or EIN. Part of the encrypted record; never surfaced in an index, log or manifest.
    public var taxpayerIdNumber: String?
    public var address: String?
    public var phones: [String]
    public var emails: [String]
    public var representationAuthorization: RepresentationAuthorization?
    public var notes: String?

    public init(
        id: String,
        type: TaxpayerType,
        name: String,
        taxpayerIdNumber: String? = nil,
        address: String? = nil,
        phones: [String] = [],
        emails: [String] = [],
        representationAuthorization: RepresentationAuthorization? = nil,
        notes: String? = nil
    ) throws {
        guard !name.isEmpty else {
            throw CaseValidationError.invalidField("name", "must not be empty")
        }
        self.id = id
        self.type = type
        self.name = name
        self.taxpayerIdNumber = taxpayerIdNumber
        self.address = address
        self.phones = phones
        self.emails = emails
        self.representationAuthorization = representationAuthorization
        self.notes = notes
    }
}

public enum CaseValidationError: Error, Equatable, CustomStringConvertible {
    case invalidField(String, String)

    public var description: String {
        switch self {
        case let .invalidField(field, reason):
            return "\(field): \(reason)"
        }
    }
}
