import Foundation

/// Timeline ordering rules, shared by the views and the exporter so both
/// display identical behaviour. Events without a usable date are grouped into
/// an explicit "date undetermined" section and never faked into a date.
enum TimelineSorting {
    /// Partitions items into dated (ascending) and undated groups.
    /// An item is dated only when it has a date AND precision != .unknown.
    static func partition<T>(
        _ items: [T],
        date: (T) -> Date?,
        precision: (T) -> DatePrecision
    ) -> (dated: [T], undated: [T]) {
        let dated = items
            .filter { date($0) != nil && precision($0) != .unknown }
            .sorted { (date($0) ?? .distantPast) < (date($1) ?? .distantPast) }
        let undated = items.filter { date($0) == nil || precision($0) == .unknown }
        return (dated, undated)
    }

    /// Stable ordering for events sharing the same day: preserves insertion
    /// order (createdAt ascending) so same-day events display deterministically.
    static func sortSameDayStably<T>(_ items: [T], date: (T) -> Date?, createdAt: (T) -> Date) -> [T] {
        items.sorted { lhs, rhs in
            let dl = date(lhs) ?? .distantPast
            let dr = date(rhs) ?? .distantPast
            if dl == dr { return createdAt(lhs) < createdAt(rhs) }
            return dl < dr
        }
    }
}