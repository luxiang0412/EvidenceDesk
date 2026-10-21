import Foundation
import SwiftData
import Testing
@testable import EvidenceDesk

@MainActor
struct RecoveryTests {
    let persistence: PersistenceService
    let recovery: RecoveryService

    init() throws {
        persistence = try PersistenceService.makeInMemory()
        recovery = RecoveryService(modelContext: persistence.modelContext, attachments: persistence.attachments)
    }

    @Test func missingAttachmentGetsFlagged() async throws {
        let c = try persistence.createCase(title: "recovery")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("doc.pdf")
        try Data("pdf".utf8).write(to: f)
        let source = try persistence.importFileSource(in: c, sourceURL: f, sourceType: .pdf, title: "Docs")
        #expect(!source.attachmentIsMissing)

        // Simulate the file disappearing.
        if let rel = source.attachmentRelativePath,
           let url = persistence.attachments.resolve(urlForRelativePath: rel) {
            try FileManager.default.removeItem(at: url)
        }

        let report = try await recovery.run()
        #expect(report.missingAttachments.contains { $0.id == source.id })
        #expect(source.attachmentIsMissing)

        try? FileManager.default.removeItem(at: dir)
    }

    @Test func orphanDirectoriesDetected() async throws {
        // Create a stray attachment directory with no matching Source record.
        try persistence.attachments.removeAll()
        let stray = persistence.attachments.root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stray, withIntermediateDirectories: true)

        let report = try await recovery.run()
        let strayName = stray.lastPathComponent
        #expect(report.orphanAttachmentDirectories.contains { $0.lastPathComponent == strayName })
        let removed = try recovery.cleanOrphans(orphans: report.orphanAttachmentDirectories)
        #expect(removed == 1)
        #expect(!FileManager.default.fileExists(atPath: stray.path))
    }

    @Test func referencedAttachmentIsNotOrphan() async throws {
        try persistence.attachments.removeAll()
        let c = try persistence.createCase(title: "no orphan")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-RecoveryRef-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("doc.txt")
        try Data("text".utf8).write(to: f)
        let source = try persistence.importFileSource(in: c, sourceURL: f, sourceType: .text, title: "T")
        _ = source

        let report = try await recovery.run()
        #expect(report.orphanAttachmentDirectories.isEmpty)
        try? FileManager.default.removeItem(at: dir)
    }
}