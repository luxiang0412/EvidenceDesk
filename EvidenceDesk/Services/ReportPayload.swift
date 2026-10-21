import Foundation

/// Value-type snapshot of everything a report needs. Keeping the generator
/// decoupled from SwiftData makes it unit-testable without a database and
/// lets the UI build reports from either live models or fixtures.
struct ReportPayload: Sendable {
    struct CaseInfo: Sendable {
        var shortCode: String
        var title: String
        var question: String
        var scope: String
    }

    struct SourceInfo: Sendable {
        var ref: String            // "S-001"
        var title: String
        var sourceType: SourceType
        var urlString: String?     // nullable => no clickable link
        var attachmentRelativePath: String? // relative, valid inside export bundle
        var publisher: String
        var publishedDate: Date?
        var addedAt: Date
        var isMissing: Bool
        var userNotes: String
    }

    struct EvidenceInfo: Sendable {
        var ref: String            // "E-003"
        var text: String
        var type: EvidenceType
        var sourceRef: String?     // "S-001"; nil => personal note
        var locationNote: String
        var pageNumber: Int?
        var userNotes: String
    }

    struct FindingInfo: Sendable {
        var ref: String            // "F-002"
        var title: String
        var body: String
        var status: FindingStatus
        var uncertainty: String
        /// Evidence refs grouped by relation.
        var evidenceRefs: [RelationType: [String]]
    }

    struct TimelineEventInfo: Sendable {
        var title: String
        var detail: String
        var date: Date?
        var precision: DatePrecision
        var sourceRef: String?
        var notes: String
    }

    var caseInfo: CaseInfo
    var sources: [SourceInfo]
    var evidences: [EvidenceInfo]
    var findings: [FindingInfo]
    var timeline: [TimelineEventInfo]
    var generatedAt: Date

    /// Missing-source / unresolved notes collecting from across the case.
    var unresolvedNotes: [String]
}