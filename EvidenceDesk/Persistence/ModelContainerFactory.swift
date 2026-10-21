import Foundation
import SwiftData

/// Builds `ModelContainer` instances. UI tests use an isolated file storage
/// (via launch argument) or in-memory storage; the app uses the sandboxed
/// Application Support store.
enum ModelContainerFactory {
    static let schema = Schema([
        ResearchCase.self,
        Source.self,
        Evidence.self,
        Finding.self,
        FindingEvidenceLink.self,
        TimelineEvent.self
    ])

    static func makeStoreURL(storageRoot: URL) -> URL {
        storageRoot.appendingPathComponent("EvidenceDesk.store", isDirectory: false)
    }

    /// Live app container. The store lives inside the app storage root.
    static func make(storageRoot: URL) throws -> ModelContainer {
        let config = ModelConfiguration(
            "EvidenceDesk",
            schema: schema,
            url: makeStoreURL(storageRoot: storageRoot)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Test container isolated from real user data.
    static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Test container backed by a specific directory (persists across app restarts
    /// for UI restart tests).
    static func makeIsolated(storageRoot: URL) throws -> ModelContainer {
        try make(storageRoot: storageRoot)
    }
}