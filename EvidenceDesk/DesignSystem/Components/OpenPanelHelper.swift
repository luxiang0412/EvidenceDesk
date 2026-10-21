import AppKit
import UniformTypeIdentifiers

/// Small NSOpenPanel wrapper — system file selection, used by both the menu
/// import and drag & drop fallback paths.
@MainActor
enum FileSelectionHelper {
    static func openFiles(allowedContentTypes: [UTType], allowsMultiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            return panel.urls
        }
        return []
    }

    /// Directory chooser used for exporting the portable case bundle.
    static func openDirectory(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = title
        panel.prompt = prompt
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}