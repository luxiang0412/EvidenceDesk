import SwiftUI

struct SourceListView: View {
    let sources: [Source]
    @Binding var selection: UUID?
    @Binding var searchText: String
    @Environment(\.designColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: searchText.isEmpty ? "books.vertical" : "magnifyingglass")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text(L10n.t(searchText.isEmpty ? "No Sources" : "No Matching Sources"))
                        .font(DesignSystem.Typography.secondary)
                    Text(L10n.t(searchText.isEmpty ? "Import a link, PDF, TXT or Markdown file." : "Try a different search."))
                        .font(DesignSystem.Typography.metadata)
                        .foregroundStyle(colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { source in
                        SourceRowView(source: source)
                            .tag(source.id as UUID?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 260, idealWidth: 300)
    }

    private var filtered: [Source] {
        guard !searchText.isEmpty else { return sources }
        let q = searchText.localizedLowercase
        return sources.filter {
            $0.title.localizedLowercase.contains(q)
            || $0.publisher.localizedLowercase.contains(q)
            || $0.originalFilename.localizedLowercase.contains(q)
            || $0.shortCode.localizedLowercase.contains(q)
            || ($0.urlString?.localizedLowercase.contains(q) ?? false)
        }
    }
}

struct SourceRowView: View {
    let source: Source
    @Environment(\.designColors) private var colors

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: source.sourceType.systemImage)
                .foregroundStyle(colors.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(source.shortCode)
                        .font(DesignSystem.Typography.monospacedSmall)
                        .foregroundStyle(colors.tertiaryText)
                    Text(source.title)
                        .lineLimit(1)
                    if source.attachmentIsMissing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Attachment file missing")
                    }
                }
                Text(meta)
                    .font(DesignSystem.Typography.metadata)
                    .foregroundStyle(colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("sourceRow.\(source.shortCode)")
        .accessibilityHint(source.sourceType == .url
            ? "Link source. Web page content is not fetched."
            : "\(source.sourceType.displayName) source")
    }

    private var accessibilityDescription: String {
        [source.shortCode, source.title, source.sourceType.displayName, meta]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var meta: String {
        var parts: [String] = []
        if source.sourceType == .url, let urlString = source.urlString {
            parts.append(host(of: urlString))
        } else if !source.originalFilename.isEmpty {
            parts.append(source.originalFilename)
        }
        if !source.publisher.isEmpty { parts.append(source.publisher) }
        if let date = source.publishedDate {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    private func host(of urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}