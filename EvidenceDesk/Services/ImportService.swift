import Foundation
import UniformTypeIdentifiers

/// Outcome of validating one import offer.
enum ImportValidationResult: Equatable, Sendable {
    /// Valid file, ready to import.
    case file(URL, SourceType, title: String)
    /// Valid URL.
    case url(URL)
    /// Rejected with a user-presentable reason.
    case rejected(String)
    /// The item could not be resolved to a file.
    case unresolved
}

/// Shared import pipeline. Menu imports, drag & drop and URL paste all go
/// through this service so validation and error handling are identical.
@MainActor
final class ImportService {
    static func deriveTitle(from url: URL) -> String {
        guard !url.lastPathComponent.isEmpty else { return url.deletingPathExtension().lastPathComponent }
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty ? url.lastPathComponent : name
    }

    /// Validate a single dropped file URL.
    static func validateFileOffer(_ url: URL) -> ImportValidationResult {
        switch FileValidation.validateFile(at: url) {
        case .success:
            guard let type = FileValidation.category(for: url) else {
                return .rejected("“\(url.lastPathComponent)” is not a supported file type.")
            }
            return .file(url, type, title: deriveTitle(from: url))
        case .failure(let error):
            return .rejected(error.errorDescription ?? "The file could not be used.")
        }
    }

    /// Resolve drop providers to validated file offers (asynchronous, since
    /// providers load lazily).
    static func resolveDropProviders(_ providers: [NSItemProvider]) async -> [ImportValidationResult] {
        var results: [ImportValidationResult] = []
        for provider in providers {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let url = item as? URL {
                results.append(validateFileOffer(url))
            } else if let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) {
                results.append(validateFileOffer(url))
            } else {
                results.append(.unresolved)
            }
        }
        return results
    }

    /// Validate a pasted URL string.
    static func validateURLOffer(_ raw: String) -> ImportValidationResult {
        switch URLValidation.validate(raw) {
        case .success(let url): return .url(url)
        case .failure(let error): return .rejected(error.errorDescription ?? "Invalid URL.")
        }
    }
}