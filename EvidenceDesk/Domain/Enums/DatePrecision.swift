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
        case .exact: return "Exact date"
        case .yearMonth: return "Month / year"
        case .year: return "Year only"
        case .unknown: return "Date unknown"
        }
    }
}