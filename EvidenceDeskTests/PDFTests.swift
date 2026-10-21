import Foundation
import PDFKit
import Testing
@testable import EvidenceDesk

/// Verifies the PDF fixture pipeline and selection extraction against a real
/// generated PDF document.
@MainActor
struct PDFTests {
    @Test func generatedPDFOpensWithTextAndPageInfo() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-PDF-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("spec.pdf")
        try PDFFixtureWriter.write(text: "Line 7 spec\nFirms must submit bids within 14 days.", to: url)
        defer { try? FileManager.default.removeItem(at: dir) }

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount >= 1)
        // Text extraction from the first page is possible.
        let page = try #require(document.page(at: 0)?.string)
        #expect(page.contains("14 days"))
    }

    @Test func selectionExtractionReturnsTextAndOneBasedPage() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-PDFSel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sel.pdf")
        try PDFFixtureWriter.write(text: "Alpha beta gamma\nSecond line delta omega.", to: url)
        defer { try? FileManager.default.removeItem(at: dir) }

        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            Issue.record("document failed to open")
            return
        }
        // Select a run of characters programmatically.
        let pageText = page.string ?? ""
        guard let range = pageText.range(of: "beta gamma") else {
            Issue.record("range not found")
            return
        }
        let nsRange = NSRange(range, in: pageText)
        guard let selection = page.selection(for: nsRange) else {
            Issue.record("selection failed")
            return
        }
        guard let extracted = PDFSelectionService.extract(from: selection) else {
            Issue.record("extract failed")
            return
        }
        #expect(extracted.text.contains("beta gamma"))
        #expect(extracted.pageNumber == 1, "first page is 1-based page 1")
    }

    @Test func fixturePDFIsPasswordFree() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-PDFPW-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("plain.pdf")
        try PDFFixtureWriter.write(text: "plain", to: url)
        defer { try? FileManager.default.removeItem(at: dir) }
        let document = try #require(PDFDocument(url: url))
        #expect(!document.isLocked)
    }
}