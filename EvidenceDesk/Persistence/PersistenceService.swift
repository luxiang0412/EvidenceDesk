import Foundation
import SwiftData

enum PersistenceError: Error, LocalizedError, Equatable {
    case saveFailed(String)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let detail):
            return "Your changes could not be saved. \(detail)"
        case .itemNotFound:
            return "That item no longer exists."
        }
    }
}

/// Central, testable service for every write operation. Views call this service;
/// they never touch `ModelContext` directly for mutations.
@MainActor
final class PersistenceService {
    let modelContext: ModelContext
    let attachments: AttachmentStore

    init(modelContext: ModelContext, attachments: AttachmentStore) {
        self.modelContext = modelContext
        self.attachments = attachments
    }

    static func makeShared(environment: AppEnvironment) throws -> PersistenceService {
        let container = try ModelContainerFactory.make(storageRoot: environment.storageRoot)
        let attachments = AttachmentStore(root: environment.attachmentsRoot)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return PersistenceService(modelContext: context, attachments: attachments)
    }

    static func makeInMemory() throws -> PersistenceService {
        let container = try ModelContainerFactory.makeInMemory()
        let attachments = AttachmentStore(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("EvidenceDesk-Test-\(UUID().uuidString)", isDirectory: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return PersistenceService(modelContext: context, attachments: attachments)
    }

    /// Persist pending changes; raises `.saveFailed` instead of silently
    /// deceiving the caller.
    func save() throws {
        do {
            try modelContext.save()
        } catch {
            Logger.ops.error("save failed: \(error.localizedDescription, privacy: .public)")
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    private func touch(_ researchCase: ResearchCase) {
        researchCase.updatedAt = Date()
    }

    // MARK: - Cases

    @discardableResult
    func createCase(title: String, researchQuestion: String = "", researchScope: String = "") throws -> ResearchCase {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("A title is required.")
        }
        let descriptor = FetchDescriptor<ResearchCase>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let code = ShortCodeFormatter.nextCode(prefix: "C", existing: existing) { $0.shortCode }
        let newCase = ResearchCase(shortCode: code, title: trimmed, researchQuestion: researchQuestion, researchScope: researchScope)
        modelContext.insert(newCase)
        try save()
        return newCase
    }

    func updateCase(_ researchCase: ResearchCase, title: String, question: String, scope: String) throws {
        researchCase.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        researchCase.researchQuestion = question
        researchCase.researchScope = scope
        touch(researchCase)
        try save()
    }

    func setArchived(_ researchCase: ResearchCase, archived: Bool) throws {
        researchCase.isArchived = archived
        touch(researchCase)
        try save()
    }

    /// Deletes a case and its owned data. Confirmation is the UI layer's job;
            /// this service verifies the object still exists first.
    func deleteCase(_ researchCase: ResearchCase) throws {
        // Remove attachments owned by sources of this case before removal.
        for source in researchCase.sources {
            try? attachments.removeAttachmentDirectory(for: source)
        }
        modelContext.delete(researchCase)
        try save()
    }

    // MARK: - Sources

    @discardableResult
    func createURLSource(in researchCase: ResearchCase, url: URL, title: String, publisher: String = "", notes: String = "") throws -> Source {
        let code = ShortCodeFormatter.nextCode(prefix: "S", existing: researchCase.sources) { $0.shortCode }
        let source = Source(
            shortCode: code,
            sourceType: .url,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            urlString: url.absoluteString,
            publisher: publisher,
            userNotes: notes
        )
        source.case = researchCase
        modelContext.insert(source)
        touch(researchCase)
        try save()
        return source
    }

    /// Imports a file attachment: stage -> verify -> finalise -> insert record -> save.
    /// On save failure the staged attachment is rolled back.
    @discardableResult
    func importFileSource(in researchCase: ResearchCase, sourceURL: URL, sourceType: SourceType, title: String, userNotes: String = "") throws -> Source {
        let code = ShortCodeFormatter.nextCode(prefix: "S", existing: researchCase.sources) { $0.shortCode }
        let sourceID = UUID()
        let staged = try attachments.stageImport(from: sourceURL, sourceID: sourceID)

        let source = Source(
            id: sourceID,
            shortCode: code,
            sourceType: sourceType,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            userNotes: userNotes,
            originalFilename: sourceURL.lastPathComponent,
            attachmentFileSize: try? fileSize(of: sourceURL)
        )
        source.case = researchCase
        modelContext.insert(source)

        do {
            let relativePath = try attachments.finaliseImport(stagedFile: staged, source: source)
            source.attachmentRelativePath = relativePath
            touch(researchCase)
            try save()
            return source
        } catch {
            attachments.cancelImport(stagedFile: staged)
            modelContext.delete(source)
            try? save()
            throw error
        }
    }

    /// Handles a file whose attachment has gone missing: the user can either
    /// re-point the source at another file or delete the metadata.
    func updateSourceMetadata(_ source: Source, title: String, publisher: String, notes: String, publishedDate: Date?) throws {
        source.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        source.publisher = publisher
        source.userNotes = notes
        source.publishedDate = publishedDate
        if let researchCase = source.case { touch(researchCase) }
        try save()
    }

    func relocateAttachment(for source: Source, newFileURL: URL) throws {
        guard source.sourceType != .url else { return }
        let staged = try attachments.stageImport(from: newFileURL, sourceID: source.id)
        // Remove previous attachment directory, then finalise the new file.
        try? attachments.removeAttachmentDirectory(for: source)
        let relativePath = try attachments.finaliseImport(stagedFile: staged, source: source)
        source.attachmentRelativePath = relativePath
        source.attachmentIsMissing = false
        source.originalFilename = newFileURL.lastPathComponent
        if let size = try? fileSize(of: newFileURL) { source.attachmentFileSize = size }
        if let researchCase = source.case { touch(researchCase) }
        try save()
    }

    /// Deletes a source. If it still has evidence, callers must consult
    /// `DeletionGuard.impact(of:)` and decide via the UI. Keep mode detaches
    /// evidence (they become source-less notes); delete mode removes them too.
    func deleteSource(_ source: Source, keepEvidence: Bool) throws {
        let evidenceToRemove = keepEvidence ? [] : source.evidences
        for evidence in evidenceToRemove {
            if source.case != nil { modelContext.delete(evidence) }
        }
        if !keepEvidence {
            for evidence in source.evidences {
                // detach so no dangling source refs survive deletion of the record
                evidence.source = nil
            }
        } else {
            for evidence in source.evidences {
                evidence.source = nil
            }
        }
        try? attachments.removeAttachmentDirectory(for: source)
        if let researchCase = source.case { touch(researchCase) }
        modelContext.delete(source)
        try save()
    }

    // MARK: - Evidence

    @discardableResult
    func createEvidence(in researchCase: ResearchCase, text: String, type: EvidenceType, source: Source?, locationNote: String, pageNumber: Int?, userNotes: String, caseIsRequired: Bool = true) throws -> Evidence {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("Evidence text cannot be empty.")
        }
        guard trimmed.count <= 50_000 else {
            throw PersistenceError.saveFailed("Evidence text is too long.")
        }
        if caseIsRequired && source == nil {
            throw PersistenceError.saveFailed("Evidence must be linked to a source, or explicitly marked as a personal note.")
        }
        let code = ShortCodeFormatter.nextCode(prefix: "E", existing: researchCase.evidences) { $0.shortCode }
        let evidence = Evidence(
            shortCode: code,
            text: trimmed,
            evidenceType: type,
            source: source,
            locationNote: locationNote,
            pageNumber: pageNumber,
            userNotes: userNotes
        )
        evidence.case = researchCase
        modelContext.insert(evidence)
        touch(researchCase)
        try save()
        return evidence
    }

    func updateEvidence(_ evidence: Evidence, text: String, type: EvidenceType, source: Source?, locationNote: String, pageNumber: Int?, userNotes: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("Evidence text cannot be empty.")
        }
        guard trimmed.count <= 50_000 else {
            throw PersistenceError.saveFailed("Evidence text is too long.")
        }
        evidence.text = trimmed
        evidence.evidenceType = type
        evidence.source = source
        evidence.locationNote = locationNote
        evidence.pageNumber = pageNumber
        evidence.userNotes = userNotes
        evidence.updatedAt = Date()
        if let researchCase = evidence.case { touch(researchCase) }
        try save()
    }

    func deleteEvidence(_ evidence: Evidence) throws {
        if let researchCase = evidence.case { touch(researchCase) }
        modelContext.delete(evidence)
        try save()
    }

    // MARK: - Findings

    @discardableResult
    func createFinding(in researchCase: ResearchCase, title: String, body: String, status: FindingStatus, uncertainty: String) throws -> Finding {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("A finding title is required.")
        }
        let code = ShortCodeFormatter.nextCode(prefix: "F", existing: researchCase.findings) { $0.shortCode }
        let finding = Finding(shortCode: code, title: trimmed, body: body, status: status, uncertainty: uncertainty)
        finding.case = researchCase
        modelContext.insert(finding)
        touch(researchCase)
        try save()
        return finding
    }

