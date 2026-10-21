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
@MainActor
struct SourceDeletionPolicyTests {
    /// Deleting a source together with its evidence removes exactly that
    /// evidence and leaves unrelated notes untouched. Pairs with the UI test
    /// that verifies both policies are offered in the confirmation dialog.
    @Test func deleteSourceAlsoRemovesEvidence() throws {
        let persistence = try PersistenceService.makeInMemory()
        let researchCase = try persistence.createCase(title: "delete both")
        let source = try persistence.createURLSource(in: researchCase,
                                                     url: URL(string: "https://example.gov/d")!,
                                                     title: "Doc")
        let linked = try persistence.createEvidence(in: researchCase, text: "linked", type: .fact,
                                                    source: source, locationNote: "", pageNumber: nil,
                                                    userNotes: "")
        let finding = try persistence.createFinding(in: researchCase, title: "F", body: "",
                                                    status: .active, uncertainty: "")
        try persistence.linkEvidence(linked, to: finding, relation: .supports)
        let note = try persistence.createEvidence(in: researchCase, text: "note", type: .hypothesis,
                                                  source: nil, locationNote: "", pageNumber: nil,
                                                  userNotes: "", caseIsRequired: false)

        let impact = DeletionGuard.impact(of: source)
        #expect(impact.attachedEvidenceCount == 1)
        #expect(impact.findingLinkCount == 1)

        try persistence.deleteSource(source, keepEvidence: false)

        #expect(researchCase.sources.isEmpty)
        #expect(researchCase.evidences.count == 1, "only the unrelated note remains")
        #expect(researchCase.evidences.first?.id == note.id)
        #expect(finding.links.isEmpty, "links to deleted evidence must not dangle")
        #expect(researchCase.evidences.contains { $0.id == linked.id } == false)
    }
}

/// Library search/archive filtering, tested without a UI.
@MainActor
struct CaseFilterTests {
    @Test func filtersByArchiveState() throws {
        let persistence = try PersistenceService.makeInMemory()
        let active = try persistence.createCase(title: "Active case", researchQuestion: "Q1")
        let archived = try persistence.createCase(title: "Archived case", researchQuestion: "Q2")
        try persistence.setArchived(archived, archived: true)

        let visible = CaseFilter.apply(to: [active, archived], showArchived: false, query: "")
        #expect(visible.map(\.id) == [active.id])

        let archivedOnly = CaseFilter.apply(to: [active, archived], showArchived: true, query: "")
        #expect(archivedOnly.map(\.id) == [archived.id])
    }

    @Test func searchesCodeTitleQuestionAndScope() throws {
        let persistence = try PersistenceService.makeInMemory()
        let transit = try persistence.createCase(
            title: "Transit tender",
            researchQuestion: "Was the window fair?",
            researchScope: "Procurement documents"
        )
        let housing = try persistence.createCase(title: "Housing policy", researchQuestion: "Rent caps?")

        let all = [transit, housing]
        #expect(CaseFilter.apply(to: all, showArchived: false, query: "transit").map(\.id) == [transit.id])
        #expect(CaseFilter.apply(to: all, showArchived: false, query: "FAIR").map(\.id) == [transit.id])
        #expect(CaseFilter.apply(to: all, showArchived: false, query: "procurement").map(\.id) == [transit.id])
        #expect(CaseFilter.apply(to: all, showArchived: false, query: transit.shortCode).map(\.id) == [transit.id])
    }

    @Test func searchWithNoMatchReturnsEmpty() throws {
        let persistence = try PersistenceService.makeInMemory()
        let only = try persistence.createCase(title: "Only case")
        #expect(CaseFilter.apply(to: [only], showArchived: false, query: "zzzz-nothing").isEmpty)
    }

    @Test func blankQueryReturnsEverythingInScope() throws {
        let persistence = try PersistenceService.makeInMemory()
        let a = try persistence.createCase(title: "A")
        let b = try persistence.createCase(title: "B")
        #expect(CaseFilter.apply(to: [a, b], showArchived: false, query: "   ").count == 2)
    }
}

