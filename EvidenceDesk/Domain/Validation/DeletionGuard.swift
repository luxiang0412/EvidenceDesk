import Foundation
import SwiftData

/// Answers the impact questions needed before destructive operations, so the
/// UI can show honest, specific confirmations instead of silently cascading.
struct DeletionGuard {
    let attachedEvidenceCount: Int
    let findingLinkCount: Int

    var hasAttachedEvidence: Bool { attachedEvidenceCount > 0 }
    var hasFindingLinks: Bool { findingLinkCount > 0 }

    /// Inspects a source to be deleted.
    static func impact(of source: Source) -> DeletionGuard {
        DeletionGuard(
            attachedEvidenceCount: source.evidences.count,
            findingLinkCount: source.evidences.reduce(0) { $0 + $1.findingLinks.count }
        )
    }

    /// Inspects an evidence to be deleted.
    static func impact(of evidence: Evidence) -> DeletionGuard {
        DeletionGuard(
            attachedEvidenceCount: 0,
            findingLinkCount: evidence.findingLinks.count
        )
    }

    /// Inspects a case to be deleted.
    static func impact(of researchCase: ResearchCase) -> DeletionGuard {
        DeletionGuard(
            attachedEvidenceCount: researchCase.evidences.count,
            findingLinkCount: researchCase.findings.reduce(0) { $0 + $1.links.count }
            + researchCase.evidences.reduce(0) { $0 + $1.findingLinks.count }
        )
    }
}