import SwiftUI

struct LibrarySidebarView: View {
    let cases: [ResearchCase]
    @Binding var searchText: String
    @Binding var showArchived: Bool
    @Binding var selection: UUID?
    let onNewCase: () -> Void

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyTitle: String {
        if isSearching { return "No Matching Cases" }
        return showArchived ? "No Archived Cases" : "No Research Cases"
    }

    private var emptyMessage: String {
        if isSearching { return "Try a different title, question or case code." }
        return showArchived
            ? "Archived cases appear here. Archiving is not deleting."
            : "Create a case to begin a research project."
    }

    private var emptySymbol: String {
        if isSearching { return "magnifyingglass" }
        return showArchived ? "archivebox" : "tray"
    }

    var body: some View {
        VStack(spacing: 0) {
            if cases.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: emptySymbol,
                    title: emptyTitle,
                    message: emptyMessage,
                    actionTitle: (isSearching || showArchived) ? nil : "New Research Case",
                    action: (isSearching || showArchived) ? nil : onNewCase
                )
                .padding()
                Spacer()
            } else {
                List(selection: $selection) {
                    Section(showArchived ? "Archived Cases" : "Cases") {
                        ForEach(cases) { item in
                            CaseRowView(researchCase: item)
                                .tag(item.id as UUID?)
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { showArchived.toggle() }) {
                    Label(showArchived ? "Active Cases" : "Archived",
                          systemImage: showArchived ? "tray" : "archivebox")
                }
                .buttonStyle(.borderless)
                .help(showArchived ? "Show active cases" : "Show archived cases")
                .accessibilityLabel(showArchived ? "Show active cases" : "Show archived cases")

                Spacer()

                Button(action: onNewCase) {
                    Label("New Case", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("New research case (⌘N)")
                .accessibilityLabel("New research case")
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }
}

struct CaseRowView: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(researchCase.shortCode)
                    .font(DesignSystem.Typography.monospacedSmall)
                    .foregroundStyle(colors.tertiaryText)
                Text(researchCase.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            if !researchCase.researchQuestion.isEmpty {
                Text(researchCase.researchQuestion)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Research case")
        .accessibilityIdentifier("caseRow.\(researchCase.shortCode)")
    }

    private var accessibilityDescription: String {
        var parts = [researchCase.shortCode, researchCase.title]
        if !researchCase.researchQuestion.isEmpty {
            parts.append(researchCase.researchQuestion)
        }
        return parts.joined(separator: ", ")
    }
}