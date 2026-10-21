import SwiftData
import SwiftUI

struct AddCaseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.designColors) private var colors
    @Environment(\.persistence) private var persistence

    let onCreated: (ResearchCase) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var question = ""
    @State private var scope = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("New Research Case")
                .font(DesignSystem.Typography.sectionTitle)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                if errorText != nil {
                    Text("A title is required.")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Research Question").font(DesignSystem.Typography.secondary)
                TextEditor(text: $question)
                    .font(DesignSystem.Typography.body)
                    .frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Research Scope / Background").font(DesignSystem.Typography.secondary)
                TextEditor(text: $scope)
                    .font(DesignSystem.Typography.body)
                    .frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create Case", action: create)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 480)
    }

    private func create() {
        guard let persistence else { return }
        do {
            let created = try persistence.createCase(title: title, researchQuestion: question, researchScope: scope)
            onCreated(created)
        } catch {
            errorText = error.localizedDescription
        }
    }
}