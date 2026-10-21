import Foundation

/// Precision recorded for a timeline event date.
enum DatePrecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case exact
    case yearMonth
    case year
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exact: return String(localized: "Exact date")
        case .yearMonth: return String(localized: "Month / year")
        case .year: return String(localized: "Year only")
        case .unknown: return String(localized: "Date unknown")
        }
    }
}