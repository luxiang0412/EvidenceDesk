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
        case .draft: return "Draft"
        case .active: return "Active"
        case .superseded: return "Superseded"
        }
    }
}