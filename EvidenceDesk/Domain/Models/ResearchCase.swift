import Foundation
import SwiftData

@Model
final class ResearchCase {
    /// Stable identifier – never changes, never reused.
    var id: UUID
    /// Human readable short number, unique within the library, stable after creation: `C-001`.
    var shortCode: String
    var title: String
    var researchQuestion: String
    var researchScope: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \Source.case)
    var sources: [Source] = []

    @Relationship(deleteRule: .cascade, inverse: \Evidence.case)
    var evidences: [Evidence] = []

    @Relationship(deleteRule: .cascade, inverse: \Finding.case)
    var findings: [Finding] = []

    @Relationship(deleteRule: .cascade, inverse: \TimelineEvent.case)
    var timelineEvents: [TimelineEvent] = []

    init(
        id: UUID = UUID(),
        shortCode: String,
        title: String,
        researchQuestion: String = "",
        researchScope: String = ""
    ) {
        self.id = id
        self.shortCode = shortCode
        self.title = title
        self.researchQuestion = researchQuestion
        self.researchScope = researchScope
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
    }
}