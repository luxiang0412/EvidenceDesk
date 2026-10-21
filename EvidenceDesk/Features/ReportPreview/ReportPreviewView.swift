import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ReportPreviewView: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var generatedMarkdown: String = ""
    @State private var generatedAt: Date?
    @State private var exportState: ExportState = .idle

    enum ExportState: Equatable {
        case idle
        case exporting
        case success(String)
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            if generatedMarkdown.isEmpty {
                EmptyStateView(
                    systemImage: "doc.plaintext",
                    title: "Report Preview",
                    message: "Your report is generated from this case's question, findings, evidence, timeline and sources.",
                    actionTitle: "Generate Preview",
                    action: regenerate
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Read-only preview. TextEditor (NSTextView-backed) handles long
                // documents efficiently and is honest about it being the exported
                // Markdown source.
                TextEditor(text: .constant(generatedMarkdown))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { disableFocusRingsIfNeeded() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let generatedAt {
                    Text(L10n.t("Generated %@",
                                generatedAt.formatted(date: .abbreviated, time: .shortened)))
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
                Button("Regenerate", action: regenerate)
                    .accessibilityIdentifier("report.regenerate")
                Button {
                    exportMarkdown()
                } label: {
                    Label("Export as Markdown…", systemImage: "doc")
                }
                .disabled(generatedMarkdown.isEmpty || exportState == .exporting)
                .accessibilityLabel("Export as Markdown")
                .accessibilityIdentifier("report.exportMarkdown")

                Button {
                    exportCaseBundle()
                } label: {
                    Label("Export Case Bundle…", systemImage: "folder")
                }
                .disabled(exportState == .exporting)
                .accessibilityLabel("Export Case Bundle")
                .accessibilityIdentifier("report.exportBundle")
            }
        }
        .onReceive(AppActions.shared.publisher()) { action in
            if action == .exportReport, generatedMarkdown.isEmpty {
                regenerate()
            }
        }
        .overlay(alignment: .bottom) {
            exportFeedback
        }
        .onAppear {
            regenerate()
        }
        .onChange(of: researchCase.updatedAt) {
            regenerate()
        }
    }

    @ViewBuilder
    private var exportFeedback: some View {
        switch exportState {
        case .idle:
            EmptyView()
        case .exporting:
            HStack(spacing: DesignSystem.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Exporting…")
                    .font(DesignSystem.Typography.secondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(colors.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
            .padding()
        case .success(let path):
            Label(L10n.t("Exported to %@", path), systemImage: "checkmark.circle.fill")
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(.green)
                .padding(DesignSystem.Spacing.md)
                .background(colors.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                .padding()
        case .failed(let message):
            ErrorBannerView(message: message) { exportState = .idle }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: 520)
                .background(colors.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                .padding()
        }
    }

    private func disableFocusRingsIfNeeded() {
        // Leave default focus behaviour; this is a preview, but editing is off.
    }

    private func regenerate() {
        let payload = ReportPayloadBuilder.build(for: researchCase)
        generatedMarkdown = MarkdownReportExporter.generate(payload)
        generatedAt = payload.generatedAt
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.nameFieldStringValue = ReportExporter.markdownFilename(for: researchCase)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportState = .exporting
        do {
            try ReportExporter.exportMarkdown(for: researchCase, to: url)
            exportState = .success(url.lastPathComponent)
        } catch {
            exportState = .failed(error.localizedDescription)
        }
    }

    private func exportCaseBundle() {
        guard let persistence,
              let dir = FileSelectionHelper.openDirectory(title: "Choose export folder",
                                                          prompt: "Export case bundle here") else { return }
        exportState = .exporting
        do {
            let target = try ReportExporter.exportBundle(for: researchCase,
                                                         into: dir,
                                                         attachments: persistence.attachments)
            exportState = .success(target.lastPathComponent)
        } catch {
            exportState = .failed(error.localizedDescription)
        }
    }
}