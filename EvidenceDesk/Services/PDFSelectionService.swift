import Foundation
import PDFKit

/// Extracts plain text + 1-based page number from a `PDFSelection`.
/// Wrapped so UI code never deals with PDFKit internals directly.
enum PDFSelectionService {
    /// Returns the selected text and the 1-based page number of its start.
    /// Page number may be nil when the selection has no page bounds (unusual).
    static func extract(from selection: PDFSelection) -> (text: String, pageNumber: Int?)? {
        guard let text = selection.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard selection.pages.count > 0 else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let pageIndex = selection.pages[0].pageRef?.pageNumber ?? -1
        let oneBased = pageIndex >= 0 ? pageIndex : nil
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), oneBased)
    }
}