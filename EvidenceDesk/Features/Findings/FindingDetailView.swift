import SwiftUI

@MainActor
struct FindingDetailView: View {
    @Bindable var finding: Finding
    @EnvironmentObject private var router: CaseRouter
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    let onEdit: () -> Void
    let onDeleted: () -> Void

    @State private var showLinkPicker = false
    @State private var confirmDelete = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                header
                Divider()

                if !finding.body.isEmpty {
                    Text(finding.body)
                        .font(DesignSystem.Typography.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Spacing.md)
                        .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                } else {
                    Label("No analysis written yet. A finding with no body does not generate a report conclusion.",
                          systemImage: "pencil.slash")
                        .foregroundStyle(colors.secondaryText)
                        .font(DesignSystem.Typography.secondary)
                }

                if !finding.uncertainty.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uncertainty / open questions")
                            .font(DesignSystem.Typography.secondary)
                            .foregroundStyle(.orange)
                        Text(finding.uncertainty)
                            .font(DesignSystem.Typography.body)
                            .textSelection(.enabled)
                    }
                }

                HStack {
                    SectionHeader("Linked Evidence")
                    Button {
                        showLinkPicker = true
                    } label: {
                        Label("Link Evidence", systemImage: "link.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                linkedGroups

                if let errorText {
                    ErrorBannerView(message: errorText)
                }

                HStack {
                    Button("Edit…", action: onEdit)
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete Finding", systemImage: "trash")
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("\(finding.shortCode) — \(finding.title)")
        .sheet(isPresented: $showLinkPicker) {
            if let researchCase = finding.case {
                EvidenceLinkPickerSheet(researchCase: researchCase, finding: finding) {
                    showLinkPicker = false
                }
            } else {
                Text("Case unavailable.")
            }
        }
        .confirmationDialog("Delete this finding?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its \(finding.links.count) evidence link(s) will also be removed.")
        }
        .onChange(of: router.pending.token) {
            // When navigating from evidence to finding, highlight the section.
            // (Section switch is handled by the workspace.)
        }
    }

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: finding.status == .active ? "circle.circle.fill" : finding.status == .draft ? "pencil" : "arrow.uturn.backward")
                .font(.system(size: 26))
                .foregroundStyle(finding.status == .active ? colors.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.shortCode)
                    .font(DesignSystem.Typography.pageTitle)
                Text(finding.status.displayName)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(finding.shortCode), \(finding.status.displayName)")
    }

    @ViewBuilder
    private var linkedGroups: some View {
        if finding.links.isEmpty {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "link").font(.system(size: 26)).foregroundStyle(.secondary)
                Text("No evidence linked yet.")
                    .font(DesignSystem.Typography.secondary)
                    .foregroundStyle(colors.secondaryText)
                Button("Link Evidence") { showLinkPicker = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            ForEach(RelationType.allCases) { relation in
                let links = finding.links.filter { $0.relationType == relation }
                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(relation.displayName)
                            .font(DesignSystem.Typography.sectionTitle)
                            .foregroundStyle(color(for: relation))
                        ForEach(links) { link in
                            linkRow(link)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow(_ link: FindingEvidenceLink) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: link.relationType.systemImage)
                .foregroundStyle(color(for: link.relationType))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                if let evidence = link.evidence {
                    Button {
                        router.openEvidence(evidence.id)
                    } label: {
                        Text("\(evidence.shortCode) — \(evidence.text)")
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(colors.primaryText)
                    HStack(spacing: 6) {
                        if let source = evidence.source {
                            Text(source.shortCode)
                                .font(DesignSystem.Typography.metadata)
                                .foregroundStyle(colors.tertiaryText)
                        }
                        if let page = evidence.pageNumber {
                            Text("p. \(page)")
                                .font(DesignSystem.Typography.metadata)
                                .foregroundStyle(colors.tertiaryText)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(linkMetadata(for: evidence))
                } else {
                    Text("(removed evidence)")
                        .foregroundStyle(colors.secondaryText)
                }
            }
            Spacer()
            Menu {
                Button("Change to Supports") { change(link, to: .supports) }
                Button("Change to Contradicts") { change(link, to: .contradicts) }
                Button("Change to Background") { change(link, to: .context) }
                Divider()
                Button("Remove Link", role: .destructive) { remove(link) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Change relation or remove link")
        }
        .padding(DesignSystem.Spacing.sm)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
    }

    private func linkMetadata(for evidence: Evidence) -> String {
        var parts: [String] = []
        if let source = evidence.source { parts.append(source.shortCode) }
        if let page = evidence.pageNumber { parts.append("page \(page)") }
        return parts.joined(separator: ", ")
    }

    private func color(for relation: RelationType) -> Color {
        switch relation {
        case .supports: return colors.success
        case .contradicts: return colors.danger
        case .context: return colors.inference
        }
    }

    private func change(_ link: FindingEvidenceLink, to relation: RelationType) {
        do {
            try persistence?.changeLinkRelation(link, relation: relation)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func remove(_ link: FindingEvidenceLink) {
        do {
            try persistence?.unlinkEvidence(link)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try persistence?.deleteFinding(finding)
            onDeleted()
        } catch {
            errorText = error.localizedDescription
        }
    }
}