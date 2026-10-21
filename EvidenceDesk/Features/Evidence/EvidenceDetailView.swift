import SwiftUI

@MainActor
struct EvidenceDetailView: View {
    @Bindable var evidence: Evidence
    @EnvironmentObject private var router: CaseRouter
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    let onEdit: () -> Void
    let onDeleted: () -> Void

    @State private var confirmDelete = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                header

                Text(evidence.text)
                    .font(DesignSystem.Typography.body)
                    .textSelection(.enabled)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                    .accessibilityLabel("Evidence text: \(evidence.text)")

                Divider()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    SectionHeader("Details")
                    HStack(spacing: DesignSystem.Spacing.md) {
                        DetailRow(label: "Type", value: evidence.evidenceType.displayName)
                        if let page = evidence.pageNumber {
                            DetailRow(label: "Page", value: "\(page)")
                        }
                    }
                    if let source = evidence.source {
                        Button {
                            router.openSource(source.id, page: evidence.pageNumber)
                        } label: {
                            HStack {
                                Label("\(source.shortCode) — \(source.title)", systemImage: "arrow.up.right.square")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(colors.accent)
                        .help("Open this source")
                        .accessibilityHint("Opens the source in the Sources section")
                    } else {
                        Label("Personal note / no source", systemImage: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(colors.secondaryText)
                    }
                    if !evidence.locationNote.isEmpty {
                        DetailRow(label: "Location", value: evidence.locationNote)
                    }
                    if !evidence.userNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notes").font(DesignSystem.Typography.secondary).foregroundStyle(colors.secondaryText)
                            Text(evidence.userNotes).textSelection(.enabled)
                        }
                    }
                    HStack {
                        Text("Created \(evidence.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(DesignSystem.Typography.metadata)
                            .foregroundStyle(colors.tertiaryText)
                        if evidence.updatedAt != evidence.createdAt {
                            Text("· Updated \(evidence.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(DesignSystem.Typography.metadata)
                                .foregroundStyle(colors.tertiaryText)
                        }
                    }
                }

                linkedFindings

                if let errorText {
                    ErrorBannerView(message: errorText)
                }

                HStack {
                    Button("Edit…", action: onEdit)
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete Evidence", systemImage: "trash")
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("\(evidence.shortCode)")
        .confirmationDialog("Delete this evidence?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if evidence.findingLinks.count > 0 {
                Text("It is linked to \(evidence.findingLinks.count) finding(s). Deleting it removes those links too.")
            } else {
                Text("This evidence item will be removed.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: evidence.evidenceType.systemImage)
                .font(.system(size: 26))
                .foregroundStyle(color(for: evidence.evidenceType))
            VStack(alignment: .leading, spacing: 2) {
                Text(evidence.shortCode)
                    .font(DesignSystem.Typography.pageTitle)
                Text(evidence.evidenceType.displayName)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(color(for: evidence.evidenceType))
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(evidence.shortCode), \(evidence.evidenceType.displayName)")
    }

    private func color(for type: EvidenceType) -> Color {
        switch type {
        case .fact: return colors.fact
        case .interpretation: return colors.inference
        case .hypothesis: return colors.hypothesis
        case .unresolved: return colors.unresolved
        }
    }

    @ViewBuilder
    private var linkedFindings: some View {
        let links = evidence.findingLinks
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader("Linked Findings")
            if links.isEmpty {
                Text("Not linked to any finding.")
                    .font(DesignSystem.Typography.secondary)
                    .foregroundStyle(colors.secondaryText)
            } else {
                ForEach(links) { link in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        relationTypeTag(link.relationType, colors: colors)
                        if let finding = link.finding {
                            Button("\(finding.shortCode) — \(finding.title)") {
                                router.openFinding(finding.id)
                            }
                            .buttonStyle(.link)
                        } else {
                            Text("(removed finding)").foregroundStyle(colors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
                }
            }
        }
    }

    private func delete() {
        do {
            try persistence?.deleteEvidence(evidence)
            onDeleted()
        } catch {
            errorText = error.localizedDescription
        }
    }
}