import Foundation
import os
import Observation

/// Runtime environment: paths, launch arguments, and diagnostics for the current process.
///
/// The app honours a few launch arguments so UI tests can run with an isolated
/// data container and never touch real user data:
///  - `--test-storage <dir>` : use `<dir>` as the Application Support root.
@MainActor
@Observable
final class AppEnvironment {
    static let bundleID = "com.luxiang0412.EvidenceDesk"
    static let appDirectoryName = "EvidenceDesk"

    private let fileManager: FileManager
    /// Root of the sandboxed application support storage for the app.
    let storageRoot: URL
    /// Relative-path root at which attachments are stored.
    let attachmentsRoot: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let arguments = ProcessInfo.processInfo.arguments
        let root: URL
        if let argIndex = arguments.firstIndex(of: "--test-storage"),
           argIndex + 1 < arguments.count {
            root = URL(fileURLWithPath: arguments[argIndex + 1], isDirectory: true)
        } else if let nameIndex = arguments.firstIndex(of: "--test-storage-name"),
                  nameIndex + 1 < arguments.count {
            // Resolve inside this app's own sandbox temp directory, so the path
            // is writable regardless of where the test runner lives.
            let safeName = arguments[nameIndex + 1]
                .replacingOccurrences(of: "/", with: "-")
            root = fileManager.temporaryDirectory
                .appendingPathComponent("EvidenceDeskUITest", isDirectory: true)
                .appendingPathComponent(safeName, isDirectory: true)
            // Opt-in wipe so a UI test can start from a known-empty library.
            // Only ever applied to the isolated `EvidenceDeskUITest` subtree.
            if arguments.contains("--reset-test-storage") {
                try? fileManager.removeItem(at: root)
            }
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            root = base.appendingPathComponent(Self.appDirectoryName, isDirectory: true)
        }
        self.storageRoot = root
        self.attachmentsRoot = root.appendingPathComponent("Attachments", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: attachmentsRoot, withIntermediateDirectories: true)
    }

    /// True when launched with an explicit test storage location.
    var usesTestStorage: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--test-storage") || args.contains("--test-storage-name")
    }
}