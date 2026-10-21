import Foundation

/// Library filtering rules, extracted so search and archive behaviour can be
/// tested without a UI.
enum CaseFilter {
    /// Filters by archive state, then by a case-insensitive match on the case
    /// code, title or research question. An empty/whitespace query returns all
    /// cases in the selected archive state.
    static func apply(
        to cases: [ResearchCase],
        showArchived: Bool,
        query: String
    ) -> [ResearchCase] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let inScope = cases.filter { $0.isArchived == showArchived }
        guard !trimmed.isEmpty else { return inScope }
        let needle = trimmed.localizedLowercase
        return inScope.filter { researchCase in
            researchCase.title.localizedLowercase.contains(needle)
                || researchCase.researchQuestion.localizedLowercase.contains(needle)
                || researchCase.shortCode.localizedLowercase.contains(needle)
                || researchCase.researchScope.localizedLowercase.contains(needle)
        }
    }
}
