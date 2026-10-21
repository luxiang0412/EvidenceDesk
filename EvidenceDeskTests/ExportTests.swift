import Foundation
import SwiftData
import Testing
@testable import EvidenceDesk

@MainActor
struct ExportTests {
    let persistence: PersistenceService

    init() throws {
        persistence = try PersistenceService.makeInMemory()
    }

    // MARK: - Markdown generation (pure)

    private func makeSamplePayload() -> ReportPayload {
        let now = Date(timeIntervalSince1970: 1700000000)
        return ReportPayload(
            caseInfo: .init(shortCode: "C-001", title: "The Transit Tender", question: "Was the window fair?", scope: "Review the notice and complaints."),
            sources: [
                .init(ref: "S-001", title: "Announcement", sourceType: .url, urlString: "https://example.gov/news", attachmentRelativePath: nil, publisher: "City", publishedDate: now, addedAt: now, isMissing: false, userNotes: ""),
                .init(ref: "S-002", title: "Tender Notes", sourceType: .text, urlString: nil, attachmentRelativePath: "S-002/original.md", publisher: "", publishedDate: nil, addedAt: now, isMissing: false, userNotes: "")
            ],
            evidences: [
                .init(ref: "E-001", text: "14 days window", type: .fact, sourceRef: "S-001", locationNote: "p. 3", pageNumber: 3, userNotes: ""),
                .init(ref: "E-002", text: "An open #question > in the text", type: .fact, sourceRef: "S-002", locationNote: "", pageNumber: nil, userNotes: "")
            ],
            findings: [
                .init(ref: "F-001", title: "Short window", body: "Body.", status: .active, uncertainty: "Verify 2024 window.", evidenceRefs: [.supports: ["E-001"], .contradicts: ["E-002"]])
            ],
            timeline: [
                .init(title: "Announced", detail: "Notice posted.", date: now, precision: .exact, sourceRef: "S-001", notes: ""),
                .init(title: "Unknown date event", detail: "", date: nil, precision: .unknown, sourceRef: nil, notes: "")
            ],
            generatedAt: now,
            unresolvedNotes: []
        )
    }

    @Test func citationFormat() {
        let e = ReportPayload.EvidenceInfo(ref: "E-002", text: "x", type: .fact, sourceRef: "S-001", locationNote: "p. 3", pageNumber: 3, userNotes: "")
        #expect(MarkdownReportExporter.citation(for: e) == "[E-002, S-001, p. 3]")
        let e2 = ReportPayload.EvidenceInfo(ref: "E-001", text: "x", type: .fact, sourceRef: "S-001", locationNote: "", pageNumber: nil, userNotes: "")
        #expect(MarkdownReportExporter.citation(for: e2) == "[E-001, S-001]")
    }

    @Test func reportContainsCoreSections() {
        let md = MarkdownReportExporter.generate(makeSamplePayload())
        #expect(md.contains("# The Transit Tender"))
        #expect(md.contains("## Research Question"))
        #expect(md.contains("Was the window fair?"))
        #expect(md.contains("## Findings"))
        #expect(md.contains("## Evidence"))
        #expect(md.contains("## Timeline"))
        #expect(md.contains("## Sources"))
        #expect(md.contains("## Unresolved Issues and Uncertainties"))
        #expect(md.contains("Case C-001"))
    }

    @Test func reportShowsRelationGroups() {
        let md = MarkdownReportExporter.generate(makeSamplePayload())
        #expect(md.contains("**Supporting evidence:**"))
        #expect(md.contains("**Contradicting evidence:**"))
        #expect(md.contains("- E-001"))
        #expect(md.contains("- E-002"))
    }

    @Test func emptyCaseStillProducesReadableReport() {
        let payload = ReportPayload(
            caseInfo: .init(shortCode: "C-002", title: "Empty", question: "", scope: ""),
            sources: [], evidences: [], findings: [], timeline: [],
            generatedAt: Date(), unresolvedNotes: []
        )
        let md = MarkdownReportExporter.generate(payload)
        #expect(md.contains("# Empty"))
        #expect(md.contains("_No findings recorded._"))
        #expect(md.contains("_No evidence recorded._"))
        #expect(md.contains("_No timeline events recorded._"))
        #expect(md.contains("_No sources recorded._"))
        #expect(md.contains("_None recorded._"))
    }