    func updateFinding(_ finding: Finding, title: String, body: String, status: FindingStatus, uncertainty: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("A finding title is required.")
        }
        finding.title = trimmed
        finding.body = body
        finding.status = status
        finding.uncertainty = uncertainty
        finding.updatedAt = Date()
        if let researchCase = finding.case { touch(researchCase) }
        try save()
    }

    func linkEvidence(_ evidence: Evidence, to finding: Finding, relation: RelationType) throws {
        // Prevent implicit duplicates.
        if finding.links.contains(where: { $0.evidence?.id == evidence.id }) {
            return
        }
        let link = FindingEvidenceLink(relationType: relation, finding: finding, evidence: evidence)
        modelContext.insert(link)
        finding.updatedAt = Date()
        if let researchCase = finding.case { touch(researchCase) }
        try save()
    }

    func changeLinkRelation(_ link: FindingEvidenceLink, relation: RelationType) throws {
        link.relationType = relation
        link.finding?.updatedAt = Date()
        if let researchCase = link.finding?.case { touch(researchCase) }
        try save()
    }

    func unlinkEvidence(_ link: FindingEvidenceLink) throws {
        if let researchCase = link.finding?.case { touch(researchCase) }
        modelContext.delete(link)
        try save()
    }

    func deleteFinding(_ finding: Finding) throws {
        if let researchCase = finding.case { touch(researchCase) }
        modelContext.delete(finding)
        try save()
    }

    // MARK: - Timeline

    @discardableResult
    func createTimelineEvent(in researchCase: ResearchCase, title: String, detail: String, date: Date?, precision: DatePrecision, source: Source?, notes: String) throws -> TimelineEvent {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("An event title is required.")
        }
        let event = TimelineEvent(title: trimmed, detail: detail, date: date, datePrecision: precision, source: source, notes: notes)
        event.case = researchCase
        modelContext.insert(event)
        touch(researchCase)
        try save()
        return event
    }

    func updateTimelineEvent(_ event: TimelineEvent, title: String, detail: String, date: Date?, precision: DatePrecision, source: Source?, notes: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersistenceError.saveFailed("An event title is required.")
        }
        event.title = trimmed
        event.detail = detail
        event.date = date
        event.datePrecision = precision
        event.source = source
        event.notes = notes
        if let researchCase = event.case { touch(researchCase) }
        try save()
    }

    func deleteTimelineEvent(_ event: TimelineEvent) throws {
        if let researchCase = event.case { touch(researchCase) }
        modelContext.delete(event)
        try save()
    }

    private func fileSize(of url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }
}