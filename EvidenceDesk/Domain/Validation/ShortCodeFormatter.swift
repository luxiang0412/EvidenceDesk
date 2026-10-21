import Foundation

/// Formats stable human-readable short codes and computes the next one from
/// existing items. Codes are assigned once and never change.
enum ShortCodeFormatter {
    /// Format a zero-based index as a 3-digit padded code.
    /// Example: prefix "S", index 0 -> "S-001".
    static func code(prefix: String, index: Int) -> String {
        String(format: "%@-%03d", prefix, max(index, 0) + 1)
    }

    /// Derive the next code prefix and index from existing codes.
    /// Existing codes are expected to follow the `P-###` shape produced by
    /// `code(prefix:index:)`; unrecognised items are ignored.
    static func nextCode<T>(prefix: String, existing: [T], codeOf: (T) -> String?) -> String {
        var maxIndex = -1
        for item in existing {
            guard let code = codeOf(item) else { continue }
            maxIndex = max(maxIndex, parseIndex(code: code, prefix: prefix))
        }
        return code(prefix: prefix, index: maxIndex + 1)
    }

    static func parseIndex(code: String, prefix: String) -> Int {
        let expected = "\(prefix)-"
        guard code.hasPrefix(expected) else { return -1 }
        let number = code.dropFirst(expected.count)
        guard let value = Int(number) else { return -1 }
        return value - 1
    }
}