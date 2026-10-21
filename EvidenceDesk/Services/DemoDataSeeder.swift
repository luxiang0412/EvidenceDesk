import Foundation
import SwiftData

/// Creates a synthetic research case for visual QA. Only used with the
/// `--seed-demo` launch flag (which should always be combined with
/// `--test-storage`); never touches real user data.
@MainActor
enum DemoDataSeeder {
    static func seedIfRequested(persistence: PersistenceService) throws {
        guard ProcessInfo.processInfo.arguments.contains("--seed-demo") else { return }
        let cases = try persistence.modelContext.fetch(FetchDescriptor<ResearchCase>())
        guard cases.isEmpty else { return }

        let researchCase = try persistence.createCase(
            title: "Local Transit Tender — Sources Review",
            researchQuestion: "Did the recent transit tender give fair access to new suppliers, or was it designed around incumbent bidders?",
            researchScope: "Review the July announcement, tender documents, committee minutes and the supplier complaint; verify claims of short bidding windows and ambiguous scoring."
        )

        // URL source
        _ = try persistence.createURLSource(
            in: researchCase,
            url: URL(string: "https://example.gov/news/transit-tender-2026")!,
            title: "City announces transit tender for Line 7",
            publisher: "Example City Transit",
            notes: "Primary announcement. Cross-check the claimed deadline."
        )

        // Text source with a quote
        let createdText = try persistence.createTextSourceFixture(in: researchCase)

        // PDF source (generated fixture, QA only)
        let pdfSource = try persistence.createPDFSourceFixture(in: researchCase)
        _ = pdfSource

        // Evidence
        let e1 = try persistence.createEvidence(
            in: researchCase,
            text: "Firms must submit bids within 14 days of publication; late submissions are not accepted under any circumstance.",
            type: .fact,
            source: createdText.source,
            locationNote: "§ 3.2, p. 4",
            pageNumber: nil,
            userNotes: "Compare with 2024 tender which allowed 30 days."
        )
        let e2 = try persistence.createEvidence(
            in: researchCase,
            text: "A supplier complaint claims the scoring matrix was shown only during a 30-minute Q&A and never published.",
            type: .hypothesis,
            source: createdText.source,
            locationNote: "p. 7",
            pageNumber: nil,
            userNotes: ""
        )
        _ = try persistence.createEvidence(
            in: researchCase,
            text: "The committee minutes record an objection about 'unusually short preparation time' raised by two bidders.",
            type: .fact,
            source: createdText.source,
            locationNote: "Minute 12",
            pageNumber: nil,
            userNotes: ""
        )
        _ = try persistence.createEvidence(
            in: researchCase,
            text: "Whether the 14-day window alone caused harm, or whether vendors were informally warned earlier, remains unresolved.",
            type: .unresolved,
            source: nil,
            locationNote: "",
            pageNumber: nil,
            userNotes: "Personal note — needs an interview source.",
            caseIsRequired: false
        )

        // Findings
        let f1 = try persistence.createFinding(
            in: researchCase,
            title: "The bidding window appears significantly shorter than previous cycles",
            body: "The announcement gives 14 days versus 30 days in the 2024 cycle. This compresses vendor preparation time and favours firms already engaged on the corridor.",
            status: .active,
            uncertainty: "The 2024 window is from memory; confirm with the archived notice before relying on the comparison."
        )
        try persistence.linkEvidence(e1, to: f1, relation: .supports)
        try persistence.linkEvidence(e2, to: f1, relation: .contradicts)

        // Timeline
        _ = try persistence.createTimelineEvent(
            in: researchCase,
            title: "Tender announced",
            detail: "Public notice posted on city procurement portal.",
            date: Date().addingTimeInterval(-21 * 86400),
            precision: .exact,
            source: nil,
            notes: ""
        )
        _ = try persistence.createTimelineEvent(
            in: researchCase,
            title: "Supplier complaint filed",
            detail: "Formal complaint regarding unpublished scoring matrix.",
            date: Date().addingTimeInterval(-10 * 86400),
            precision: .exact,
            source: nil,
            notes: ""
        )
        _ = try persistence.createTimelineEvent(
            in: researchCase,
            title: "Decision expected",
            detail: "Award decision due; date not yet published.",
            date: nil,
            precision: .unknown,
            source: nil,
            notes: ""
        )
    }
}

/// Fixture used to stand up a text source without shipping a fixture file.
extension PersistenceService {
    /// Creates a PDF source whose attachment is generated inline (QA only).
    func createPDFSourceFixture(in researchCase: ResearchCase) throws -> Source {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-seed-\\\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("line7-spec.pdf")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

        var text = "Line 7 Rolling Stock Specification\n\n"
        text += "1. Overview\nThe corridor requires 18 articulated vehicles with a minimum capacity of 160 passengers.\n\n"
        text += "2. Submission timing\nFirms must submit bids within 14 days of publication; late submissions are not accepted under any circumstance.\n\n"
        text += "3. Evaluation\nThe evaluation matrix considers price (40%), technical capability (40%) and local presence (20%).\n\n"
        text += "4. Reference case\nThe 2024 cycle allowed a 30-day window. Bidders should note the difference.\n\n"
        text += "5. Complaint register\nA supplier complaint claims the scoring matrix was shown only during a 30-minute Q&A and never published.\n\n"
        text += "6. Contact\nProcurement Office, Example City Transit.\n"
        try? PDFFixtureWriter.write(text: text, to: file)
        let source = try importFileSource(in: researchCase, sourceURL: file, sourceType: .pdf,
                                          title: "Line 7 tender specification (synthetic PDF)",
                                          userNotes: "QA fixture PDF generated at seed time.")
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        return source
    }

    /// Creates a text source whose attachment is generated inline (QA only).
    func createTextSourceFixture(in researchCase: ResearchCase) throws -> (source: Source, text: String) {
        let text = """
        # Tender notice — Line 7 rolling stock

        § 3.2 Submission
        Firms must submit bids within 14 days of publication; late submissions are not accepted under any circumstance.

        § 4 Scoring
        The evaluation matrix considers price (40%), technical capability (40%) and local presence (20%).

        p. 7 — Notes
        A supplier complaint claims the scoring matrix was shown only during a 30-minute Q&A and never published.
        """
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let file = testDir.appendingPathComponent("tender-notes.md")
        try text.write(to: file, atomically: true, encoding: .utf8)
        let source = try importFileSource(in: researchCase, sourceURL: file, sourceType: .text,
                                          title: "Line 7 tender notes (synthetic fixture)",
                                          userNotes: "Synthetic QA fixture.")
        try? FileManager.default.removeItem(at: testDir)
        return (source, text)
    }
}