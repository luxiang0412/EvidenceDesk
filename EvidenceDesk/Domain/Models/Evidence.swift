import Foundation
import SwiftData

@Model
final class Evidence {
    var id: UUID
    /// Human readable short number unique within the case: `E-001`.
    var shortCode: String
    /// The excerpt or recorded text.
    var text: String
    var evidenceTypeRaw: String
    /// Main source this evidence is drawn from. `nil` means "personal note / unverified".
    var source: Source?
    /// Human readable location, e.g. "p. 3" or a custom citation.
    var locationNote: String
    /// Page number when known (PDF selection). Not display-only; kept for navigation.
    var pageNumber: Int?
    var userNotes: String
    var createdAt: Date
    var updatedAt: Date
    var `case`: ResearchCase?

    @Relationship(deleteRule: .cascade, inverse: \FindingEvidenceLink.evidence)
    var findingLinks: [FindingEvidenceLink] = []

    var evidenceType: EvidenceType {
        get { EvidenceType(rawValue: evidenceTypeRaw) ?? .fact }
        set { evidenceTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        shortCode: String,
        text: String,
        evidenceType: EvidenceType = .fact,
        source: Source? = nil,
        locationNote: String = "",
        pageNumber: Int? = nil,
        userNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.shortCode = shortCode
        self.text = text
        self.evidenceTypeRaw = evidenceType.rawValue
        self.source = source
        self.locationNote = locationNote
        self.pageNumber = pageNumber
        self.userNotes = userNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}