import Foundation
import SwiftData

@Model
final class Finding {
    var id: UUID
    /// Human readable short number unique within the case: `F-001`.
    var shortCode: String
    var title: String
    var body: String
    var statusRaw: String
    /// Optional note on uncertainty, alternative explanations, open questions.
    var uncertainty: String
    var createdAt: Date
    var updatedAt: Date
    var `case`: ResearchCase?

    @Relationship(deleteRule: .cascade, inverse: \FindingEvidenceLink.finding)
    var links: [FindingEvidenceLink] = []

    var status: FindingStatus {
        get { FindingStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        shortCode: String,
        title: String,
        body: String = "",
        status: FindingStatus = .draft,
        uncertainty: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.shortCode = shortCode
        self.title = title
        self.body = body
        self.statusRaw = status.rawValue
        self.uncertainty = uncertainty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}