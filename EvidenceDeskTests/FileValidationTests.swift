import Foundation
import Testing
@testable import EvidenceDesk

@MainActor
struct FileValidationTests {
    private var tempDir: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-FileValidation-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeFile(named: String, size: Int64, in dir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(named)
        FileManager.default.createFile(atPath: url.path, contents: Data(count: Int(size)))
        return url
    }

    @Test func supportsPdfTxtMd() throws {
        let dir = tempDir
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(FileValidation.isSupported(url: try makeFile(named: "a.pdf", size: 10, in: dir)))
        #expect(FileValidation.isSupported(url: try makeFile(named: "b.txt", size: 10, in: dir)))
        #expect(FileValidation.isSupported(url: try makeFile(named: "c.md", size: 10, in: dir)))
        #expect(FileValidation.isSupported(url: try makeFile(named: "d.markdown", size: 10, in: dir)))
    }

    @Test func rejectsUnsupportedType() throws {
        let dir = tempDir
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeFile(named: "evil.exe", size: 10, in: dir)
        guard case .failure(.unsupportedType) = FileValidation.validateFile(at: url) else {
            Issue.record("expected unsupportedType")
            return
        }
    }

    @Test func rejectsEmptyFile() throws {
        let dir = tempDir
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try makeFile(named: "empty.pdf", size: 0, in: dir)
        guard case .failure(.emptyFile) = FileValidation.validateFile(at: url) else {
            Issue.record("expected emptyFile")
            return
        }
    }

    @Test func rejectsTooLargeFile() throws {
        let dir = tempDir
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Sparse file over the 100 MB limit — content never loaded.
        let url = dir.appendingPathComponent("big.pdf")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let fh = try FileHandle(forWritingTo: url)
        try fh.truncate(atOffset: UInt64(FileValidation.maxFileSize) + 1)
        try fh.close()
        guard case .failure(.tooLarge(let size)) = FileValidation.validateFile(at: url) else {
            Issue.record("expected tooLarge")
            return
        }
        #expect(size > FileValidation.maxFileSize)
    }
}