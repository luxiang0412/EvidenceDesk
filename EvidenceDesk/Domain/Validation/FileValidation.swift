import Foundation
import UniformTypeIdentifiers

enum FileValidationError: Error, LocalizedError, Equatable {
    case unsupportedType(String)
    case emptyFile
    case unreadable
    case tooLarge(Int64)
    case noAccess

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let name):
            return String(localized: "“\(name)” is not a supported file type. Please provide a PDF, TXT or Markdown file.")
        case .emptyFile:
            return String(localized: "The file is empty.")
        case .unreadable:
            return String(localized: "The file could not be read.")
        case .tooLarge(let size):
            let mb = Double(size) / (1024 * 1024)
            return String(format: "The file is %.1f MB. Files larger than 100 MB are not supported.", mb)
        case .noAccess:
            return String(localized: "The file could not be accessed.")
        }
    }
}

/// Validates files offered for import. Only PDF, plain text and Markdown are
/// accepted, with a 100 MB hard limit (validated without loading the file into
/// memory).
enum FileValidation {
    static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100 MB

    static let supportedExtensions: Set<String> = ["pdf", "txt", "md", "markdown"]

    static func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if supportedExtensions.contains(ext) { return true }
        // Fall back to the declared UTI for content-based recognition.
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .pdf)
            || type.conforms(to: .plainText)
            || type.conforms(to: .text)
    }

    static func category(for url: URL) -> SourceType? {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "txt": return .text
        case "md", "markdown": return .text
        default:
            guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
            if type.conforms(to: .pdf) { return .pdf }
            if type.conforms(to: .plainText) || type.conforms(to: .text) {
                return .text
            }
            return nil
        }
    }

    /// Validate a file without reading its contents into memory.
    static func validateFile(at url: URL) -> Result<URL, FileValidationError> {
        guard isSupported(url: url) else {
            return .failure(.unsupportedType(url.lastPathComponent))
        }
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: url.path) else { return .failure(.noAccess) }
        let size: Int64
        do {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
        } catch {
            return .failure(.unreadable)
        }
        if size == 0 { return .failure(.emptyFile) }
        if size > maxFileSize { return .failure(.tooLarge(size)) }
        return .success(url)
    }
}