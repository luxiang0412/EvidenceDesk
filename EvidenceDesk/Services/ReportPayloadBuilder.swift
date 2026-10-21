import Foundation

/// Maps SwiftData models to the value-type `ReportPayload` used by the
/// exporter. Kept separate from the generator for testability.
@MainActor
enum ReportPayloadBuilder {
    static func build(for researchCase: ResearchCase) -> ReportPayload {
        // Sources sorted by short code.
        let sources = researchCase.sources.sorted { $0.shortCode < $1.shortCode }
        let sourceIndex: [UUID: ReportPayload.SourceInfo] = Dictionary(uniqueKeysWithValues: sources.map {
            ($0.id, ReportPayload.SourceInfo(
                ref: $0.shortCode,
                title: $0.title,
                sourceType: $0.sourceType,
                urlString: $0.urlString,
                attachmentRelativePath: $0.attachmentRelativePath,
                publisher: $0.publisher,
                publishedDate: $0.publishedDate,
                addedAt: $0.addedAt,
                isMissing: $0.attachmentIsMissing,
                userNotes: $0.userNotes
            ))
        })

        let evidences = researchCase.evidences.sorted { $0.shortCode < $1.shortCode }
        let evidenceIndex: [UUID: ReportPayload.EvidenceInfo] = Dictionary(uniqueKeysWithValues: evidences.map {
            ($0.id, ReportPayload.EvidenceInfo(
                ref: $0.shortCode,
                text: $0.text,
                type: $0.evidenceType,
                sourceRef: $0.source?.shortCode,
                locationNote: $0.locationNote,
                pageNumber: $0.pageNumber,
                userNotes: $0.userNotes
            ))
        })

        let findings = researchCase.findings.sorted { $0.shortCode < $1.shortCode }
        let findingInfos: [ReportPayload.FindingInfo] = findings.map { finding in
            var byRelation: [RelationType: [String]] = [:]
            for link in finding.links {
                guard let evidence = link.evidence else { continue }
                let ref = evidence.shortCode
                if byRelation[link.relationType] == nil { byRelation[link.relationType] = [] }
                byRelation[link.relationType]?.append(ref)
            }
            for (key, value) in byRelation {
                byRelation[key] = value.sorted()
            }
            return ReportPayload.FindingInfo(
                ref: finding.shortCode,
                title: finding.title,
                body: finding.body,
                status: finding.status,
                uncertainty: finding.uncertainty,
                evidenceRefs: byRelation
            )
        }

        let timeline = researchCase.timelineEvents.map { event in
            ReportPayload.TimelineEventInfo(
                title: event.title,
                detail: event.detail,
                date: event.date,
                precision: event.datePrecision,
                sourceRef: event.source?.shortCode,
                notes: event.notes
            )
        }

        // Unresolved notes: evidence explicitly typed unresolved plus manually
        // flagged uncertainty from findings.
        var unresolvedNotes: [String] = []
        for finding in findings where !finding.uncertainty.isEmpty {
            unresolvedNotes.append("\(finding.shortCode) — \(finding.title): \(finding.uncertainty)")
        }

        return ReportPayload(
            caseInfo: ReportPayload.CaseInfo(
                shortCode: researchCase.shortCode,
                title: researchCase.title,
                question: researchCase.researchQuestion,
                scope: researchCase.researchScope
            ),
            sources: sources.map { sourceIndex[$0.id]! },
            evidences: evidences.map { evidenceIndex[$0.id]! },
            findings: findingInfos,
            timeline: timeline,
            generatedAt: Date(),
            unresolvedNotes: unresolvedNotes
        )
    }
}