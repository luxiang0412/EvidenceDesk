import Foundation
import SwiftData

@Model
final class Source {
    /// Stable identifier. Attachments are stored under this UUID.
    var id: UUID
    /// Human readable short number unique within the case: `S-001`.
    var shortCode: String
    var sourceTypeRaw: String
    var title: String

    /// Only meaningful for `.url` sources. Kept on the model for validation.
    var urlString: String?

    /// Publisher / site name for web sources; optional.
    var publisher: String
    /// Optional published date.
    var publishedDate: Date?
    var addedAt: Date
    var userNotes: String

    /// Original filename at import time (metadata only).
    var originalFilename: String
    /// Path relative to the case attachments root, e.g. `<source-uuid>/original.pdf`.
    var attachmentRelativePath: String?
    /// Size in bytes of the copied attachment, if any.
    var attachmentFileSize: Int64?

    /// Set by `RecoveryService` when the attachment file is missing.
    var attachmentIsMissing: Bool

    var `case`: ResearchCase?

    @Relationship(inverse: \Evidence.source)
    var evidences: [Evidence] = []

    @Relationship(inverse: \TimelineEvent.source)
    var timelineEvents: [TimelineEvent] = []

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .url }
        set { sourceTypeRaw = newValue.rawValue }
    }

    /// `true` when this source is a web link only, not an archived snapshot.
    var isLinkOnly: Bool { sourceType == .url }

    init(
        id: UUID = UUID(),
        shortCode: String,
        sourceType: SourceType,
        title: String,
        urlString: String? = nil,
        publisher: String = "",
        publishedDate: Date? = nil,
        addedAt: Date = Date(),
        userNotes: String = "",
        originalFilename: String = "",
        attachmentRelativePath: String? = nil,
        attachmentFileSize: Int64? = nil
    ) {
        self.id = id
        self.shortCode = shortCode
        self.sourceTypeRaw = sourceType.rawValue
        self.title = title
        self.urlString = urlString
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.addedAt = addedAt
        self.userNotes = userNotes
        self.originalFilename = originalFilename
        self.attachmentRelativePath = attachmentRelativePath
        self.attachmentFileSize = attachmentFileSize
        self.attachmentIsMissing = false
    }
}