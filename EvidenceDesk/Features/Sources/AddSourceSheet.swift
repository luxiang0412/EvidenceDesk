import SwiftUI
import UniformTypeIdentifiers

/// Entry sheet for adding a source: either a pasted URL or an imported file
/// (via system panel or drag & drop).
@MainActor
struct AddSourceSheet: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence

    let onDone: () -> Void

    enum Mode { case choose, url, file }
    @State private var mode: Mode = .choose

    @State private var urlText = ""
    @State private var title = ""
    @State private var publisher = ""
    @State private var notes = ""
    @State private var importedFileURL: URL?
    @State private var errorText: String?
    @State private var isImporting = false

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Import Source")
                .font(DesignSystem.Typography.sectionTitle)

            Picker("Mode", selection: $mode) {
                Text("Link (URL)").tag(Mode.url)
                Text("File (PDF / TXT / MD)").tag(Mode.file)
            }
            .pickerStyle(.segmented)

            switch mode {
            case .choose:
                EmptyView()
            case .url:
                urlForm
            case .file:
                fileForm
            }

            if let errorText {
                InlineErrorText(text: errorText)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button(action: { Task { await commit() } }) {
                    Text(commitButtonTitle)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCommit || isImporting)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 540)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .strokeBorder(DesignSystem.lightColors.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - URL form

    private var urlForm: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Web address (http / https)").font(DesignSystem.Typography.secondary)
                TextField("https://example.com/article", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Title (optional)").font(DesignSystem.Typography.secondary)
                TextField("Page title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Publisher / site").font(DesignSystem.Typography.secondary)
                    TextField("e.g. Example News", text: $publisher)
                        .textFieldStyle(.roundedBorder)
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Notes (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $notes)
                    .frame(height: 60)
                    .accessibilityLabel("Source notes")
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            }
            Text("This stores the link and the metadata you provide. Web page content is not fetched.")
                .font(DesignSystem.Typography.metadata)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - File form

    private var fileForm: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Button("Choose File…") {
                    let urls = FileSelectionHelper.openFiles(
                        allowedContentTypes: [.pdf, .plainText, .text],
                        allowsMultiple: false
                    )
                    if let first = urls.first { importedFileURL = first }
                }
                if let importedFileURL {
                    Label(importedFileURL.lastPathComponent, systemImage: "doc.fill")
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Drop a PDF, TXT or MD file here, or choose one. (max 100 MB)")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Title (optional, defaults to file name)").font(DesignSystem.Typography.secondary)
                TextField("Source title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Notes (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $notes)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
            }
            if isImporting {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Importing…")
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        Task {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                let results = await ImportService.resolveDropProviders([provider])
                if case .file(let url, _, _) = results.first {
                    await MainActor.run {
                        importedFileURL = url
                        mode = .file
                    }
                } else if case .rejected(let msg) = results.first {
                    await MainActor.run { errorText = msg }
                } else if case .url(let url) = results.first {
                    await MainActor.run {
                        urlText = url.absoluteString
                        title = title.isEmpty ? url.host ?? "" : title
                        mode = .url
                    }
                }
            }
        }
    }

    private var canCommit: Bool {
        switch mode {
        case .choose: return false
        case .url: return !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return importedFileURL != nil && !isImporting
        }
    }

    private var commitButtonTitle: String {
        switch mode {
        case .choose: return "Import Source"
        case .url: return "Add Link Source"
        case .file: return "Import File"
        }
    }

    private func commit() async {
        errorText = nil
        guard let persistence else { return }
        switch mode {
        case .url:
            let offer = ImportService.validateURLOffer(urlText)
            switch offer {
            case .url(let url):
                let fallbackTitle = title.isEmpty ? url.host ?? url.absoluteString : title
                do {
                    try persistence.createURLSource(in: researchCase,
                                                    url: url,
                                                    title: fallbackTitle,
                                                    publisher: publisher,
                                                    notes: notes)
                    onDone()
                } catch {
                    errorText = error.localizedDescription
                }
            case .rejected(let message):
                errorText = message
            default:
                errorText = "Unsupported input."
            }
        case .file:
            guard let importedFileURL else { return }
            isImporting = true
            let offer = ImportService.validateFileOffer(importedFileURL)
            switch offer {
            case .file(let url, let type, let defaultTitle):
                do {
                    _ = try persistence.importFileSource(in: researchCase,
                                                         sourceURL: url,
                                                         sourceType: type,
                                                         title: title.isEmpty ? defaultTitle : title,
                                                         userNotes: notes)
                    onDone()
                } catch {
                    errorText = error.localizedDescription
                }
            case .rejected(let message):
                errorText = message
            default:
                errorText = "The file could not be used."
            }
            isImporting = false
        case .choose:
            break
        }
    }
}