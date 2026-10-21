import SwiftUI

@MainActor
struct TimelineSectionView: View {
    @Bindable var researchCase: ResearchCase
    @Environment(\.persistence) private var persistence
    @Environment(\.designColors) private var colors

    @State private var showEditor = false
    @State private var editingEvent: TimelineEvent?
    @State private var errorText: String?

    private var datedEvents: [TimelineEvent] {
        researchCase.timelineEvents
            .filter { $0.date != nil && $0.datePrecision != .unknown }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var undatedEvents: [TimelineEvent] {
        researchCase.timelineEvents.filter { $0.date == nil || $0.datePrecision == .unknown }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                HStack {
                    SectionHeader("Timeline")
                    Spacer()
                    Button {
                        editingEvent = nil
                        showEditor = true
                    } label: {
                        Label("New Event", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if researchCase.timelineEvents.isEmpty {
                    EmptyStateView(
                        systemImage: "clock",
                        title: "No Timeline Events",
                        message: "Add events with dates you know — or leave the date unknown and it will be kept in a separate undetermined section. Nothing is faked.",
                        actionTitle: "New Event",
                        action: { editingEvent = nil; showEditor = true }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                } else {
                    timelineList
                    if !undatedEvents.isEmpty {
                        Divider().padding(.vertical, DesignSystem.Spacing.md)
                        SectionHeader("Date Undetermined")
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            ForEach(undatedEvents) { event in
                                TimelineEventRow(event: event, onEdit: { editingEvent = event; showEditor = true })
                            }
                        }
                    }
                }

                if let errorText {
                    ErrorBannerView(message: errorText)
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .sheet(isPresented: $showEditor) {
            TimelineEventEditorSheet(researchCase: researchCase, existing: editingEvent) {
                showEditor = false
                editingEvent = nil
            }
        }
    }

    @ViewBuilder
    private var timelineList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(datedEvents.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(colors.accent)
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)
                        if index < datedEvents.count - 1 {
                            Rectangle()
                                .fill(colors.separator)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .padding(.trailing, DesignSystem.Spacing.md)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        TimelineEventRow(event: event, onEdit: { editingEvent = event; showEditor = true })
                    }
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
    }
}

struct TimelineEventRow: View {
    let event: TimelineEvent
    let onEdit: () -> Void
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                Text(displayDate)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.accent)
                    .frame(width: 90, alignment: .leading)
                    .accessibilityLabel("Date: \(displayDate)")
                Text(event.title)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit event")
            }
            if !event.detail.isEmpty {
                Text(event.detail)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(colors.secondaryText)
            }
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let source = event.source {
                    Text("Source: \(source.shortCode)")
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.tertiaryText)
                }
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayDate), \(event.title)" + (event.detail.isEmpty ? "" : ", \(event.detail)"))
        .accessibilityHint("Timeline event. Activates the edit button.")
        .accessibilityIdentifier("timelineRow.\(event.title)")
    }

    private var displayDate: String {
        guard let date = event.date else { return "Date unknown" }
        switch event.datePrecision {
        case .exact:
            return date.formatted(date: .abbreviated, time: .omitted)
        case .yearMonth:
            let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f.string(from: date)
        case .year:
            let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: date)
        case .unknown:
            return "Date unknown"
        }
    }
}