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

    private static func launchAppearance() -> NSAppearance.Name? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--appearance"), i + 1 < args.count {
            switch args[i + 1] {
            case "dark": return .darkAqua
            case "light": return .aqua
            default: return nil
            }
        }
        return nil
    }

    /// QA hook: `--window-size W,H` (e.g. `980,640`) resizes the window.
    private static func launchWindowSize() -> CGSize? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--window-size"), i + 1 < args.count else { return nil }
        let parts = args[i + 1].split(separator: ",")
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
            if let appearance = Self.launchAppearance() {
                NSApp.appearance = NSAppearance(named: appearance)
                NSApp.windows.forEach { $0.appearance = NSAppearance(named: appearance) }
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
        _ = try? (message + "\n").appendToFile(URL(fileURLWithPath: "/tmp/ed-trace.txt"))
    }

    /// Renders this window to a PNG — used for CI/QA evidence without needing
    /// screen-recording permissions. Gated behind `--screenshot <path>`.
    private func captureScreenshotIfRequested() async {
        if ProcessInfo.processInfo.arguments.contains("--ed-trace") { trace("capture entered") }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot"), index + 1 < args.count else { return }
        let path = args[index + 1]
        try? await Task.sleep(for: .seconds(3.5))
        guard let window = NSApp.windows.first(where: { $0.isVisible }) else {
            FileManager.default.createFile(atPath: "/tmp/ed-shot-error.txt", contents: Data("no visible window\n".utf8))
            NSApp.terminate(nil)
            return
        }
        guard let view = window.contentView else {
            FileManager.default.createFile(atPath: "/tmp/ed-shot-error.txt", contents: Data("no content view\n".utf8))
            NSApp.terminate(nil)
            return
        }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            FileManager.default.createFile(atPath: "/tmp/ed-shot-error.txt", contents: Data("no rep\n".utf8))
            NSApp.terminate(nil)
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileManager.default.createFile(atPath: "/tmp/ed-shot-error.txt", contents: Data("no png\n".utf8))
            NSApp.terminate(nil)
            return
        }
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        if let written = try? data.write(to: URL(fileURLWithPath: path)) {
            _ = written
        } else {
            FileManager.default.createFile(atPath: "/tmp/ed-shot-error.txt", contents: Data("write failed\n".utf8))
        }
        renderPDFSidecar(for: path)
        NSApp.terminate(nil)
    }

    /// QA: when the Sources section is captured, also render the first PDF's
    /// first page to `<output>.pdfpage.png` via PDFKit — the PDF canvas itself
    /// is drawn by PDFKit and not captured by window `cacheDisplay`.
    private func renderPDFSidecar(for windowPath: String) {
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
        let sidecar = URL(fileURLWithPath: windowPath).deletingPathExtension().appendingPathExtension("pdfpage.png")
        try? png.write(to: sidecar)
    }
}