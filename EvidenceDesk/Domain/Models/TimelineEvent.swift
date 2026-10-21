import Foundation
import SwiftData

@Model
final class TimelineEvent {
    var id: UUID
    var title: String
    var detail: String
    /// `nil` when the date is unknown.
    var date: Date?
    var datePrecisionRaw: String
    /// Optional linked source.
    var source: Source?
    var notes: String
    var createdAt: Date
    var `case`: ResearchCase?

    var datePrecision: DatePrecision {
        get { DatePrecision(rawValue: datePrecisionRaw) ?? .unknown }
        set { datePrecisionRaw = newValue.rawValue }
    }

    /// Parseable date range only when a partial date exists.
    var hasDate: Bool { date != nil && datePrecision != .unknown }

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        date: Date? = nil,
        datePrecision: DatePrecision = .unknown,
        source: Source? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.date = date
        self.datePrecisionRaw = datePrecision.rawValue
        self.source = source
        self.notes = notes
        self.createdAt = createdAt
    }
}