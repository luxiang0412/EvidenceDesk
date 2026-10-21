import Foundation
import SwiftData
import Testing
@testable import EvidenceDesk

/// Verifies data survives an app restart: writes to an isolated on-disk
/// store, re-opens a brand-new container on the same store, and checks the
/// data is still there with all relationships intact.
@MainActor
struct PersistenceRestartTests {
    let root: URL

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Restart-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeService() throws -> PersistenceService {
        let container = try ModelContainerFactory.makeIsolated(storageRoot: root)
        let attachments = AttachmentStore(root: root.appendingPathComponent("Attachments"))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return PersistenceService(modelContext: context, attachments: attachments)
    }

    @Test func caseEvidenceFindingAndPDFPageSurviveRestart() throws {
        defer { try? FileManager.default.removeItem(at: root) }

        // ---- Session 1 ----
        let s1 = try makeService()
        let researchCase = try s1.createCase(title: "Restart case", researchQuestion: "Persists?")
        let src = try s1.createURLSource(in: researchCase, url: URL(string: "https://r.example")!, title: "Src")
        let evidence = try s1.createEvidence(in: researchCase, text: "quote p.3", type: .fact, source: src,
                                             locationNote: "p. 3", pageNumber: 3, userNotes: "keep me")
        let finding = try s1.createFinding(in: researchCase, title: "Find", body: "body", status: .active, uncertainty: "")
        try s1.linkEvidence(evidence, to: finding, relation: .supports)
        _ = try s1.createTimelineEvent(in: researchCase, title: "Event", detail: "", date: Date(timeIntervalSince1970: 5000), precision: .exact, source: nil, notes: "")

        // ---- "Restart": fresh container/service on the same store ----
        let s2 = try makeService()
        let cases = try s2.modelContext.fetch(FetchDescriptor<ResearchCase>())
        #expect(cases.count == 1)
        let reloaded = cases[0]
        #expect(reloaded.id == researchCase.id)
        #expect(reloaded.title == "Restart case")
        #expect(reloaded.researchQuestion == "Persists?")
        #expect(reloaded.sources.count == 1)
        #expect(reloaded.evidences.count == 1)
        #expect(reloaded.findings.count == 1)
        #expect(reloaded.timelineEvents.count == 1)

        let reloadedEvidence = reloaded.evidences[0]
        #expect(reloadedEvidence.text == "quote p.3")
        #expect(reloadedEvidence.pageNumber == 3, "PDF page must persist across restarts")
        #expect(reloadedEvidence.locationNote == "p. 3")
        #expect(reloadedEvidence.source?.id == src.id)
        #expect(reloaded.findings[0].links.first?.relationType == .supports)
        #expect(reloaded.findings[0].links.first?.evidence?.id == evidence.id)
    }

    @Test func uniqueStoresAreIndependent() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let otherRoot = root.appendingPathComponent("other", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let container1 = try ModelContainerFactory.makeIsolated(storageRoot: root)
        let context1 = ModelContext(container1)
        let svc1 = PersistenceService(modelContext: context1,
                                      attachments: AttachmentStore(root: root.appendingPathComponent("Attachments")))
        _ = try svc1.createCase(title: "Only in root")

        let container2 = try ModelContainerFactory.makeIsolated(storageRoot: otherRoot)
        let context2 = ModelContext(container2)
        let svc2 = PersistenceService(modelContext: context2,
                                      attachments: AttachmentStore(root: otherRoot.appendingPathComponent("Attachments")))
        _ = try svc2.createCase(title: "Only in other")

        let titles1 = try context1.fetch(FetchDescriptor<ResearchCase>()).map(\.title)
        let titles2 = try context2.fetch(FetchDescriptor<ResearchCase>()).map(\.title)
        #expect(titles1 == ["Only in root"])
        #expect(titles2 == ["Only in other"])
        #expect(titles1 != titles2)
    }
}