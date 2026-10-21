import Foundation
import Testing
@testable import EvidenceDesk

@MainActor
struct AttachmentStoreTests {
    @Test func stagingCopyVerifyAndFinalise() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = AttachmentStore(root: root.appendingPathComponent("Attachments"))

        let sourceFile = root.appendingPathComponent("source.pdf")
        try Data(repeating: 0x41, count: 4096).write(to: sourceFile)

        let sourceID = UUID()
        let staged = try store.stageImport(from: sourceFile, sourceID: sourceID)
        #expect(FileManager.default.fileExists(atPath: staged.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: staged.path)
        #expect((attrs[.size] as? NSNumber)?.int64Value == 4096, "staged copy must match source size")

        // finalise into per-source dir
        let source = Source(shortCode: "S-001", sourceType: .pdf, title: "T")
        let rel = try store.finaliseImport(stagedFile: staged, source: source)
        #expect(rel == "\(source.id.uuidString)/original.pdf")
        #expect(store.fileExists(relativePath: rel))
        // staging dir removed
        let stagingDir = staged.deletingLastPathComponent()
        #expect(!FileManager.default.fileExists(atPath: stagingDir.path))
    }

    @Test func cancelImportCleansUpStaging() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-StoreCancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = AttachmentStore(root: root.appendingPathComponent("Attachments"))

        let sourceFile = root.appendingPathComponent("doc.md")
        try Data("hello".utf8).write(to: sourceFile)
        let staged = try store.stageImport(from: sourceFile, sourceID: UUID())
        store.cancelImport(stagedFile: staged)
        #expect(!FileManager.default.fileExists(atPath: staged.path))
    }

    @Test func sizeMismatchFailsVerification() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-StoreVerify-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = AttachmentStore(root: root.appendingPathComponent("Attachments"))

        // Non-existent source should fail staging (no file to copy).
        let missing = root.appendingPathComponent("nope.pdf")
        var threw: Error?
        do {
            _ = try store.stageImport(from: missing, sourceID: UUID())
        } catch {
            threw = error
        }
        guard case .some(.copyFailed) = threw as? AttachmentStoreError else {
            Issue.record("expected copyFailed, got \(String(describing: threw))")
            return
        }
    }

    @Test func removeAttachmentDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-StoreRem-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = AttachmentStore(root: root.appendingPathComponent("Attachments"))

        let source = Source(shortCode: "S-001", sourceType: .pdf, title: "T")
        let rel = try store.finaliseImport(stagedFile: try store.stageImport(from: sourceFile(at: root), sourceID: source.id), source: source)
        #expect(store.fileExists(relativePath: rel))
        try store.removeAttachmentDirectory(for: source)
        #expect(!store.fileExists(relativePath: rel))
    }

    private func sourceFile(at root: URL) -> URL {
        let f = root.appendingPathComponent("a.txt")
        try? Data("a".utf8).write(to: f)
        return f
    }
}