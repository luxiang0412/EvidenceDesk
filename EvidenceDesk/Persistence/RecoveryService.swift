import Foundation
import SwiftData

/// Result of a startup consistency check.
struct RecoveryReport: Sendable {
    let missingAttachments: [Source]
    let orphanAttachmentDirectories: [URL]
}

enum RecoveryError: Error, LocalizedError {
    case scanFailed(String)

    var errorDescription: String? {
        switch self {
        case .scanFailed(let detail): return String(localized: "The data consistency check failed: \(detail)")
        }
    }
}

/// Light-weight startup consistency check.
///
/// - Flags sources whose attachment file no longer exists (UI shows a
///   recover/re-locate option; nothing is deleted automatically).
/// - Lists attachment directories without a matching Source record so the user
///   can choose to clean them up; **never deletes files it cannot confirm**.
@MainActor
final class RecoveryService {
    private let modelContext: ModelContext
    private let attachments: AttachmentStore

    init(modelContext: ModelContext, attachments: AttachmentStore) {
        self.modelContext = modelContext
        self.attachments = attachments
    }

    func run() async throws -> RecoveryReport {
        let sources = (try? modelContext.fetch(FetchDescriptor<Source>())) ?? []
        var missing: [Source] = []
        for source in sources {
            guard let rel = source.attachmentRelativePath else { continue }
            let exists = attachments.fileExists(relativePath: rel)
            if !exists {
                source.attachmentIsMissing = true
                missing.append(source)
            } else if source.attachmentIsMissing {
                source.attachmentIsMissing = false
            }
        }
        if !missing.isEmpty {
            try? modelContext.save()
        }

        let orphans = try orphanDirectories()
        Logger.recovery.log("check complete: \(missing.count, privacy: .public) missing, \(orphans.count, privacy: .public) orphan dirs")
        return RecoveryReport(missingAttachments: missing, orphanAttachmentDirectories: orphans)
    }

    /// Removes attachment directories with no referencing Source record.
    /// Returns the count of directories removed. Never touches referenced files.
    func cleanOrphans(orphans: [URL]) throws -> Int {
        var removed = 0
        for url in orphans {
            try? FileManager.default.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private func orphanDirectories() throws -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        guard let items = try? fm.contentsOfDirectory(at: attachments.root,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles]) else {
            return result
        }
        for item in items {
            let name = item.lastPathComponent
            if name.hasPrefix(".") { continue }
            guard UUID(uuidString: name) != nil else { continue } // only source dirs
            let referenced = (try? modelContext.fetch(FetchDescriptor<Source>()))?.contains {
                $0.attachmentRelativePath?.hasPrefix("\(name)/") == true
            } ?? false
            if !referenced {
                result.append(item)
            }
        }
        return result
    }
}