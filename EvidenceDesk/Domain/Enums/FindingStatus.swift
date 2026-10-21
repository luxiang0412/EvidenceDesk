import Foundation

/// Status of a research finding.
///
/// Note: `active` means "the finding the researcher is currently working with",
/// not "proven". Evidence Desk never claims to establish truth.
enum FindingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case active
    case superseded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return String(localized: "Draft")
        case .active: return String(localized: "Active")
        case .superseded: return String(localized: "Superseded")
        }
    }
}