import SwiftUI

@MainActor
struct SourceDetailView: View {
    @Bindable var source: Source
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors
    @Environment(\.openURL) private var openURL

    @Binding var pendingEvidence: String?
    @Binding var pendingEvidencePage: Int?

    @State private var confirmDelete = false
    @State private var keepEvidenceOption = true
    @State private var errorText: String?
    @State private var showRelocatePanel = false
    @State private var textPreview: String?
    @State private var textLoadFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                header

                if source.attachmentIsMissing {
                    ErrorBannerView(
                        message: "The attachment file for this source could not be found.",
                        retryTitle: "Re-link File…"
                    ) { showRelocatePanel = true }
                }

                if source.sourceType == .url {
                    urlCard
                } else if source.sourceType == .pdf {
                    pdfCard
                } else {
                    textCard
                }

                metadataForm

                if let errorText {
                    ErrorBannerView(message: errorText, retryTitle: "Retry") { performSave() }
                }

                Divider()

                dangerZone
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .navigationTitle(source.title)
        .sheet(isPresented: $showRelocatePanel) { relocateSheet }
        .fileImporter(isPresented: Binding(get: { relocateFileOpen }, set: { _ in relocateFileOpen = false }),
                      allowedContentTypes: [.pdf, .plainText, .text]) { result in
            if case .success(let url) = result {
                relocate(with: url)
            }
        }
        .confirmationDialog("Delete this source?", isPresented: $confirmDelete, titleVisibility: .visible) {
            if attachedEvidenceCount > 0 {
                Button("Delete Source and Keep Evidence") {
                    performDelete(keepEvidence: true)
                }
                Button(L10n.t("Delete Source and Its Evidence (%lld)", attachedEvidenceCount), role: .destructive) {
                    performDelete(keepEvidence: false)
                }
            } else {
                Button("Delete Source", role: .destructive) {
                    performDelete(keepEvidence: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            deleteMessage
        }
        .onAppear { loadTextPreviewIfNeeded() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Only the icon + titles form one announced unit. Buttons stay
            // individual elements so VoiceOver and automation can reach them.
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: source.sourceType.systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(DesignSystem.Typography.pageTitle)
                    Text("\(source.shortCode) · \(source.sourceType.displayName)")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(source.shortCode), \(source.title), \(source.sourceType.displayName)")
            Spacer()
            if source.sourceType == .url {
                Button {
                    if let urlString = source.urlString, let url = URL(string: urlString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open in Browser", systemImage: "safari")
                }
                .help("Opens the link in your default browser")
                .accessibilityLabel("Open in Browser")
                .accessibilityIdentifier("source.openInBrowser")
            }
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete Source")
            .accessibilityIdentifier("source.delete")
        }
    }

    private var attachedEvidenceCount: Int { source.evidences.count }

    @ViewBuilder
    private var deleteMessage: some View {
        if attachedEvidenceCount > 0 {
            Text(L10n.t("This source has %lld evidence item(s). They will either be kept as unlinked notes or deleted with the source.",
                        attachedEvidenceCount))
        } else {
            Text("This source will be removed. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var urlCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Link source", systemImage: "link")
                .font(DesignSystem.Typography.metadata)
                .foregroundStyle(colors.secondaryText)
            Text("This is a web link. Evidence Desk stores the address and the metadata you provide; it does not fetch or archive the page content. Any excerpt you record is captured by you, not verified against the live page.")
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(colors.secondaryText)
            if let urlString = source.urlString {
                Text(urlString)
                    .font(DesignSystem.Typography.monospacedSmall)
                    .textSelection(.enabled)
                    .foregroundStyle(colors.accent)
            }
            Button {
                createManualEvidence()
            } label: {
                Label("Add Evidence from This Source", systemImage: "quote.bubble")
            }
            .accessibilityIdentifier("source.addEvidence")
        }
        .padding(DesignSystem.Spacing.md)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    private func createManualEvidence() {
        pendingEvidence = " " // sentinel triggers editor, then cleared
        pendingEvidencePage = nil
    }

    @ViewBuilder
    private var pdfCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Reader").font(DesignSystem.Typography.sectionTitle)
                Spacer()
                if let size = source.attachmentFileSize {
                    Text("\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
            }
            PDFReaderView(source: source,
                          pendingEvidence: $pendingEvidence,
                          pendingEvidencePage: $pendingEvidencePage)
                .frame(minHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
        }
    }

    @ViewBuilder
    private var textCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Content").font(DesignSystem.Typography.sectionTitle)
                Spacer()
                if textLoadFailed {
                    Text("Couldn't read file").font(DesignSystem.Typography.metadata).foregroundStyle(.red)
                } else if textPreview == nil {
                    Text("Reading…").font(DesignSystem.Typography.metadata).foregroundStyle(colors.secondaryText)
                }
            }
            if let textPreview {
                Text(textPreview)
                    .font(DesignSystem.Typography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.md)
                    .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                    .textSelection(.enabled)
                Text("Showing the beginning of the file. Full content is preserved in the original attachment.")
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var metadataForm: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader("Metadata")
            TextField("Title", text: $source.title)
                .textFieldStyle(.roundedBorder)
            TextField("Publisher / site (optional)", text: $source.publisher)
                .textFieldStyle(.roundedBorder)
            if source.sourceType == .url {
                DatePicker("Published date (optional)",
                           selection: Binding(get: { source.publishedDate ?? Date() },
                                              set: { source.publishedDate = $0 }),
                           displayedComponents: .date)
                Toggle("No published date known", isOn: Binding(
                    get: { source.publishedDate == nil },
                    set: { if $0 { source.publishedDate = nil } }
                ))
                .toggleStyle(.checkbox)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Notes (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $source.userNotes)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }
            HStack {
                SaveStateIndicator(state: saveState)
                Spacer()
                Button("Save Metadata") { performSave() }
                    .accessibilityIdentifier("source.saveMetadata")
            }
        }
    }

    @State private var saveState: SaveState = .idle

    private func performSave() {
        saveState = .saving
        do {
            try persistence?.updateSourceMetadata(source,
                                                  title: source.title,
                                                  publisher: source.publisher,
                                                  notes: source.userNotes,
                                                  publishedDate: source.publishedDate)
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }

    @ViewBuilder
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Danger Zone").font(DesignSystem.Typography.sectionTitle)
            Text("Deleting a source removes it from this case. Related evidence is handled before deletion.")
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(colors.secondaryText)
        }
    }

    // MARK: - Relocation

    @State private var relocateFileOpen = false

    private var relocateSheet: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Re-link Attachment")
                .font(DesignSystem.Typography.sectionTitle)
            Text("Choose the file to restore for this source. The file will be copied into the app's storage.")
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(colors.secondaryText)
            HStack {
                Spacer()
                Button("Cancel") { showRelocatePanel = false }
                    .keyboardShortcut(.cancelAction)
                Button("Choose File…") {
                    showRelocatePanel = false
                    relocateFileOpen = true
                }
                .accessibilityIdentifier("source.relinkFile")
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 420)
    }

    private func relocate(with url: URL) {
        do {
            try persistence?.relocateAttachment(for: source, newFileURL: url)
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Delete

    private func performDelete(keepEvidence: Bool) {
        do {
            try persistence?.deleteSource(source, keepEvidence: keepEvidence)
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Text preview

    private func loadTextPreviewIfNeeded() {
        guard source.sourceType == .text, textPreview == nil else { return }
        guard let rel = source.attachmentRelativePath,
              let url = persistence?.attachments.resolve(urlForRelativePath: rel) else {
            textLoadFailed = true
            return
        }
        Task.detached {
            // Read only the first 200 KB for the preview; the original file is preserved.
            let handle = try? FileHandle(forReadingFrom: url)
            let data = try? handle?.read(upToCount: 200 * 1024)
            try? handle?.close()
            let string = data.flatMap { String(data: $0, encoding: .utf8) }
            await MainActor.run {
                if let string, !string.isEmpty {
                    textPreview = String(string.prefix(20_000))
                } else {
                    textLoadFailed = true
                }
            }
        }
    }
}