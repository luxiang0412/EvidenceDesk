import SwiftUI

private struct PersistenceServiceKey: EnvironmentKey {
    static var defaultValue: PersistenceService? = nil
}

extension EnvironmentValues {
    /// The app-wide persistence service, injected at startup.
    var persistence: PersistenceService? {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
}

/// Convenience accessor for views that need the persistence service.
extension View {
    func withPersistence(_ service: PersistenceService?) -> some View {
        environment(\.persistence, service)
    }
}