import SwiftUI

/// Menu commands. These route into `AppActions` — the same channel the
/// toolbar buttons use — so there is never a second implementation of a
/// business operation.
struct AppCommands: Commands {
    var body: some Commands {
        // File menu
        CommandGroup(after: .newItem) {
            Button("New Research Case…") {
                AppActions.shared.send(.newCase)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Import Source…") {
                AppActions.shared.send(.importSource)
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Export Report…") {
                AppActions.shared.send(.exportReport)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        // View menu
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") {
                AppActions.shared.send(.toggleInspector)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandGroup(after: .toolbar) {
            Button("Focus Search") {
                AppActions.shared.send(.focusSearch)
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()

            // The app's only settings screen is language, so it is reachable
            // from View as well as the standard app menu / ⌘,.
            SettingsLink {
                Text("Language…")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}