import SwiftUI

/// Create or edit an evidence item.
@MainActor
struct EvidenceEditorSheet: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    // Editing mode
    var existing: Evidence? = nil
    // Create mode prefill
    var source: Source? = nil
    var prefillText: String? = nil
    var prefillPage: Int? = nil

    let onDone: () -> Void

    @State private var text = ""
    @State private var type: EvidenceType = .fact
    @State private var sourceSelection: UUID?
    @State private var locationNote = ""
    @State private var pageNumber: Int?
    @State private var userNotes = ""
    @State private var noSourceToggle = false
    @State private var errorText: String?
    @State private var saveState: SaveState = .idle

    private var availableSources: [Source] {
        researchCase.sources.sorted { $0.shortCode < $1.shortCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(existing == nil ? "New Evidence" : "Edit Evidence")
                .font(DesignSystem.Typography.sectionTitle)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Excerpt / text *").font(DesignSystem.Typography.secondary)
                // Multiline TextField rather than TextEditor: the NSTextView
                // backing TextEditor made SwiftUI crash while resolving
                // accessibility labels on sheet dismissal (D-014).
                TextField("Paste or type the excerpt", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
                    .lineLimit(5...12)
                    .padding(DesignSystem.Spacing.sm)
                    .accessibilityLabel("Excerpt text")
                    .accessibilityIdentifier("evidence.excerpt")
                    .frame(minHeight: 110, alignment: .topLeading)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.small).strokeBorder(colors.separator))
                // `Text(verbatim:)` avoids SwiftUI building an
                // AccessibilityAttachment for interpolated content, which
                // crashed label resolution when the sheet dismissed (D-014).
                Text(verbatim: "\(text.count) of 50,000 characters")
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
            }

            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Type").font(DesignSystem.Typography.secondary)
                    Picker("Type", selection: $type) {
                        ForEach(EvidenceType.allCases) { t in
                            Label(t.displayName, systemImage: t.systemImage).tag(t)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Toggle("Personal note / no source (unverified)", isOn: $noSourceToggle)
                    .toggleStyle(.checkbox)
                if noSourceToggle {
                    Text("This item is recorded by you and is not linked to a source.")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                } else {
                    Picker("Source", selection: $sourceSelection) {
                        Text("Select a source…").tag(UUID?.none)
                        ForEach(availableSources) { s in
                            Text("\(s.shortCode) — \(s.title)").tag(Optional(s.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(availableSources.isEmpty)
                    if availableSources.isEmpty {
                        Text("This case has no sources yet. Add a source first or mark this as a personal note.")
                            .font(DesignSystem.Typography.metadata)
                            .foregroundStyle(colors.secondaryText)
                    }
                }
            }

            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Location (optional)").font(DesignSystem.Typography.secondary)
                    TextField("e.g. p. 3, §2, custom citation", text: $locationNote)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Page (optional)").font(DesignSystem.Typography.secondary)
                    TextField("Page number", value: Binding(get: { pageNumber ?? 0 }, set: { pageNumber = $0 }),
                              format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Your notes (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $userNotes)
                    .frame(minHeight: 60)
                    .accessibilityLabel("Your notes")
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }

            HStack {
                SaveStateIndicator(state: saveState)
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorText {
                InlineErrorText(text: errorText)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 560)
        .onAppear(perform: loadInitialValues)
    }

    private func source(for id: UUID?) -> Source? {
        guard let id else { return nil }
        return availableSources.first { $0.id == id }
    }

    private func loadInitialValues() {
        if let existing {
            text = existing.text
            type = existing.evidenceType
            sourceSelection = existing.source?.id
            noSourceToggle = existing.source == nil
            locationNote = existing.locationNote
            pageNumber = existing.pageNumber
            userNotes = existing.userNotes
        } else {
            noSourceToggle = source == nil
            sourceSelection = source?.id
            text = prefillText ?? ""
            pageNumber = prefillPage
            if let prefillPage, locationNote.isEmpty {
                locationNote = "p. \(prefillPage)"
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
        let chosenSource = noSourceToggle ? nil : source(for: sourceSelection)
        do {
            if let existing {
                try persistence.updateEvidence(existing,
                                               text: text,
                                               type: type,
                                               source: chosenSource,
                                               locationNote: locationNote,
                                               pageNumber: pageNumber,
                                               userNotes: userNotes)
            } else {
                _ = try persistence.createEvidence(in: researchCase,
                                                   text: text,
                                                   type: type,
                                                   source: chosenSource,
                                                   locationNote: locationNote,
                                                   pageNumber: pageNumber,
                                                   userNotes: userNotes,
                                                   caseIsRequired: !noSourceToggle)
            }
            saveState = .saved
            // Dismiss on the next runloop turn: tearing the sheet down in the
            // same update that mutates the SwiftData graph made SwiftUI resolve
            // accessibility labels for a half-removed tree and crash inside
            // AccessibilityNode.attachment (see docs/DECISIONS.md D-014).
            Task { @MainActor in onDone() }
        } catch {
            saveState = .failed(error.localizedDescription)
            errorText = error.localizedDescription
        }
    }
}