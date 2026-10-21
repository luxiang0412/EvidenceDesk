import Foundation
import SwiftData
import Testing
@testable import EvidenceDesk

/// Core model/relationship/persistence rules over an in-memory container.
@MainActor
struct PersistenceTests {
    let persistence: PersistenceService

    init() throws {
        persistence = try PersistenceService.makeInMemory()
    }

    // MARK: - Cases

    @Test func createCasesGetStableCodes() throws {
        let c1 = try persistence.createCase(title: "Alpha", researchQuestion: "Q?")
        let c2 = try persistence.createCase(title: "Beta")
        #expect(c1.shortCode == "C-001")
        #expect(c2.shortCode == "C-002")
        #expect(c1.id != c2.id)
        #expect(c1.researchQuestion == "Q?")
    }

    @Test func emptyCaseTitleRejected() throws {
        var didThrow = false
        do {
            _ = try persistence.createCase(title: "   ")
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test func archiveAndRestoreCase() throws {
        let c = try persistence.createCase(title: "To archive")
        #expect(!c.isArchived)
        try persistence.setArchived(c, archived: true)
        #expect(c.isArchived)
        try persistence.setArchived(c, archived: false)
        #expect(!c.isArchived)
    }

    @Test func updateCaseRefreshesUpdatedAt() throws {
        let c = try persistence.createCase(title: "Edit me")
        let before = c.updatedAt
        try persistence.updateCase(c, title: "Edited", question: "New Q", scope: "")
        #expect(c.title == "Edited")
        #expect(c.updatedAt >= before)
    }

    // MARK: - Sources

    @Test func createURLSourceWithValidatedURL() throws {
        let c = try persistence.createCase(title: "URL case")
        let s = try persistence.createURLSource(in: c, url: URL(string: "https://x.example/a")!, title: "X")
        #expect(s.shortCode == "S-001")
        #expect(s.sourceType == .url)
        #expect(s.isLinkOnly)
        #expect(s.case === c)
    }

    @Test func importFilesUseUUIDAttachmentPaths() throws {
        let c = try persistence.createCase(title: "Files")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Import-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f1 = dir.appendingPathComponent("same-name.md")
        let f2 = dir.appendingPathComponent("copy.md")
        try (try String("one").data(using: .utf8)!).write(to: f1)
        try (try String("two").data(using: .utf8)!).write(to: f2)

        let s1 = try persistence.importFileSource(in: c, sourceURL: f1, sourceType: .text, title: "T1")
        let s2 = try persistence.importFileSource(in: c, sourceURL: f2, sourceType: .text, title: "T2")
        // Same-name files never collide thanks to UUID directories.
        #expect(s1.attachmentRelativePath != s2.attachmentRelativePath)
        #expect(persistence.attachments.fileExists(relativePath: s1.attachmentRelativePath!))
        #expect(persistence.attachments.fileExists(relativePath: s2.attachmentRelativePath!))
        #expect(s1.originalFilename == "same-name.md")
    }

    // MARK: - Evidence

    @Test func evidenceRequiresSourceUnlessExplicitNote() throws {
        let c = try persistence.createCase(title: "E case")
        var didThrow = false
        do {
            _ = try persistence.createEvidence(in: c, text: "quote", type: .fact, source: nil,
                                               locationNote: "", pageNumber: nil, userNotes: "")
        } catch {
            didThrow = true
        }
        #expect(didThrow, "evidence must link a source by default")

        let note = try persistence.createEvidence(in: c, text: "my note", type: .hypothesis, source: nil,
                                                  locationNote: "", pageNumber: nil, userNotes: "", caseIsRequired: false)
        #expect(note.source == nil)
    }

    @Test func evidenceCodesAndFields() throws {
        let c = try persistence.createCase(title: "E codes")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://e.example")!, title: "S")
        let e1 = try persistence.createEvidence(in: c, text: "first", type: .fact, source: src,
                                                locationNote: "p. 3", pageNumber: 3, userNotes: "")
        let e2 = try persistence.createEvidence(in: c, text: "second", type: .interpretation, source: src,
                                                locationNote: "", pageNumber: nil, userNotes: "")
        #expect(e1.shortCode == "E-001")
        #expect(e2.shortCode == "E-002")
        #expect(e1.pageNumber == 3)
        #expect(e1.source === src)
    }

    @Test func emptyEvidenceTextRejected() throws {
        let c = try persistence.createCase(title: "Empty E")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://e.example")!, title: "S")
        var didThrow = false
        do {
            _ = try persistence.createEvidence(in: c, text: "   ", type: .fact, source: src,
                                               locationNote: "", pageNumber: nil, userNotes: "")
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    // MARK: - Findings & links

    @Test func findingSupportsMultipleLinkedEvidence() throws {
        let c = try persistence.createCase(title: "F links")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://f.example")!, title: "S")
        let support = try persistence.createEvidence(in: c, text: "supporting", type: .fact, source: src,
                                                     locationNote: "", pageNumber: nil, userNotes: "")
        let against = try persistence.createEvidence(in: c, text: "against", type: .fact, source: src,
                                                     locationNote: "", pageNumber: nil, userNotes: "")
        let finding = try persistence.createFinding(in: c, title: "Conclusion", body: "body", status: .active, uncertainty: "")
        try persistence.linkEvidence(support, to: finding, relation: .supports)
        try persistence.linkEvidence(against, to: finding, relation: .contradicts)

        #expect(finding.links.count == 2)
        #expect(finding.links.contains { $0.evidence?.id == support.id && $0.relationType == .supports })
        #expect(finding.links.contains { $0.evidence?.id == against.id && $0.relationType == .contradicts })
    }

    @Test func duplicateLinkPrevented() throws {
        let c = try persistence.createCase(title: "dup")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://d.example")!, title: "S")
        let evidence = try persistence.createEvidence(in: c, text: "text", type: .fact, source: src,
                                                      locationNote: "", pageNumber: nil, userNotes: "")
        let finding = try persistence.createFinding(in: c, title: "F", body: "", status: .draft, uncertainty: "")
        try persistence.linkEvidence(evidence, to: finding, relation: .supports)
        try persistence.linkEvidence(evidence, to: finding, relation: .supports)
        #expect(finding.links.count == 1, "implicit duplicate links must not be created")
    }

    @Test func changeRelationAndUnlink() throws {
        let c = try persistence.createCase(title: "rel")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://r.example")!, title: "S")
        let evidence = try persistence.createEvidence(in: c, text: "text", type: .fact, source: src,
                                                      locationNote: "", pageNumber: nil, userNotes: "")
        let finding = try persistence.createFinding(in: c, title: "F", body: "", status: .draft, uncertainty: "")
        try persistence.linkEvidence(evidence, to: finding, relation: .supports)
        let link = finding.links.first!
        try persistence.changeLinkRelation(link, relation: .context)
        #expect(link.relationType == .context)
        try persistence.unlinkEvidence(link)
        #expect(finding.links.isEmpty)
    }

    @Test func deleteEvidenceRemovesItsLinks() throws {
        let c = try persistence.createCase(title: "delE")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://de.example")!, title: "S")
        let evidence = try persistence.createEvidence(in: c, text: "text", type: .fact, source: src,
                                                      locationNote: "", pageNumber: nil, userNotes: "")
        let finding = try persistence.createFinding(in: c, title: "F", body: "", status: .draft, uncertainty: "")
        try persistence.linkEvidence(evidence, to: finding, relation: .supports)
        try persistence.deleteEvidence(evidence)
        #expect(finding.links.isEmpty)
        #expect(c.evidences.isEmpty)
    }

    // MARK: - Deletion guard & source deletion

    @Test func deletionGuardReportsImpact() throws {
        let c = try persistence.createCase(title: "guard")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://g.example")!, title: "S")
        let evidence = try persistence.createEvidence(in: c, text: "text", type: .fact, source: src,
                                                      locationNote: "", pageNumber: nil, userNotes: "")
        let finding = try persistence.createFinding(in: c, title: "F", body: "", status: .draft, uncertainty: "")
        try persistence.linkEvidence(evidence, to: finding, relation: .supports)

        let impact = DeletionGuard.impact(of: src)
        #expect(impact.attachedEvidenceCount == 1)
        #expect(impact.findingLinkCount == 1)
        #expect(impact.hasAttachedEvidence)
    }

    @Test func deleteSourceKeepingEvidenceDetaches() throws {
        let c = try persistence.createCase(title: "delS keep")
        let src = try persistence.createURLSource(in: c, url: URL(string: "https://k.example")!, title: "S")
        let evidence = try persistence.createEvidence(in: c, text: "text", type: .fact, source: src,
                                                      locationNote: "", pageNumber: nil, userNotes: "")
        try persistence.deleteSource(src, keepEvidence: true)
        #expect(evidence.source == nil, "evidence survives as an unlinked note")
        #expect(c.evidences.count == 1)
    }

    @Test func deleteCaseDoesNotAffectOtherCases() throws {
        let a = try persistence.createCase(title: "Case A")
        let b = try persistence.createCase(title: "Case B")
        _ = try persistence.createURLSource(in: a, url: URL(string: "https://a.example")!, title: "SA")
        try persistence.deleteCase(a)
        // B and its data are untouched.
        #expect(b.sources.isEmpty)
        #expect(try persistence.modelContext.fetch(FetchDescriptor<ResearchCase>()).count == 1)
    }

    // MARK: - Timeline

    @Test func timelineEventsSortByDateWithUndatedSecluded() throws {
        let c = try persistence.createCase(title: "timeline")
        let later = try persistence.createTimelineEvent(in: c, title: "Later", detail: "", date: Date(timeIntervalSince1970: 2000), precision: .exact, source: nil, notes: "")
        let earlier = try persistence.createTimelineEvent(in: c, title: "Earlier", detail: "", date: Date(timeIntervalSince1970: 1000), precision: .exact, source: nil, notes: "")
        let undated = try persistence.createTimelineEvent(in: c, title: "Mystery", detail: "", date: nil, precision: .unknown, source: nil, notes: "")

        let events = c.timelineEvents
        let (dated, undatedOut) = TimelineSorting.partition(events, date: { $0.date }, precision: { $0.datePrecision })
        #expect(dated.map(\.title) == ["Earlier", "Later"])
        #expect(undatedOut.map(\.title) == ["Mystery"])

        // Same-day stability
        let d1 = try persistence.createTimelineEvent(in: c, title: "Same A", detail: "", date: Date(timeIntervalSince1970: 3000), precision: .exact, source: nil, notes: "")
        let d2 = try persistence.createTimelineEvent(in: c, title: "Same B", detail: "", date: Date(timeIntervalSince1970: 3000), precision: .exact, source: nil, notes: "")
        let sameDay = TimelineSorting.sortSameDayStably([d2, d1], date: { $0.date }, createdAt: { $0.createdAt })
        #expect(sameDay.last?.title == "Same B")
    }

    @Test func timelineEventRequiresTitle() throws {
        let c = try persistence.createCase(title: "empty event")
        var didThrow = false
        do {
            _ = try persistence.createTimelineEvent(in: c, title: " ", detail: "", date: nil, precision: .unknown, source: nil, notes: "")
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }
}