/// Language preference behaviour, tested without launching the UI.
@MainActor
struct LanguageSettingsTests {
    /// An isolated defaults suite plus its name, so tests can inspect exactly
    /// what this code wrote (the host app's own domain may also contain
    /// `AppleLanguages`, which must not leak into assertions).
    private func defaults() -> (defaults: UserDefaults, suite: String) {
        let suite = "EvidenceDeskTests.language.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return (d, suite)
    }

    @Test func defaultChoiceIsSystem() {
        let d = defaults().defaults
        let settings = LanguageSettings(defaults: d)
        #expect(settings.language == .system)
    }

    @Test func choosingChineseWritesAppleLanguages() {
        let d = defaults().defaults
        let settings = LanguageSettings(defaults: d)
        settings.set(.simplifiedChinese)
        #expect(d.stringArray(forKey: "AppleLanguages") == ["zh-Hans"])
        #expect(d.string(forKey: LanguageSettings.choiceKey) == "zh-Hans")
        #expect(settings.language == .simplifiedChinese)
    }

    @Test func choosingSystemRemovesOverride() {
        let (d, suite) = defaults()
        d.set(["zh-Hans"], forKey: "AppleLanguages")
        let settings = LanguageSettings(defaults: d)
        settings.set(.system)
        // The override must be gone from what this code controls.
        let written = d.persistentDomain(forName: suite) ?? [:]
        #expect(written["AppleLanguages"] == nil, "the app must not keep pinning a language")
    }

    @Test func relaunchDetection() {
        // No relaunch needed when the effective list already matches.
        #expect(LanguageSettings.needsRelaunch(choice: .simplifiedChinese, effective: ["zh-Hans"]) == false)
        #expect(LanguageSettings.needsRelaunch(choice: .english, effective: ["en"]) == false)
        // Mismatch means the change is still pending.
        #expect(LanguageSettings.needsRelaunch(choice: .simplifiedChinese, effective: ["en"]) == true)
        #expect(LanguageSettings.needsRelaunch(choice: .english, effective: ["zh-Hans"]) == true)
        // System + a leftover single-language override is pending.
        #expect(LanguageSettings.needsRelaunch(choice: .system, effective: ["zh-Hans"]) == true)
        // System with the real system list is fine.
        #expect(LanguageSettings.needsRelaunch(choice: .system, effective: ["en", "zh-Hans"]) == false)
        #expect(LanguageSettings.needsRelaunch(choice: .system, effective: []) == false)
    }

    @Test func choiceRoundTripsThroughDefaults() {
        let d = defaults().defaults
        LanguageSettings(defaults: d).set(.simplifiedChinese)
        let reloaded = LanguageSettings(defaults: d)
        #expect(reloaded.language == .simplifiedChinese)
    }
}

/// The compiled String Catalog must actually contain the Chinese translations.
struct LocalizationCatalogTests {
    private func bundle(for language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    @Test func chineseBundleTranslatesCoreStrings() {
        guard let zh = bundle(for: "zh-Hans") else {
            Issue.record("zh-Hans.lproj missing from the app bundle")
            return
        }
        #expect(zh.localizedString(forKey: "Sources", value: nil, table: nil) == "来源")
        #expect(zh.localizedString(forKey: "Evidence", value: nil, table: nil) == "证据")
        #expect(zh.localizedString(forKey: "Fact", value: nil, table: nil) == "事实")
        #expect(zh.localizedString(forKey: "Saved", value: nil, table: nil) == "已保存")
        #expect(zh.localizedString(forKey: "Research Question", value: nil, table: nil) == "研究问题")
    }

    @Test func englishFallsBackToTheKey() {
        guard let en = bundle(for: "en") else {
            Issue.record("en.lproj missing from the app bundle")
            return
        }
        #expect(en.localizedString(forKey: "Sources", value: nil, table: nil) == "Sources")
    }

    @Test func appDeclaresBothLocalizations() {
        let localizations = Set(Bundle.main.localizations)
        #expect(localizations.contains("en"))
        #expect(localizations.contains("zh-Hans"))
    }
}
