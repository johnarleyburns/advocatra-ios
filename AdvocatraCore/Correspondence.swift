// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/case/src/correspondence.ts`.
public enum CorrespondenceDirection: String, Codable, Sendable {
    case inbound
    case outbound
}

public enum CorrespondenceMethod: String, Codable, Sendable {
    case mail
    case fax
    case efax
    case portal
    case phone
    case email
}

public struct Correspondence: Codable, Sendable, Equatable {
    public var id: String
    public var matterId: String
    public var direction: CorrespondenceDirection
    public var method: CorrespondenceMethod
    public var date: String
    public var summary: String
    public var relatedDocumentIds: [String]

    public init(
        id: String,
        matterId: String,
        direction: CorrespondenceDirection,
        method: CorrespondenceMethod,
        date: String,
        summary: String,
        relatedDocumentIds: [String] = []
    ) throws {
        guard !summary.isEmpty else {
            throw CaseValidationError.invalidField("summary", "must not be empty")
        }
        self.id = id
        self.matterId = matterId
        self.direction = direction
        self.method = method
        self.date = date
        self.summary = summary
        self.relatedDocumentIds = relatedDocumentIds
    }
}
