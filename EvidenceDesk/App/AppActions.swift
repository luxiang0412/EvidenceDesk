import Foundation
import Combine

/// Single action channel that both menu commands and toolbar buttons use, so
/// the plan's "one set of business actions" rule holds.
@MainActor
final class AppActions: ObservableObject {
    static let shared = AppActions()

    enum Action {
        case newCase
        case importSource
        case exportReport
        case focusSearch
        case toggleSidebar
        case toggleInspector
        case showLibraryList
    }

    private let subject = PassthroughSubject<Action, Never>()

    func send(_ action: Action) {
        subject.send(action)
    }

    func publisher() -> AnyPublisher<Action, Never> {
        subject.eraseToAnyPublisher()
    }
}