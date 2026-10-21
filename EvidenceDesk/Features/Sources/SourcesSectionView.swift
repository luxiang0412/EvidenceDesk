import SwiftUI

@MainActor
struct SourcesSectionView: View {
    @Bindable var researchCase: ResearchCase
    @EnvironmentObject private var router: CaseRouter
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var showAddSource = false
    @State private var pendingEvidence: String?
    @State private var pendingEvidencePage: Int?
    @State private var dropNotice: String?
    @State private var isDropTargeted = false

    private var sortedSources: [Source] {
        researchCase.sources.sorted { $0.shortCode < $1.shortCode }
    }

    private var selectedSource: Source? {
        guard let selection else { return nil }
        return researchCase.sources.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            SourceListView(sources: sortedSources, selection: $selection, searchText: $searchText)
                .background(colors.canvas)

            Divider()

            Group {
                if let source = selectedSource {
                    SourceDetailView(source: source,
                                     pendingEvidence: $pendingEvidence,
                                     pendingEvidencePage: $pendingEvidencePage)
                } else {
                    EmptyStateView(
                        systemImage: "books.vertical",
                        title: "No Source Selected",
                        message: "Select a source from the list, or import a new one.",
                        actionTitle: "Import Source",
                        action: { showAddSource = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSource = true
                } label: {
                    Label("Import Source", systemImage: "plus.square.on.square")
                }
                .help("Import a source")
            }
        }
        .sheet(isPresented: $showAddSource) {
            AddSourceSheet(researchCase: researchCase) {
                showAddSource = false
            }
        }
        .sheet(isPresented: Binding(get: { pendingEvidence != nil }, set: { if !$0 { pendingEvidence = nil } })) {
            if let text = pendingEvidence {
                EvidenceEditorSheet(
                    researchCase: researchCase,
                    source: selectedSource,
                    prefillText: text,
                    prefillPage: pendingEvidencePage
                ) {
                    pendingEvidence = nil
                    pendingEvidencePage = nil
                }
            }
        }
        .alert("Drop Result", isPresented: Binding(get: { dropNotice != nil }, set: { if !$0 { dropNotice = nil } })) {
            Button("OK") { dropNotice = nil }
        } message: {
            Text(dropNotice ?? "")
        }
        .onChange(of: router.pending.token) {
            if let sourceID = router.pending.sourceID {
                selection = sourceID
            }
        }
        .onAppear {
            // QA hook: `--ed-select S-002` pre-selects a source.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--ed-select"), i + 1 < args.count {
                let code = args[i + 1]
                if let match = sortedSources.first(where: { $0.shortCode == code }) {
                    selection = match.id
                }
            }
        }
        .onDrop(of: [.fileURL, .url], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .strokeBorder(colors.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        Task {
            let results = await ImportService.resolveDropProviders(providers)
            guard let persistence else { return }
            var messages: [String] = []
            var imported = 0
            for result in results {
                switch result {
                case .file(let url, let type, let defaultTitle):
                    do {
                        _ = try persistence.importFileSource(
                            in: researchCase,
                            sourceURL: url,
                            sourceType: type,
                            title: defaultTitle
                        )
                        imported += 1
                    } catch {
                        messages.append(error.localizedDescription)
                    }
                case .url(let url):
                    do {
                        _ = try persistence.createURLSource(in: researchCase, url: url, title: url.host ?? url.absoluteString)
                        imported += 1
                    } catch {
                        messages.append(error.localizedDescription)
                    }
                case .rejected(let message):
                    messages.append(message)
                case .unresolved:
                    messages.append("One or more items could not be read as files.")
                }
            }
            let summary: String?
            if imported > 0 && messages.isEmpty {
                summary = nil
            } else if imported > 0 {
                summary = "Imported \(imported). " + messages.joined(separator: "\n")
            } else if messages.isEmpty {
                summary = "Nothing to import."
            } else {
                summary = messages.joined(separator: "\n")
            }
            if let summary {
                await MainActor.run { dropNotice = summary }
            }
        }
    }
}