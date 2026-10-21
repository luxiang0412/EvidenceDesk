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
        case .overview: return "Overview"
        case .sources: return "Sources"
        case .evidence: return "Evidence"
        case .findings: return "Findings"
        case .timeline: return "Timeline"
        case .report: return "Report"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "doc.text.magnifyingglass"
        case .sources: return "books.vertical"
        case .evidence: return "quote.bubble"
        case .findings: return "lightbulb"
        case .timeline: return "clock"
        case .report: return "doc.plaintext"
        }
    }
}