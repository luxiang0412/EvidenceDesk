import SwiftUI

@MainActor
struct FindingEditorSheet: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    var existing: Finding? = nil
    let onDone: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var status: FindingStatus = .draft
    @State private var uncertainty = ""
    @State private var errorText: String?
    @State private var saveState: SaveState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(existing == nil ? "New Finding" : "Edit Finding")
                .font(DesignSystem.Typography.sectionTitle)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Title *").font(DesignSystem.Typography.secondary)
                TextField("e.g. The tender appears to prioritise incumbents", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Body / analysis").font(DesignSystem.Typography.secondary)
                TextEditor(text: $bodyText)
                    .font(DesignSystem.Typography.body)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.small).strokeBorder(colors.separator))
            }

            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Status").font(DesignSystem.Typography.secondary)
                    Picker("Status", selection: $status) {
                        ForEach(FindingStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Uncertainty / open questions (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $uncertainty)
                    .frame(minHeight: 56)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
                Text("\"Active\" means you are working with this finding — it does not claim the finding is proved.")
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }

            HStack {
                SaveStateIndicator(state: saveState)
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorText {
                InlineErrorText(text: errorText)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 560)
        .onAppear {
            if let existing {
                title = existing.title
                bodyText = existing.body
                status = existing.status
                uncertainty = existing.uncertainty
            }
        }
    }

    private func save() {
        errorText = nil
        saveState = .saving
        guard let persistence else {
            saveState = .failed("Storage not ready.")
            return
        }
        do {
            if let existing {
                try persistence.updateFinding(existing, title: title, body: bodyText, status: status, uncertainty: uncertainty)
            } else {
                _ = try persistence.createFinding(in: researchCase, title: title, body: bodyText, status: status, uncertainty: uncertainty)
            }
            saveState = .saved
            onDone()
        } catch {
            saveState = .failed(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
}