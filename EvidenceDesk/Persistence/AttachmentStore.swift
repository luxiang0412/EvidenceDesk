import Foundation

enum AttachmentStoreError: Error, LocalizedError, Equatable {
    case copyFailed(String)
    case verifyFailed
    case cleanupFailed(String)

    var errorDescription: String? {
        switch self {
        case .copyFailed(let detail):
            return String(localized: "The attachment could not be copied. \(detail)")
        case .verifyFailed:
            return String(localized: "The copied attachment could not be verified.")
        case .cleanupFailed(let detail):
            return String(localized: "Temporary data could not be cleaned up. \(detail)")
        }
    }
}

/// Owns every attachment file. UI and services never manipulate attachments
/// directly; all file-system writes go through here.
///
/// Layout: `<attachmentsRoot>/<source-uuid>/original.<ext>`
/// The relative path stored on `Source` is relative to `attachmentsRoot`.
@MainActor
final class AttachmentStore {
    let root: URL
    private let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    // MARK: - Paths

    func directory(for source: Source) -> URL {
        root.appendingPathComponent(source.id.uuidString, isDirectory: true)
    }

    func relativePath(for source: Source, originalURL: URL) -> String {
        let ext = originalURL.pathExtension
        let filename = ext.isEmpty ? "original" : "original.\(ext)"
        return String(localized: "\(source.id.uuidString)/\(filename)")
    }

    func resolve(urlForRelativePath relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        return root.appendingPathComponent(relativePath)
    }

    // MARK: - Import (staging -> final)

    /// Copies a user-selected file into the staging directory. Caller must
    /// `finishImport` or `cancelImport` to finalise or clean up.
    func stageImport(from sourceURL: URL, sourceID: UUID) throws -> URL {
        let dir = root.appendingPathComponent(".staging/\(sourceID.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension
        let filename = ext.isEmpty ? "original" : "original.\(ext)"
        let stagingFile = dir.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: stagingFile.path) {
            try fileManager.removeItem(at: stagingFile)
        }
        do {
            try fileManager.copyItem(at: sourceURL, to: stagingFile)
        } catch {
            throw AttachmentStoreError.copyFailed(error.localizedDescription)
        }
        // Verify existence and size parity, without trusting the copy silently.
        guard let stagedSize = try? fileManager.attributesOfItem(atPath: stagingFile.path)[.size] as? NSNumber,
              let originalSize = try? fileManager.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber,
              stagedSize == originalSize, stagedSize.int64Value > 0
        else {
            try? fileManager.removeItem(at: stagingFile)
            throw AttachmentStoreError.verifyFailed
        }
        return stagingFile
    }

    /// Moves a staged file into its final per-source directory.
    func finaliseImport(stagedFile: URL, source: Source) throws -> String {
        let finalDir = directory(for: source)
        try fileManager.createDirectory(at: finalDir, withIntermediateDirectories: true)
        let fileName = stagedFile.lastPathComponent
        let finalURL = finalDir.appendingPathComponent(fileName)
        do {
            try fileManager.moveItem(at: stagedFile, to: finalURL)
        } catch {
            throw AttachmentStoreError.copyFailed(error.localizedDescription)
        }
        // Remove now-empty staging parent.
        let staging = stagedFile.deletingLastPathComponent()
        try? fileManager.removeItem(at: staging)
        return String(localized: "\(source.id.uuidString)/\(fileName)")
    }

    /// Removes a staged import entirely (rollback path after failed persistence).
    func cancelImport(stagedFile: URL) {
        let staging = stagedFile.deletingLastPathComponent()
        try? fileManager.removeItem(at: staging)
    }

    // MARK: - Cleanup

    /// Removes the per-source attachment directory.
    func removeAttachmentDirectory(for source: Source) throws {
        let dir = directory(for: source)
        guard fileManager.fileExists(atPath: dir.path) else { return }
        try fileManager.removeItem(at: dir)
    }

    /// Deletes the whole attachments tree (used for test isolation / wipe).
    func removeAll() throws {
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
    }

    // MARK: - Introspection

    func fileExists(relativePath: String) -> Bool {
        guard let url = resolve(urlForRelativePath: relativePath) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    func size(of relativePath: String) -> Int64? {
        guard let url = resolve(urlForRelativePath: relativePath),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return (attrs[.size] as? NSNumber)?.int64Value
    }
}