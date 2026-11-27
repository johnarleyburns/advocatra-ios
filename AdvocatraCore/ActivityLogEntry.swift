// SPDX-License-Identifier: AGPL-3.0-only

/// Mirrors `packages/case/src/activity-log.ts`. Append-only audit trail.
public struct ActivityLogEntry: Codable, Sendable, Equatable {
    public var id: String
    public var matterId: String
    public var timestamp: String
    public var actor: String
    public var type: String
    public var description: String

    public init(
        id: String,
        matterId: String,
        timestamp: String,
        actor: String,
        type: String,
        description: String
    ) {
        self.id = id
        self.matterId = matterId
        self.timestamp = timestamp
        self.actor = actor
        self.type = type
        self.description = description
    }
}
