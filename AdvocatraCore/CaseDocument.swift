// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/case/src/document.ts`. Named `CaseDocument`, not
/// `Document`, to avoid any ambiguity with platform document types.
public enum CaseDocumentType: String, Codable, Sendable {
    case notice
    case correspondence
    case pleading
    case discovery
    case order
    case financial
    case other
}

public struct CaseDocument: Codable, Sendable, Equatable {
    public var id: String
    public var taxpayerId: String
    public var matterId: String
    public var type: CaseDocumentType
    public var taxYear: Int?
    public var description: String
    /// Reference to the encrypted object; never the plaintext bytes.
    public var encryptedObjectRef: String
    public var uploadedAt: String

    public init(
        id: String,
        taxpayerId: String,
        matterId: String,
        type: CaseDocumentType,
        taxYear: Int? = nil,
        description: String,
        encryptedObjectRef: String,
        uploadedAt: String
    ) {
        self.id = id
        self.taxpayerId = taxpayerId
        self.matterId = matterId
        self.type = type
        self.taxYear = taxYear
        self.description = description
        self.encryptedObjectRef = encryptedObjectRef
        self.uploadedAt = uploadedAt
    }
}
