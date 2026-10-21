import SwiftUI

@MainActor
struct FindingsSectionView: View {
    @Bindable var researchCase: ResearchCase
    @EnvironmentObject private var router: CaseRouter
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var selection: UUID?
    @State private var showEditor = false
    @State private var editingFinding: Finding?

    private var sortedFindings: [Finding] {
        researchCase.findings.sorted { $0.shortCode < $1.shortCode }
    }

    private var selectedFinding: Finding? {
        guard let selection else { return nil }
        return researchCase.findings.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            findingList
                .background(colors.canvas)
            Divider()
            Group {
                if let finding = selectedFinding {
                    FindingDetailView(finding: finding,
                                      onEdit: { editingFinding = finding; showEditor = true },
                                      onDeleted: { selection = nil })
                } else {
                    EmptyStateView(
                        systemImage: "lightbulb",
                        title: "No Finding Selected",
                        message: "Findings bring your evidence together. Create one and link supporting, contradicting or background evidence.",
                        actionTitle: "New Finding",
                        action: { editingFinding = nil; showEditor = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingFinding = nil
                    showEditor = true
                } label: {
                    Label("New Finding", systemImage: "plus")
                }
                .help("New finding")
            }
        }
        .sheet(isPresented: $showEditor) {
            FindingEditorSheet(researchCase: researchCase, existing: editingFinding) {
                showEditor = false
                editingFinding = nil
            }
        }
        .onChange(of: router.pending.token) {
            if let findingID = router.pending.findingID {
                selection = findingID
            }
        }
    }

    private var findingList: some View {
        VStack(spacing: 0) {
            if sortedFindings.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "lightbulb").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("No Findings")
                        .font(DesignSystem.Typography.secondary)
                    Text("Record conclusions or working hypotheses with linked evidence.")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(sortedFindings) { finding in
                        FindingRowView(finding: finding)
                            .tag(finding.id as UUID?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 300, idealWidth: 340)
    }
}

struct FindingRowView: View {
    let finding: Finding
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(finding.shortCode)
                    .font(DesignSystem.Typography.monospacedSmall)
                    .foregroundStyle(colors.tertiaryText)
                Text(finding.title).fontWeight(.medium).lineLimit(1)
                Spacer()
                Text(finding.status.displayName)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }
            if !finding.body.isEmpty {
                Text(finding.body)
                    .font(DesignSystem.Typography.secondary)
                    .foregroundStyle(colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(finding.shortCode), \(finding.title), \(finding.status.displayName)")
        .accessibilityIdentifier("findingRow.\(finding.shortCode)")
        .accessibilityHint(finding.body.isEmpty ? "No analysis written" : finding.body)
    }
}