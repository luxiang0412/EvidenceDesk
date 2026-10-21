import SwiftUI

@main
struct EvidenceDeskApp: App {
    @State private var setup: AppSetup
    @State private var startupViewID = UUID()

    init() {
        if ProcessInfo.processInfo.arguments.contains("--ed-trace") { bootTrace("app init begin") }
        let s = AppSetup.bootstrap()
        if ProcessInfo.processInfo.arguments.contains("--ed-trace") { bootTrace("app init done") }
        _setup = State(initialValue: s)
    }

    var body: some Scene {
        WindowGroup {
            switch setup {
            case .ready(let environment, let container, let persistence):
                StartupView()
                    .environment(environment)
                    .withPersistence(persistence)
                    .modelContainer(container)
                    .frame(minWidth: DesignSystem.Layout.minWindowWidth,
                           minHeight: DesignSystem.Layout.minWindowHeight)
                    .id(startupViewID)
            case .failed(let environment, let error):
                FatalErrorView(error: error) {
                    setup = AppSetup.bootstrap()
                }
                .environment(environment)
                .frame(width: 620, height: 320)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
        .defaultSize(width: DesignSystem.Layout.defaultWindowWidth,
                     height: DesignSystem.Layout.defaultWindowHeight)
    }
}

/// Dev/QA boot tracing, written before any view exists.
private func bootTrace(_ message: String) {
    _ = try? ((message + "\n").appendToFile(FileManager.default.temporaryDirectory.appendingPathComponent("ed-boot.txt")))
}