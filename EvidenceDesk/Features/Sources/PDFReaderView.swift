import SwiftUI
import PDFKit

/// Observable state produced by the PDF reader (selection only; the view
/// stays in AppKit).
@MainActor
final class PDFReaderModel: ObservableObject {
    @Published var selectionText = ""
    @Published var selectionPage: Int?
    @Published var pageCount = 0
    @Published var isPasswordProtected = false
    @Published var loadFailed = false

    func clearSelection() {
        selectionText = ""
        selectionPage = nil
    }
}

/// Wraps PDFKit's PDFView in SwiftUI. Selection changes flow out through
/// `PDFReaderModel`; zoom and page controls are exposed by `PDFReaderControls`.
struct PDFReaderCanvas: NSViewRepresentable {
    let url: URL
    let model: PDFReaderModel
    /// Controller used for toolbar actions (zoom / page turning).
    @Binding var controls: PDFReaderControls?

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.delegate = context.coordinator
        if let document = PDFDocument(url: url) {
            if document.isLocked {
                model.isPasswordProtected = true
            } else {
                pdfView.document = document
                model.pageCount = document.pageCount
            }
        } else {
            model.loadFailed = true
        }
        context.coordinator.pdfView = pdfView
        controls = PDFReaderControls(pdfView: pdfView, model: model)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}

    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        coordinator.pdfView?.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, PDFViewDelegate {
        weak var pdfView: PDFView?
        let model: PDFReaderModel

        init(model: PDFReaderModel) {
            self.model = model
        }

        func pdfViewSelectionChanged(_ notification: Notification) {
            guard let view = pdfView else { return }
            guard let selection = view.currentSelection else {
                model.clearSelection()
                return
            }
            if let extracted = PDFSelectionService.extract(from: selection) {
                model.selectionText = extracted.text
                model.selectionPage = extracted.pageNumber
            } else {
                model.clearSelection()
            }
        }
    }
}

/// Toolbar-facing controls for a running PDFView.
@MainActor
final class PDFReaderControls {
    weak var pdfView: PDFView?
    weak var model: PDFReaderModel?

    init(pdfView: PDFView, model: PDFReaderModel) {
        self.pdfView = pdfView
        self.model = model
    }

    func zoomIn() { pdfView?.zoomIn(nil) }
    func zoomOut() { pdfView?.zoomOut(nil) }
    func zoomToFit() { pdfView?.autoScales = true; pdfView?.scaleFactor = pdfView?.scaleFactorForSizeToFit ?? 1 }

    var currentPageNumber: Int? {
        guard let view = pdfView, let doc = view.document else { return nil }
        let pageIndex = doc.index(for: view.currentPage ?? doc.page(at: 0)!)
        return pageIndex + 1
    }

    func goTo(page: Int) {
        guard let doc = pdfView?.document, page >= 1, page <= doc.pageCount else { return }
        if let target = doc.page(at: page - 1) {
            pdfView?.go(to: target)
        }
    }

    func pageCount() -> Int { pdfView?.document?.pageCount ?? 0 }
}

/// SwiftUI view hosting the PDF inside the source detail, together with a
/// slim reader toolbar.
struct PDFReaderView: View {
    let source: Source
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @StateObject private var model = PDFReaderModel()
    @State private var controls: PDFReaderControls?

    /// Request to create evidence from the current selection.
    @Binding var pendingEvidence: String?
    @Binding var pendingEvidencePage: Int?

    var body: some View {
        VStack(spacing: 0) {
            if model.isPasswordProtected {
                readerMessage(systemImage: "lock.fill",
                              title: "Password Protected",
                              message: "This PDF is locked. Provide an unlocked copy to read it here.")
            } else if model.loadFailed {
                readerMessage(systemImage: "exclamationmark.triangle",
                              title: "Couldn't Open PDF",
                              message: "This file could not be read as a PDF document.")
            } else {
                PDFReaderCanvas(url: resolvedURL, model: model, controls: $controls)
                    .background(Color(nsColor: .underPageBackgroundColor))

                Divider()
                readerToolbar
            }
        }
        .onDisappear {
            model.clearSelection()
        }
    }

    private var resolvedURL: URL {
        if let rel = source.attachmentRelativePath,
           let url = persistence?.attachments.resolve(urlForRelativePath: rel) {
            return url
        }
        return URL(fileURLWithPath: "/dev/null")
    }

    @ViewBuilder
    private var readerToolbar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button { controls?.zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")

            Button { controls?.zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")

            Button { controls?.zoomToFit() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Fit to page")

            Spacer()

            if let page = controls?.currentPageNumber {
                Text("Page \(page) of \(controls?.pageCount() ?? 0)")
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer()

            Button {
                pendingEvidence = model.selectionText
                pendingEvidencePage = model.selectionPage
                model.clearSelection()
            } label: {
                Label("New Evidence from Selection", systemImage: "quote.bubble")
            }
            .disabled(model.selectionText.isEmpty)
            .help(model.selectionText.isEmpty
                  ? "Select text in the PDF first"
                  : "Create an evidence item from the selected text")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(colors.canvas)
    }

    @ViewBuilder
    private func readerMessage(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: systemImage).font(.system(size: 36)).foregroundStyle(.secondary)
            Text(title).font(DesignSystem.Typography.sectionTitle)
            Text(message).font(DesignSystem.Typography.secondary).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}