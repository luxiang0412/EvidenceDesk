import PDFKit
import SwiftData
import SwiftUI

/// Runs the startup consistency check once, then shows the main window.
/// Recovery problems are surfaced to the user; nothing is silently deleted.
@MainActor
struct StartupView: View {
    @Environment(\.persistence) private var persistence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.designColors) private var colors

    @State private var started = false
    @State private var report: RecoveryReport?
    @State private var showRecovery = false

    /// QA hook: force light/dark for a single process.
    /// Accepts `EVIDENCE_DESK_APPEARANCE=dark|light` or `--appearance dark`.
    private static func launchAppearance() -> NSAppearance.Name? {
        var raw = ProcessInfo.processInfo.environment["EVIDENCE_DESK_APPEARANCE"]
        if raw == nil {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--appearance"), i + 1 < args.count {
                raw = args[i + 1]
            }
        }
        switch raw?.lowercased() {
        case "dark": return .darkAqua
        case "light": return .aqua
        default: return nil
        }
    }

    /// QA hook: resize the window at launch.
    /// Accepts `--window-size W,H` or `EVIDENCE_DESK_WINDOW_SIZE=WxH`.
    private static func launchWindowSize() -> CGSize? {
        let raw: String?
        if let value = ProcessInfo.processInfo.environment["EVIDENCE_DESK_WINDOW_SIZE"] {
            raw = value
        } else {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--window-size"), i + 1 < args.count {
                raw = args[i + 1]
            } else {
                raw = nil
            }
        }
        guard let raw else { return nil }
        let parts = raw.split(whereSeparator: { $0 == "," || $0 == "x" })
        guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) else { return nil }
        return CGSize(width: w, height: h)
    }

    private func applyLaunchWindowSize() {
        guard let size = Self.launchWindowSize(),
              let window = NSApp.windows.first(where: { $0.isVisible }) else { return }
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true)
    }

    var body: some View {
        Group {
            if started {
                MainWindowView()
            } else {
                ProgressView("Preparing workspace…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("task begin") }
            if let appearanceName = Self.launchAppearance() {
                let appearance = NSAppearance(named: appearanceName)
                NSApp.appearance = appearance
                NSApp.windows.forEach { $0.appearance = appearance }
                if let window = NSApp.windows.first(where: { $0.contentView != nil }) {
                    window.appearance = appearance
                    window.invalidateShadow()
                }
            }
            await runStartupCheck()
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("startup check done") }
            seedDemoIfRequested()
            applyLaunchWindowSize()
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("seed done") }
            await captureScreenshotIfRequested()
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("capture done") }
        }
        .alert("Data Check", isPresented: $showRecovery) {
            Button("OK") { showRecovery = false }
            if let orphans = report?.orphanAttachmentDirectories, !orphans.isEmpty {
                Button("Review Orphaned Attachments") { showRecovery = false }
            }
        } message: {
            if let report {
                Text(summary(for: report))
            }
        }
    }

    private func summary(for report: RecoveryReport) -> String {
        var parts: [String] = []
        if !report.missingAttachments.isEmpty {
            parts.append("\(report.missingAttachments.count) source attachment(s) could not be found. Open the affected source to re-link or remove it.")
        }
        if !report.orphanAttachmentDirectories.isEmpty {
            parts.append("\(report.orphanAttachmentDirectories.count) unattached file folder(s) were found. You can clean them up from Library settings.")
        }
        return parts.isEmpty ? "Workspace is consistent." : parts.joined(separator: "\n")
    }

    private func runStartupCheck() async {
        guard let persistence else {
            started = true
            return
        }
        let recovery = RecoveryService(modelContext: modelContext, attachments: persistence.attachments)
        do {
            let result = try await recovery.run()
            report = result
            if !result.missingAttachments.isEmpty || !result.orphanAttachmentDirectories.isEmpty {
                showRecovery = true
            }
        } catch {
            report = RecoveryReport(missingAttachments: [], orphanAttachmentDirectories: [])
        }
        started = true
    }

    /// QA/dev-only hooks (still gated behind explicit launch flags).
    private func seedDemoIfRequested() {
        guard let persistence else { return }
        do {
            try DemoDataSeeder.seedIfRequested(persistence: persistence)
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("seed ok") }
        } catch {
            if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("seed failed: \(error)") }
        }
    }

    private func trace(_ message: String) {
        _ = try? (message + "\n").appendToFile(FileManager.default.temporaryDirectory.appendingPathComponent("ed-trace.txt"))
    }

    /// Renders this window to a PNG — used for CI/QA evidence without needing
    /// screen-recording permissions. Gated behind `--screenshot <path>`.
    private func captureScreenshotIfRequested() async {
        if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("capture entered") }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot"), index + 1 < args.count else { return }
        let path = args[index + 1]
        try? await Task.sleep(for: .seconds(3.5))
        // Sandboxed launches may not report `isVisible` yet; bring the window
        // forward and fall back to any window with a content view.
        let window = NSApp.windows.first(where: { $0.isVisible })
            ?? NSApp.windows.first(where: { $0.contentView != nil })
        guard let window else {
            logShotFailure("no window")
            NSApp.terminate(nil)
            return
        }
        window.makeKeyAndOrderFront(nil)
        guard let view = window.contentView else {
            logShotFailure("no content view")
            NSApp.terminate(nil)
            return
        }
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else {
            logShotFailure("empty bounds")
            NSApp.terminate(nil)
            return
        }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            logShotFailure("no rep")
            NSApp.terminate(nil)
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            logShotFailure("no png")
            NSApp.terminate(nil)
            return
        }
        // The app is sandboxed: an arbitrary CLI-provided path may be outside the
        // container. Try the requested path first, then fall back to the app's
        // own temporary directory (the caller copies it from there).
        let requested = URL(fileURLWithPath: path)
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent(requested.lastPathComponent)
        var writtenURL: URL?
        if writeScreenshot(data, to: requested) {
            writtenURL = requested
        } else if writeScreenshot(data, to: fallback) {
            writtenURL = fallback
        }
        if let writtenURL {
            renderPDFSidecar(for: writtenURL)
        }
        NSApp.terminate(nil)
    }

    /// QA diagnostics: written inside the sandbox container temp directory.
    private func logShotFailure(_ message: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ed-shot-error.txt")
        _ = try? (message + "\n").appendToFile(url)
    }

    private func writeScreenshot(_ data: Data, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// QA: when the Sources section is captured, also render the first PDF's
    /// first page to `<output>.pdfpage.png` via PDFKit — the PDF canvas itself
    /// is drawn by PDFKit and not captured by window `cacheDisplay`.
    private func renderPDFSidecar(for windowURL: URL) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--ed-section"), i + 1 < args.count, args[i + 1] == "sources" else { return }
        guard let persistence else { return }
        let cases = (try? modelContext.fetch(FetchDescriptor<ResearchCase>())) ?? []
        guard let firstCase = cases.first,
              let pdfSource = firstCase.sources.first(where: { $0.sourceType == .pdf }),
              let rel = pdfSource.attachmentRelativePath,
              let url = persistence.attachments.resolve(urlForRelativePath: rel),
              let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return }
        let thumbnail = page.thumbnail(of: CGSize(width: 595, height: 842), for: .mediaBox)
        guard let tiff = thumbnail.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let sidecar = windowURL.deletingPathExtension().appendingPathExtension("pdfpage.png")
        try? png.write(to: sidecar)
    }
}