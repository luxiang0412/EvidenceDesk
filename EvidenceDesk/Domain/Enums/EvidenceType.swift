import Foundation

/// Semantic classification of an evidence item.
enum EvidenceType: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The source explicitly records this fact.
    case fact
    /// An explanation or reading derived from the source.
    case interpretation
    /// A hypothesis waiting to be verified.
    case hypothesis
    /// Something not yet resolved.
    case unresolved

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fact: return String(localized: "Fact")
        case .interpretation: return String(localized: "Interpretation")
        case .hypothesis: return String(localized: "Hypothesis")
        case .unresolved: return String(localized: "Unresolved")
        }
    }

    var systemImage: String {
        switch self {
        case .fact: return "checkmark.seal"
        case .interpretation: return "text.quote"
        case .hypothesis: return "questionmark.circle"
        case .unresolved: return "exclamationmark.triangle"
        }
    }

    var colorName: String {
        switch self {
        case .fact: return "fact"
        case .interpretation: return "inference"
        case .hypothesis: return "hypothesis"
        case .unresolved: return "unresolved"
        }
    }
}