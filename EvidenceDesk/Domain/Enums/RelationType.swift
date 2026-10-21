import Foundation

/// How an evidence item relates to a finding.
enum RelationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case supports
    case contradicts
    case context

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .supports: return String(localized: "Supports")
        case .contradicts: return String(localized: "Contradicts")
        case .context: return String(localized: "Background")
        }
    }

    var systemImage: String {
        switch self {
        case .supports: return "plus.circle"
        case .contradicts: return "minus.circle"
        case .context: return "square.on.circle"
        }
    }
}