import SwiftUI

@MainActor
struct EvidenceSectionView: View {
    @Bindable var researchCase: ResearchCase
    @EnvironmentObject private var router: CaseRouter
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingEvidence: Evidence?

    private var sortedEvidence: [Evidence] {
        researchCase.evidences.sorted { $0.shortCode < $1.shortCode }
    }

    private var filteredEvidence: [Evidence] {
        guard !searchText.isEmpty else { return sortedEvidence }
        let q = searchText.localizedLowercase
        return sortedEvidence.filter {
            $0.text.localizedLowercase.contains(q)
            || $0.shortCode.localizedLowercase.contains(q)
            || ($0.source?.title.localizedLowercase.contains(q) ?? false)
        }
    }

    private var selectedEvidence: Evidence? {
        guard let selection else { return nil }
        return researchCase.evidences.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            evidenceList
                .background(colors.canvas)
            Divider()
            Group {
                if let evidence = selectedEvidence {
                    EvidenceDetailView(evidence: evidence,
                                       onEdit: { editingEvidence = evidence; showEditor = true },
                                       onDeleted: { selection = nil })
                } else {
                    EmptyStateView(
                        systemImage: "quote.bubble",
                        title: "No Evidence Selected",
                        message: "Select an evidence item, or create a new one from a source or your own notes.",
                        actionTitle: "New Evidence",
                        action: { editingEvidence = nil; showEditor = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search evidence")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingEvidence = nil
                    showEditor = true
                } label: {
                    Label("New Evidence", systemImage: "plus")
                }
                .help("New evidence item")
            }
        }
        .sheet(isPresented: $showEditor) {
            EvidenceEditorSheet(
                researchCase: researchCase,
                existing: editingEvidence,
                onDone: { showEditor = false; editingEvidence = nil }
            )
        }
        .onChange(of: router.pending.token) {
            if let evidenceID = router.pending.evidenceID {
                selection = evidenceID
            }
        }
    }

    private var evidenceList: some View {
        VStack(spacing: 0) {
            if filteredEvidence.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: searchText.isEmpty ? "quote.bubble" : "magnifyingglass")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No Evidence" : "No Matching Evidence")
                        .font(DesignSystem.Typography.secondary)
                    Text("Record excerpt quotes with their source and location.")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(filteredEvidence) { evidence in
                        EvidenceRowView(evidence: evidence)
                            .tag(evidence.id as UUID?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 300, idealWidth: 340)
    }
}

struct EvidenceRowView: View {
    let evidence: Evidence
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(evidence.shortCode)
                    .font(DesignSystem.Typography.monospacedSmall)
                    .foregroundStyle(colors.tertiaryText)
                Text(evidence.evidenceType.displayName)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
                Spacer()
                if let sourceRef = evidence.source?.shortCode {
                    Text("→ \(sourceRef)")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.tertiaryText)
                }
            }
            Text(evidence.text)
                .font(DesignSystem.Typography.body)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(evidence.shortCode), \(evidence.evidenceType.displayName), \(evidence.text)")
        .accessibilityIdentifier("evidenceRow.\(evidence.shortCode)")
        .accessibilityHint(evidence.source.map { "Source \($0.shortCode)" } ?? "Personal note, no source")
    }
}