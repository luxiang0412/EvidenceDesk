import Foundation

/// The single implementation of "write a Markdown report and/or a portable case
/// bundle to a user-chosen location".
///
/// `ReportPreviewView` calls these functions; tests call the exact same ones, so
/// the exported result verified in tests is literally the artefact the UI
/// produces (only the destination differs).
@MainActor
enum ReportExporter {
    /// Suggested filename for a case's Markdown report.
    static func markdownFilename(for researchCase: ResearchCase) -> String {
        "\(researchCase.shortCode)-report.md"
    }

    /// Suggested folder name for a case bundle.
    static func bundleFolderName(for researchCase: ResearchCase) -> String {
        "\(researchCase.shortCode)-export"
    }

    /// Renders and writes the Markdown report. Returns the written URL.
    @discardableResult
    static func exportMarkdown(
        for researchCase: ResearchCase,
        to url: URL
    ) throws -> URL {
        let payload = ReportPayloadBuilder.build(for: researchCase)
        let markdown = MarkdownReportExporter.generate(payload)
        guard !markdown.isEmpty else {
            throw ExportError.reportGenerationFailed("The report was empty.")
        }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.copyFailed(error.localizedDescription)
        }
        return url
    }

    /// Exports `manifest.json`, `report.md` and `attachments/` into
    /// `parentDirectory/<bundle name>`, returning the bundle URL.
    @discardableResult
    static func exportBundle(
        for researchCase: ResearchCase,
        into parentDirectory: URL,
        attachments: AttachmentStore
    ) throws -> URL {
        let target = parentDirectory.appendingPathComponent(
            bundleFolderName(for: researchCase),
            isDirectory: true
        )
        let exporter = CaseArchiveExporter(attachments: attachments)
        return try exporter.exportCase(researchCase, to: target)
    }
}
