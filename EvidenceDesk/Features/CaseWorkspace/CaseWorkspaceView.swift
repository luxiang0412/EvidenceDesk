import SwiftUI

@MainActor
struct CaseWorkspaceView: View {
    @Bindable var researchCase: ResearchCase
    @Binding var inspectorVisible: Bool

    @State private var section: WorkspaceSection = .overview
    @StateObject private var router = CaseRouter()

    /// Dev/QA hook: `--ed-section sources` opens that section on launch.
    private static func launchSection() -> WorkspaceSection? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--ed-section"), i + 1 < args.count else { return nil }
        return WorkspaceSection(rawValue: args[i + 1])
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(WorkspaceSection.allCases) { s in
                    Label(s.title, systemImage: s.systemImage).tag(s)
                }
            }
            .onAppear {
                if let launch = Self.launchSection(), section != launch {
                    section = launch
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)

            Divider()

            ZStack {
                switch section {
                case .overview:
                    CaseOverviewView(researchCase: researchCase)
                case .sources:
                    SourcesSectionView(researchCase: researchCase)
                case .evidence:
                    EvidenceSectionView(researchCase: researchCase)
                case .findings:
                    FindingsSectionView(researchCase: researchCase)
                case .timeline:
                    TimelineSectionView(researchCase: researchCase)
                case .report:
                    ReportPreviewView(researchCase: researchCase)
                }
            }
            .id(researchCase.id) // reset section-local state when switching cases
        }
        .environmentObject(router)
        .onChange(of: router.pending.token) { _, _ in
            // Switch to the section that owns the requested destination.
            let pending = router.pending
            if pending.sourceID != nil {
                section = .sources
            } else if pending.evidenceID != nil {
                section = .evidence
            } else if pending.findingID != nil {
                section = .findings
            }
        }
        .navigationTitle(researchCase.title)
        .navigationSubtitle(researchCase.shortCode)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    AppActions.shared.send(.importSource)
                } label: {
                    Label("Import Source", systemImage: "plus.square.on.square")
                }
                .help("Import a source (⌘I)")

                Button {
                    section = .report
                    DispatchQueue.main.async {
                        AppActions.shared.send(.exportReport)
                    }
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .help("Export report (⌘⇧E)")
            }
        }
        .inspector(isPresented: $inspectorVisible) {
            CaseInspectorView(researchCase: researchCase)
        }
    }
}

/// Minimal inspector: shows an abbreviated case summary. It is hidden by
/// default and toggle via View → Toggle Inspector.
struct CaseInspectorView: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Case Details")
                .font(DesignSystem.Typography.sectionTitle)
            DetailRow(label: "Code", value: researchCase.shortCode)
            DetailRow(label: "Sources", value: "\(researchCase.sources.count)")
            DetailRow(label: "Evidence", value: "\(researchCase.evidences.count)")
            DetailRow(label: "Findings", value: "\(researchCase.findings.count)")
            DetailRow(label: "Updated", value: researchCase.updatedAt.formatted(date: .abbreviated, time: .shortened))
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(minWidth: DesignSystem.Layout.inspectorWidth, idealWidth: DesignSystem.Layout.inspectorWidth)
        .navigationSplitViewColumnWidth(DesignSystem.Layout.inspectorWidth)
        .background(colors.canvas)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    @Environment(\.designColors) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.t(label)).foregroundStyle(colors.secondaryText)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(DesignSystem.Typography.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L10n.t(label)): \(value)")
    }
}