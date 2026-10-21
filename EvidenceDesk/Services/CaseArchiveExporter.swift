import Foundation

enum ExportError: Error, LocalizedError, Equatable {
    case targetNotWritable
    case manifestEncodingFailed
    case attachmentMissing(String)
    case copyFailed(String)
    case reportGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .targetNotWritable:
            return "The export location is not writable."
        case .manifestEncodingFailed:
            return "The case manifest could not be encoded."
        case .attachmentMissing(let name):
            return "An attachment file was missing during export: \(name)."
        case .copyFailed(let detail):
            return "An attachment could not be copied. \(detail)"
        case .reportGenerationFailed(let detail):
            return "The report could not be generated. \(detail)"
        }
    }
}

struct ExportManifest: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let caseShortCode: String
    let caseTitle: String
    let reportFile: String
    let attachments: [AttachmentEntry]

    struct AttachmentEntry: Codable {
        let sourceRef: String
        /// Relative path inside the export bundle, e.g. `attachments/S-001/original.pdf`.
        let relativePath: String
        let originalFilename: String
    }
}

/// Exports a portable case directory:
///
/// ```
/// <target>
/// ├── manifest.json
/// ├── report.md
/// └── attachments/<source-ref>/original.<ext>
/// ```
///
/// - `manifest.json` carries `schemaVersion` and stable IDs; paths are relative.
/// - Attachments are **copied**, never moved.
/// - No sandbox-absolute paths are ever written.
@MainActor
final class CaseArchiveExporter {
    private let attachments: AttachmentStore
    private let fileManager: FileManager

    init(attachments: AttachmentStore, fileManager: FileManager = .default) {
        self.attachments = attachments
        self.fileManager = fileManager
    }

    @discardableResult
    func exportCase(_ researchCase: ResearchCase, to targetDirectory: URL) throws -> URL {
        guard fileManager.isWritableFile(atPath: targetDirectory.path) ||
                !fileManager.fileExists(atPath: targetDirectory.path) else {
            throw ExportError.targetNotWritable
        }
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let payload = ReportPayloadBuilder.build(for: researchCase)
        let markdown = MarkdownReportExporter.generate(payload)
        guard !markdown.isEmpty else {
            throw ExportError.reportGenerationFailed("Empty document")
        }

        // attachments/
        let attachmentsDir = targetDirectory.appendingPathComponent("attachments", isDirectory: true)
        var entries: [ExportManifest.AttachmentEntry] = []
        let sources = researchCase.sources.sorted { $0.shortCode < $1.shortCode }
        for source in sources {
            guard let rel = source.attachmentRelativePath else { continue }
            guard let sourceFileURL = attachments.resolve(urlForRelativePath: rel) else { continue }
            guard fileManager.fileExists(atPath: sourceFileURL.path) else {
                throw ExportError.attachmentMissing(source.shortCode)
            }
            let destDir = attachmentsDir.appendingPathComponent(source.shortCode, isDirectory: true)
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            let ext = sourceFileURL.pathExtension
            let destName = ext.isEmpty ? "original" : "original.\(ext)"
            let dest = destDir.appendingPathComponent(destName)
            do {
                try fileManager.copyItem(at: sourceFileURL, to: dest)
            } catch {
                throw ExportError.copyFailed(error.localizedDescription)
            }
            entries.append(ExportManifest.AttachmentEntry(
                sourceRef: source.shortCode,
                relativePath: "attachments/\(source.shortCode)/\(destName)",
                originalFilename: source.originalFilename
            ))
        }

        // report.md
        let reportURL = targetDirectory.appendingPathComponent("report.md")
        do {
            try markdown.write(to: reportURL, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.copyFailed(error.localizedDescription)
        }

        // manifest.json
        let manifest = ExportManifest(
            schemaVersion: MarkdownReportExporter.schemaVersion,
            generatedAt: payload.generatedAt,
            caseShortCode: researchCase.shortCode,
            caseTitle: researchCase.title,
            reportFile: "report.md",
            attachments: entries
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(manifest)
            try data.write(to: targetDirectory.appendingPathComponent("manifest.json"), options: .atomic)
        } catch {
            throw ExportError.manifestEncodingFailed
        }

        return targetDirectory
    }
}