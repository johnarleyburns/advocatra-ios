// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Mirrors `packages/case/src/task.ts`. Named `CaseTask`, not `Task`, because
/// `Task` is Swift's own concurrency type.
public enum CaseTaskStatus: String, Codable, Sendable {
    case open
    case done
}

public struct CaseTask: Codable, Sendable, Equatable {
    public var id: String
    public var matterId: String
    public var title: String
    public var dueDate: String?
    public var status: CaseTaskStatus
    public var assignedTo: String?
    public var reminderDate: String?

    public init(
        id: String,
        matterId: String,
        title: String,
        dueDate: String? = nil,
        status: CaseTaskStatus,
        assignedTo: String? = nil,
        reminderDate: String? = nil
    ) throws {
        guard !title.isEmpty else {
            throw CaseValidationError.invalidField("title", "must not be empty")
        }
        self.id = id
        self.matterId = matterId
        self.title = title
        self.dueDate = dueDate
        self.status = status
        self.assignedTo = assignedTo
        self.reminderDate = reminderDate
    }
}

/// A task is overdue if it's still open and its due date has passed `now`.
/// Mirrors `isTaskOverdue` in `packages/case/src/task.ts`.
public func isTaskOverdue(_ task: CaseTask, now: Date) -> Bool {
    guard task.status == .open, let dueDate = task.dueDate else { return false }
    guard let due = parseCaseDateOnly(dueDate) else { return false }
    return due < now
}

/// Parses a plain `YYYY-MM-DD` date, as used throughout the case schema.
/// Builds a fresh formatter per call rather than sharing one, since
/// `ISO8601DateFormatter` is not `Sendable` and this isn't a hot path.
public func parseCaseDateOnly(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: value)
}
