import Foundation
import SwiftData

/// Startup result: either a fully wired app environment, or a fatal
/// configuration failure that must be shown honestly.
@MainActor
enum AppSetup {
    case ready(environment: AppEnvironment, container: ModelContainer, persistence: PersistenceService)
    case failed(environment: AppEnvironment, error: Error)

    static func bootstrap() -> AppSetup {
        let environment = AppEnvironment()
        do {
            let container = try ModelContainerFactory.make(storageRoot: environment.storageRoot)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let attachments = AttachmentStore(root: environment.attachmentsRoot)
            let persistence = PersistenceService(modelContext: context, attachments: attachments)
            return .ready(environment: environment, container: container, persistence: persistence)
        } catch {
            return .failed(environment: environment, error: error)
        }
    }
}