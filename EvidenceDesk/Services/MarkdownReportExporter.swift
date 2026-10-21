import Foundation

/// Pure Markdown report generator. Input is `ReportPayload`, output is a
/// readable Markdown document. It performs no file I/O.
enum MarkdownReportExporter {
    static let schemaVersion = 1

    /// Builds the citation for an evidence item, e.g. `[E-002, S-001, p. 3]`.
    static func citation(for evidence: ReportPayload.EvidenceInfo) -> String {
        var parts = [evidence.ref]
        if let sourceRef = evidence.sourceRef { parts.append(sourceRef) }
        if let page = evidence.pageNumber {
            parts.append("p. \(page)")
        }
        return "[\(parts.joined(separator: ", "))]"
    }

    static func generate(_ payload: ReportPayload) -> String {
        var out = MarkdownWriter()

        out.heading(1, payload.caseInfo.title)
        out.paragraph("Case \(payload.caseInfo.shortCode) · Generated \(dateString(payload.generatedAt))")
        out.blank()

        // Research question & scope
        out.heading(2, "Research Question")
        out.paragraph(payload.caseInfo.question.isEmpty ? "_No research question recorded._" : payload.caseInfo.question)
        out.blank()
        out.heading(2, "Research Scope / Background")
        out.paragraph(payload.caseInfo.scope.isEmpty ? "_No scope recorded._" : payload.caseInfo.scope)
        out.blank()

        // Findings
        out.heading(2, "Findings")
        if payload.findings.isEmpty {
            out.paragraph("_No findings recorded._")
        }
        for finding in payload.findings {
            out.blank()
            out.heading(3, "\(finding.ref) — \(finding.title)  _(\(finding.status.displayName))_")
            out.paragraph(finding.body.replacingOccurrences(of: "\n", with: "\n\n"))
            if !finding.uncertainty.isEmpty {
                out.blank()
                out.paragraph("**Uncertainty / open questions:** \(finding.uncertainty)")
            }
            if let supporting = finding.evidenceRefs[.supports], !supporting.isEmpty {
                out.blank()
                out.paragraph("**Supporting evidence:**")
                out.list(supporting.map { "\($0)" })
            }
            if let contradicting = finding.evidenceRefs[.contradicts], !contradicting.isEmpty {
                out.blank()
                out.paragraph("**Contradicting evidence:**")
                out.list(contradicting.map { "\($0)" })
            }
            if let context = finding.evidenceRefs[.context], !context.isEmpty {
                out.blank()
                out.paragraph("**Background evidence:**")
                out.list(context.map { "\($0)" })
            }
        }
        out.blank()

        // Evidence
        out.heading(2, "Evidence")
        if payload.evidences.isEmpty {
            out.paragraph("_No evidence recorded._")
        }
        for evidence in payload.evidences {
            out.blank()
            out.heading(3, "\(evidence.ref) — (\(evidence.type.displayName))")
            out.quote(evidence.text)
            var meta: [String] = []
            if let sourceRef = evidence.sourceRef {
                meta.append("Source: \(sourceRef)")
            } else {
                meta.append("Source: _personal note / unverified_")
            }
            if !evidence.locationNote.isEmpty { meta.append("Location: \(evidence.locationNote)") }
            if let page = evidence.pageNumber { meta.append("Page: \(page)") }
            if !evidence.userNotes.isEmpty { meta.append("Notes: \(evidence.userNotes)") }
            out.paragraph(meta.joined(separator: " · "))
        }
        out.blank()

        // Timeline
        out.heading(2, "Timeline")
        if payload.timeline.isEmpty {
            out.paragraph("_No timeline events recorded._")
        }
        let datedEvents = payload.timeline.filter { $0.precision != .unknown }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let unknownEvents = payload.timeline.filter { $0.precision == .unknown }
        for event in datedEvents {
            out.listItem("**\(dateOrPartial(event))** — \(event.title)")
            if !event.detail.isEmpty {
                out.paragraph(event.detail)
            }
            if !event.notes.isEmpty {
                out.paragraph("_Notes:_ \(event.notes)")
            }
            if let sourceRef = event.sourceRef {
                out.paragraph("_Source:_ \(sourceRef)")
            }
        }
        if !unknownEvents.isEmpty {
            out.blank()
            out.paragraph("**Date undetermined:**")
            for event in unknownEvents {
                out.listItem("\(event.title)")
            }
        }
        out.blank()

        // Sources
        out.heading(2, "Sources")
        if payload.sources.isEmpty {
            out.paragraph("_No sources recorded._")
        }
        for source in payload.sources {
            out.blank()
            out.paragraph("**\(source.ref) — \(source.title)** _(\(source.sourceType.displayName))_")
            var meta: [String] = []
            if let url = source.urlString, let urlValue = URL(string: url), urlValue.scheme == "http" || urlValue.scheme == "https" {
                meta.append("[\(url)](\(url))")
            } else if let rel = source.attachmentRelativePath {
                meta.append("Attachment: `\(rel)`")
            }
            if !source.publisher.isEmpty { meta.append("Publisher: \(source.publisher)") }
            if let published = source.publishedDate { meta.append("Published: \(dateString(published))") }
            if source.isMissing { meta.append("⚠️ attachment file missing") }
            if !source.userNotes.isEmpty { meta.append("Notes: \(source.userNotes)") }
            out.paragraph(meta.joined(separator: " · "))
        }
        out.blank()

        // Unresolved
        out.heading(2, "Unresolved Issues and Uncertainties")
        var unresolved = payload.unresolvedNotes
        for evidence in payload.evidences where evidence.type == .unresolved {
            unresolved.append("\(citation(for: evidence)) \(evidence.text)")
        }
        for finding in payload.findings where !finding.uncertainty.isEmpty {
            unresolved.append("\(finding.ref): \(finding.uncertainty)")
        }
        if unresolved.isEmpty {
            out.paragraph("_None recorded._")
        } else {
            out.list(unresolved)
        }

        return out.result
    }

    // MARK: - Helpers

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func dateOrPartial(_ event: ReportPayload.TimelineEventInfo) -> String {
        guard let date = event.date else { return "Date unknown" }
        switch event.precision {
        case .exact:
            let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
            return f.string(from: date)
        case .yearMonth:
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            return f.string(from: date)
        case .year:
            let f = DateFormatter(); f.dateFormat = "yyyy"
            return f.string(from: date)
        case .unknown:
            return "Date unknown"
        }
    }
}

/// Minimal line-based Markdown writer to avoid accidental malformed output.
struct MarkdownWriter {
    private(set) var result = ""

    mutating func heading(_ level: Int, _ text: String) {
        result += String(repeating: "#", count: level) + " " + text + "\n"
    }

    mutating func paragraph(_ text: String) {
        result += text + "\n"
    }

    mutating func quote(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            result += "> " + line + "\n"
        }
    }

    mutating func list(_ items: [String]) {
        for item in items {
            result += "- " + item + "\n"
        }
    }

    mutating func listItem(_ text: String) {
        result += "- " + text + "\n"
    }

    mutating func blank() {
        result += "\n"
    }
}