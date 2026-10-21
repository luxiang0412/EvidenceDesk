import Foundation
import SwiftData
import Testing
@testable import EvidenceDesk

/// Performance-oriented checks from the plan's P6 baseline. These are
/// correctness-under-scale tests (no absolute millisecond assertions), plus
/// bounded timing to catch pathological regressions.
@MainActor
struct PerformanceTests {
    @Test func fiveHundredSourcesRemainUsable() throws {
        let p = try PersistenceService.makeInMemory()
        let c = try p.createCase(title: "Scale case")

        let start = Date()
        for i in 1...500 {
            _ = try p.createURLSource(in: c, url: URL(string: "https://example.com/item/\(i)")!,
                                      title: "Source \(i)")
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(c.sources.count == 500)
        #expect(c.sources.map(\.shortCode).max() == "S-500")
        #expect(Set(c.sources.map(\.shortCode)).count == 500, "codes stay unique")
        // Bounded: creating 500 sources in memory should be well under a minute.
        #expect(elapsed < 60, "creating 500 sources took \(elapsed)s")
    }

    @Test func evidenceAndLinksAtScale() throws {
        let p = try PersistenceService.makeInMemory()
        let c = try p.createCase(title: "Scale evidence")
        let source = try p.createURLSource(in: c, url: URL(string: "https://example.com")!, title: "S")

        var evidences: [Evidence] = []
        for i in 1...200 {
            evidences.append(try p.createEvidence(in: c, text: "excerpt \(i)", type: .fact, source: source,
                                                  locationNote: "p. \(i)", pageNumber: i, userNotes: ""))
        }
        let finding = try p.createFinding(in: c, title: "Many links", body: "", status: .active, uncertainty: "")
        for evidence in evidences {
            try p.linkEvidence(evidence, to: finding, relation: .context)
        }
        #expect(finding.links.count == 200)

        // Report generation over 200 evidence items completes quickly.
        let started = Date()
        let payload = ReportPayloadBuilder.build(for: c)
        let md = MarkdownReportExporter.generate(payload)
        let elapsed = Date().timeIntervalSince(started)
        #expect(md.contains("E-200"))
        #expect(elapsed < 10, "report generation took \(elapsed)s")
    }

    @Test func reportDoesNotLeakAbsolutePathsAtScale() throws {
        let p = try PersistenceService.makeInMemory()
        let c = try p.createCase(title: "Path safety")
        _ = try p.createURLSource(in: c, url: URL(string: "https://example.com/a")!, title: "A")
        let payload = ReportPayloadBuilder.build(for: c)
        let md = MarkdownReportExporter.generate(payload)
        #expect(!md.contains("/Users/"))
        #expect(!md.contains("/var/folders/"))
        #expect(!md.contains("file://"))
    }
}