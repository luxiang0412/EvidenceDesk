import Foundation
import SwiftData

/// Explicit association between a finding and an evidence item, carrying a
/// typed relation. Bare many-to-many is intentionally avoided so the relation
/// type is always explicit, testable and exportable.
@Model
final class FindingEvidenceLink {
    var id: UUID
    var relationTypeRaw: String
    var finding: Finding?
    var evidence: Evidence?

    var relationType: RelationType {
        get { RelationType(rawValue: relationTypeRaw) ?? .context }
        set { relationTypeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), relationType: RelationType, finding: Finding, evidence: Evidence) {
        self.id = id
        self.relationTypeRaw = relationType.rawValue
        self.finding = finding
        self.evidence = evidence
    }

    /// Convenience for building Export DTOs.
    var evidenceShortCode: String? { evidence?.shortCode }
    var evidenceText: String { evidence?.text ?? "" }
    var evidenceLocation: String { evidence?.locationNote ?? "" }
}