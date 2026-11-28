// SPDX-License-Identifier: AGPL-3.0-only
//
// Deliberately minimal: just enough to count what's in a decrypted
// snapshot and prove the round trip works end to end. Full typed
// decoding into case-model objects (matching packages/case's schema
// field-for-field) is separate, larger, not-yet-started work.

public struct VaultRecordsSummary: Decodable, Sendable, Equatable {
    public let taxpayerCount: Int
    public let matterCount: Int
    public let documentCount: Int
    public let correspondenceCount: Int
    public let taskCount: Int
    public let activityCount: Int

    public static let empty = VaultRecordsSummary(
        taxpayerCount: 0,
        matterCount: 0,
        documentCount: 0,
        correspondenceCount: 0,
        taskCount: 0,
        activityCount: 0
    )

    public init(
        taxpayerCount: Int,
        matterCount: Int,
        documentCount: Int,
        correspondenceCount: Int,
        taskCount: Int,
        activityCount: Int
    ) {
        self.taxpayerCount = taxpayerCount
        self.matterCount = matterCount
        self.documentCount = documentCount
        self.correspondenceCount = correspondenceCount
        self.taskCount = taskCount
        self.activityCount = activityCount
    }

    /// Any JSON value — used only to count array elements without needing
    /// to know their shape.
    private struct OpaqueElement: Decodable {}

    private enum CodingKeys: String, CodingKey {
        case taxpayers, matters, documents, correspondence, tasks, activity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taxpayerCount = try container.decodeIfPresent([OpaqueElement].self, forKey: .taxpayers)?.count ?? 0
        matterCount = try container.decodeIfPresent([OpaqueElement].self, forKey: .matters)?.count ?? 0
        documentCount = try container.decodeIfPresent([OpaqueElement].self, forKey: .documents)?.count ?? 0
        correspondenceCount =
            try container.decodeIfPresent([OpaqueElement].self, forKey: .correspondence)?.count ?? 0
        taskCount = try container.decodeIfPresent([OpaqueElement].self, forKey: .tasks)?.count ?? 0
        activityCount = try container.decodeIfPresent([OpaqueElement].self, forKey: .activity)?.count ?? 0
    }
}
