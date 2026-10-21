import Foundation

/// Dev/QA tracing helper appended to a file. Deliberately tiny; used only by
/// launch-flag-driven tooling.
extension String {
    func appendToFile(_ url: URL) throws {
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(Data(utf8))
        } else {
            try write(to: url, atomically: true, encoding: .utf8)
        }
    }
}