import SwiftUI

@MainActor
struct TimelineEventEditorSheet: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    var existing: TimelineEvent? = nil
    let onDone: () -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var precision: DatePrecision = .exact
    @State private var date = Date()
    @State private var sourceSelection: UUID?
    @State private var notes = ""
    @State private var errorText: String?

    private var availableSources: [Source] {
        researchCase.sources.sorted { $0.shortCode < $1.shortCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(existing == nil ? "New Timeline Event" : "Edit Timeline Event")
                .font(DesignSystem.Typography.sectionTitle)

            TextField("Event title *", text: $title)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Description").font(DesignSystem.Typography.secondary)
                TextEditor(text: $detail)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Date precision").font(DesignSystem.Typography.secondary)
                Picker("Precision", selection: $precision) {
                    ForEach(DatePrecision.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if precision != .unknown {
                    DatePicker("Date", selection: $date, displayedComponents: displayComponents)
                } else {
                    Label("The event will appear in the “Date Undetermined” section.", systemImage: "questionmark.circle")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Linked source (optional)").font(DesignSystem.Typography.secondary)
                Picker("Source", selection: $sourceSelection) {
                    Text("None").tag(UUID?.none)
                    ForEach(availableSources) { s in
                        Text("\(s.shortCode) — \(s.title)").tag(Optional(s.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Notes (optional)").font(DesignSystem.Typography.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(colors.separator))
            }

            if let errorText {
                InlineErrorText(text: errorText)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 520)
        .onAppear {
            if let existing {
                title = existing.title
                detail = existing.detail
                precision = existing.datePrecision
                date = existing.date ?? Date()
                sourceSelection = existing.source?.id
                notes = existing.notes
            }
        }
    }

    private var displayComponents: DatePickerComponents {
        switch precision {
        case .exact: return .date
        case .yearMonth: return .date
        case .year: return .date
        case .unknown: return .date
        }
    }

    private func save() {
        errorText = nil
        guard let persistence else { return }
        let eventDate = precision == .unknown ? nil : date
        let chosenSource = availableSources.first { $0.id == sourceSelection }
        do {
            if let existing {
                try persistence.updateTimelineEvent(existing,
                                                    title: title,
                                                    detail: detail,
                                                    date: eventDate,
                                                    precision: precision,
                                                    source: chosenSource,
                                                    notes: notes)
            } else {
                _ = try persistence.createTimelineEvent(in: researchCase,
                                                        title: title,
                                                        detail: detail,
                                                        date: eventDate,
                                                        precision: precision,
                                                        source: chosenSource,
                                                        notes: notes)
            }
            onDone()
        } catch {
            errorText = error.localizedDescription
        }
    }
}