import Foundation
import Combine

/// Cross-section navigation within a case workspace. Sections publish a
/// destination; the workspace switches section and the target view reacts to
/// the changing token. Kept at workspace scope, not global.
@MainActor
final class CaseRouter: ObservableObject {
    struct Destination: Equatable {
        var sourceID: UUID?
        var evidenceID: UUID?
        var findingID: UUID?
        var page: Int?
        var token: Int
    }

    @Published var pending = Destination(token: 0)

    func openSource(_ id: UUID, page: Int? = nil) {
        pending = Destination(sourceID: id, page: page, token: pending.token + 1)
    }

    func openEvidence(_ id: UUID) {
        pending = Destination(evidenceID: id, token: pending.token + 1)
    }

    func openFinding(_ id: UUID) {
        pending = Destination(findingID: id, token: pending.token + 1)
    }
}