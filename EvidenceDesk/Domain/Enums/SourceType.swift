import Foundation

/// The kind of research source.
enum SourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case url
    case pdf
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .url: return String(localized: "Web Link")
        case .pdf: return String(localized: "PDF Document")
        case .text: return String(localized: "Text / Markdown")
        }
    }

    var systemImage: String {
        switch self {
        case .url: return "link"
        case .pdf: return "doc.richtext"
        case .text: return "doc.plaintext"
        }
    }
}