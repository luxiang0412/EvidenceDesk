import SwiftUI

@MainActor
struct CaseOverviewView: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var title: String = ""
    @State private var question: String = ""
    @State private var scope: String = ""
    @State private var saveState: SaveState = .idle
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                SectionHeader("Case Overview")

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignSystem.Typography.body)
                        .onChange(of: title) { scheduleSave() }

                    Text("\(researchCase.shortCode) · Created \(researchCase.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Research Question").font(DesignSystem.Typography.sectionTitle)
                    TextEditor(text: $question)
                        .font(DesignSystem.Typography.body)
                        .accessibilityLabel("Research question")
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.small).strokeBorder(colors.separator))
                        .onChange(of: question) { scheduleSave() }
                    Text("What are you trying to resolve?")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Research Scope / Background").font(DesignSystem.Typography.sectionTitle)
                    TextEditor(text: $scope)
                        .font(DesignSystem.Typography.body)
                        .accessibilityLabel("Research scope and background")
                        .frame(minHeight: 110)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.small).strokeBorder(colors.separator))
                        .onChange(of: scope) { scheduleSave() }
                }

                HStack {
                    SaveStateIndicator(state: saveState)
                    Spacer()
                    Button("Save Now") { performSave() }
                        .disabled(saveState == .saving)
                }

                caseStats

                if case .failed(let message) = saveState {
                    ErrorBannerView(message: message, retryTitle: "Retry") {
                        performSave()
                    }
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear {
            title = researchCase.title
            question = researchCase.researchQuestion
            scope = researchCase.researchScope
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    @ViewBuilder
    private var caseStats: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            StatCard(value: "\(researchCase.sources.count)", label: "Sources", icon: "books.vertical")
            StatCard(value: "\(researchCase.evidences.count)", label: "Evidence", icon: "quote.bubble")
            StatCard(value: "\(researchCase.findings.count)", label: "Findings", icon: "lightbulb")
            StatCard(value: "\(researchCase.timelineEvents.count)", label: "Timeline", icon: "clock")
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    private func scheduleSave() {
        debounceTask?.cancel()
        saveState = .saving
        let snapshot = (title: title, question: question, scope: scope)
        debounceTask = Task { [weak researchCase] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let caseRef = researchCase else { return }
            await MainActor.run {
                do {
                    try persistence?.updateCase(caseRef, title: snapshot.title, question: snapshot.question, scope: snapshot.scope)
                    saveState = .saved
                } catch {
                    saveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func performSave() {
        debounceTask?.cancel()
        saveState = .saving
        do {
            try persistence?.updateCase(researchCase, title: title, question: question, scope: scope)
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(colors.secondaryText)
                Text(value).font(.system(.title3, design: .rounded).weight(.semibold))
            }
            Text(label)
                .font(DesignSystem.Typography.metadata)
                .foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}