    @Test func everyDisplayedReferenceResolvesInSourceList() {
        let payload = makeSamplePayload()
        let md = MarkdownReportExporter.generate(payload)
        // Assert citation source refs exist in the Sources section.
        let sourceList = payload.sources.map(\.ref)
        for evidence in payload.evidences {
            if let sourceRef = evidence.sourceRef {
                #expect(sourceList.contains(sourceRef), "reference \(sourceRef) must be in the source list")
            }
        }
        // The generated "Sources:" section underscores each source ref.
        for source in payload.sources {
            #expect(md.contains("**\(source.ref) —"))
        }
    }

    @Test func urlSourcesBecomeClickableLinksAndAttachmentsUseRelativePaths() {
        let payload = makeSamplePayload()
        let md = MarkdownReportExporter.generate(payload)
        #expect(md.contains("[https://example.gov/news](https://example.gov/news)"))
        #expect(md.contains("Attachment: `S-002/original.md`"))
        #expect(!md.contains("file://"), "no absolute file URLs in report")
        #expect(!md.contains("/Users/"), "no host absolute paths in report")
    }

    // MARK: - Case archive bundle

    @Test func archiveExportsManifestReportAndAttachments() throws {
        let c = try persistence.createCase(title: "Bundle", researchQuestion: "Q")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("notes.md")
        try Data("# Notes".utf8).write(to: f)
        let source = try persistence.importFileSource(in: c, sourceURL: f, sourceType: .text, title: "Notes")
        let originalAttachmentURL = persistence.attachments.resolve(urlForRelativePath: source.attachmentRelativePath!)

        let exportRoot = dir.appendingPathComponent("out", isDirectory: true)
        let exporter = CaseArchiveExporter(attachments: persistence.attachments)
        try exporter.exportCase(c, to: exportRoot)

        // manifest.json exists, encodes correctly, uses relative paths.
        let manifestURL = exportRoot.appendingPathComponent("manifest.json")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ExportManifest.self, from: manifestData)
        #expect(manifest.schemaVersion == MarkdownReportExporter.schemaVersion)
        #expect(manifest.caseShortCode == "C-001")
        #expect(manifest.reportFile == "report.md")
        #expect(manifest.attachments.count == 1)
        let entry = manifest.attachments[0]
        #expect(entry.relativePath.hasPrefix("attachments/"))
        #expect(!entry.relativePath.hasPrefix("/"))

        // report.md exists and is readable.
        let reportURL = exportRoot.appendingPathComponent("report.md")
        let reportText = try String(contentsOf: reportURL, encoding: .utf8)
        #expect(reportText.contains("# Bundle"))
        #expect(reportText.contains("## Sources"))
        #expect(reportText.contains("Notes"))

        // Attachment copied INTO the bundle; original untouched.
        let copiedURL = exportRoot.appendingPathComponent(entry.relativePath)
        #expect(FileManager.default.fileExists(atPath: copiedURL.path))
        #expect(FileManager.default.fileExists(atPath: originalAttachmentURL!.path), "original must not be moved")

        // All manifest attachment relative paths are valid inside the bundle.
        for a in manifest.attachments {
            #expect(FileManager.default.fileExists(atPath: exportRoot.appendingPathComponent(a.relativePath).path))
        }

        try? FileManager.default.removeItem(at: dir)
    }

    @Test func archiveWithMissingAttachmentReportsError() throws {
        let c = try persistence.createCase(title: "Missing attachment")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-ExportMissing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("doc.pdf")
        try Data("x".utf8).write(to: f)
        let source = try persistence.importFileSource(in: c, sourceURL: f, sourceType: .pdf, title: "Doc")
        // Delete the attachment file.
        if let rel = source.attachmentRelativePath,
           let url = persistence.attachments.resolve(urlForRelativePath: rel) {
            try FileManager.default.removeItem(at: url)
        }
        let exportRoot = dir.appendingPathComponent("out", isDirectory: true)
        let exporter = CaseArchiveExporter(attachments: persistence.attachments)
        var threw: Error?
        do {
            try exporter.exportCase(c, to: exportRoot)
        } catch {
            threw = error
        }
        guard case .some(.attachmentMissing) = threw as? ExportError else {
            Issue.record("expected attachmentMissing, got \(String(describing: threw))")
            return
        }
        try? FileManager.default.removeItem(at: dir)
    }
}
/// Error-path coverage for unwritable destinations (P6 requirement).
@MainActor
struct ExportFailureTests {
    @Test func archiveToReadOnlyDirectoryFailsHonestly() throws {
        let persistence = try PersistenceService.makeInMemory()
        let researchCase = try persistence.createCase(title: "Read-only export")

        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-RO-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer {
            // Restore permissions before cleanup so the temp dir can be removed.
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
            try? FileManager.default.removeItem(at: parent)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)
        let target = parent.appendingPathComponent("out", isDirectory: true)

        let exporter = CaseArchiveExporter(attachments: persistence.attachments)
        var thrown: Error?
        do {
            try exporter.exportCase(researchCase, to: target)
        } catch {
            thrown = error
        }
        #expect(thrown != nil, "export into a read-only directory must fail, not pretend success")
        if let exportError = thrown as? ExportError {
            switch exportError {
            case .targetNotWritable, .copyFailed, .reportGenerationFailed, .manifestEncodingFailed:
                break
            case .attachmentMissing(let name):
                Issue.record("unexpected attachmentMissing for \(name)")
            }
        } else if thrown != nil {
            // A raw Cocoa permission error is also an honest failure.
        }
    }

