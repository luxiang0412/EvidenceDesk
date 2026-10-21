import SwiftUI

/// Picks an evidence item and a relation, then links it to the finding.
@MainActor
struct EvidenceLinkPickerSheet: View {
    @Bindable var researchCase: ResearchCase
    @Bindable var finding: Finding
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    let onDone: () -> Void

    @State private var searchText = ""
    @State private var selectedRef: UUID?
    @State private var relation: RelationType = .supports
    @State private var errorText: String?

    private var availableEvidence: [Evidence] {
        let q = searchText.localizedLowercase
        let unlinked = researchCase.evidences.filter { evidence in
            !finding.links.contains { $0.evidence?.id == evidence.id }
        }
        guard !q.isEmpty else { return unlinked.sorted { $0.shortCode < $1.shortCode } }
        return unlinked.filter {
            $0.text.localizedLowercase.contains(q) || $0.shortCode.localizedLowercase.contains(q)
        }.sorted { $0.shortCode < $1.shortCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Link Evidence to \(finding.shortCode)")
                .font(DesignSystem.Typography.sectionTitle)

            Picker("Relation", selection: $relation) {
                ForEach(RelationType.allCases) { r in
                    Label(r.displayName, systemImage: r.systemImage).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Evidence").font(DesignSystem.Typography.secondary)
                TextField("Search evidence", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if availableEvidence.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "quote.bubble").font(.system(size: 26)).foregroundStyle(.secondary)
                    Text("No unlinked evidence available.")
                        .font(DesignSystem.Typography.secondary)
                        .foregroundStyle(colors.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                List(selection: $selectedRef) {
                    ForEach(availableEvidence) { evidence in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(evidence.shortCode) · \(evidence.evidenceType.displayName)")
                                .font(DesignSystem.Typography.metadata)
                                .foregroundStyle(colors.secondaryText)
                            Text(evidence.text).lineLimit(2)
                        }
                        .tag(evidence.id as UUID?)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 200)
            }

            if let errorText {
                InlineErrorText(text: errorText)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Link") {
                    link()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedRef == nil)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 520, height: 460)
    }

    private func link() {
        guard let selectedRef, let evidence = researchCase.evidences.first(where: { $0.id == selectedRef }) else { return }
        do {
            try persistence?.linkEvidence(evidence, to: finding, relation: relation)
            onDone()
        } catch {
            errorText = error.localizedDescription
        }
    }
}