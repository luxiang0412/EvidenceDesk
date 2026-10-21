import Foundation

/// Sections of the case workspace.
enum WorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case sources
    case evidence
    case findings
    case timeline
    case report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return L10n.t("Overview")
        case .sources: return L10n.t("Sources")
        case .evidence: return L10n.t("Evidence")
        case .findings: return L10n.t("Findings")
        case .timeline: return L10n.t("Timeline")
        case .report: return L10n.t("Report")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return L10n.t("doc.text.magnifyingglass")
        case .sources: return L10n.t("books.vertical")
        case .evidence: return L10n.t("quote.bubble")
        case .findings: return L10n.t("lightbulb")
        case .timeline: return L10n.t("clock")
        case .report: return L10n.t("doc.plaintext")
        }
    }
}