    @Test func unopenableStoreSurfacesAsFailure() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-NoWrite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
            try? FileManager.default.removeItem(at: parent)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)

        var threw = false
        do {
            _ = try ModelContainerFactory.make(storageRoot: parent)
        } catch {
            threw = true
        }
        #expect(threw, "an unwritable store must throw so the app can show FatalErrorView")
    }
}

/// The UI's own export path (`ReportExporter`) writing real files, so the
/// artefact verified here is the artefact the app produces.
@MainActor
struct ReportExporterPathTests {
    private func workspace() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-UIExport-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func exportMarkdownWritesTheSameContentAsTheGenerator() throws {
        let persistence = try PersistenceService.makeInMemory()
        let researchCase = try persistence.createCase(title: "UI export", researchQuestion: "Q?")
        let source = try persistence.createURLSource(in: researchCase,
                                                     url: URL(string: "https://example.gov/a")!,
                                                     title: "Notice")
        _ = try persistence.createEvidence(in: researchCase, text: "14 days", type: .fact,
                                           source: source, locationNote: "p. 1", pageNumber: 1,
                                           userNotes: "")

        let dir = workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(ReportExporter.markdownFilename(for: researchCase))
        try ReportExporter.exportMarkdown(for: researchCase, to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.lastPathComponent == "C-001-report.md")
        let written = try String(contentsOf: url, encoding: .utf8)
        let expected = MarkdownReportExporter.generate(ReportPayloadBuilder.build(for: researchCase))
        // Content, ignoring the per-call generated timestamp line.
        let stripDate: (String) -> [String] = { text in
            text.components(separatedBy: "\n").filter { !$0.hasPrefix("Case C-001 · Generated") }
        }
        #expect(stripDate(written) == stripDate(expected))
        #expect(written.contains("## Sources"))
        #expect(written.contains("S-001"))
    }

    @Test func exportBundleCreatesPortableLayout() throws {
        let persistence = try PersistenceService.makeInMemory()
        let researchCase = try persistence.createCase(title: "Bundle case")
        let dir = workspace()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let file = dir.appendingPathComponent("notes.md")
        try Data("# note".utf8).write(to: file)
        _ = try persistence.importFileSource(in: researchCase, sourceURL: file,
                                             sourceType: .text, title: "Notes")

        let parent = dir.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let bundle = try ReportExporter.exportBundle(for: researchCase,
                                                     into: parent,
                                                     attachments: persistence.attachments)

        #expect(bundle.lastPathComponent == "C-001-export")
        #expect(FileManager.default.fileExists(atPath: bundle.appendingPathComponent("manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: bundle.appendingPathComponent("report.md").path))
        let attachmentsDir = bundle.appendingPathComponent("attachments", isDirectory: true)
        let children = try FileManager.default.contentsOfDirectory(atPath: attachmentsDir.path)
        #expect(children == ["S-001"])
        // Manifest references resolve inside the bundle.
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ExportManifest.self,
                                          from: Data(contentsOf: bundle.appendingPathComponent("manifest.json")))
        for entry in manifest.attachments {
            #expect(FileManager.default.fileExists(
                atPath: bundle.appendingPathComponent(entry.relativePath).path))
            #expect(!entry.relativePath.hasPrefix("/"))
        }
    }

    @Test func exportMarkdownIntoUnwritableFolderFails() throws {
        let persistence = try PersistenceService.makeInMemory()
        let researchCase = try persistence.createCase(title: "RO")
        let dir = workspace()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
        let url = dir.appendingPathComponent("report.md")
        var threw = false
        do { try ReportExporter.exportMarkdown(for: researchCase, to: url) } catch { threw = true }
        #expect(threw, "a read-only destination must surface an error")
    }
}
