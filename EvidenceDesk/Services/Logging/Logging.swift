import Foundation
import os

/// Centralised `os.Logger` instances.
///
/// Privacy rules: log operation categories, stable identifiers and error codes
/// only. Never log research bodies, full excerpts, URLs or file paths.
enum Logger {
    static let ops = os.Logger(subsystem: "com.luxiang0412.EvidenceDesk", category: "operations")
    static let importLog = os.Logger(subsystem: "com.luxiang0412.EvidenceDesk", category: "import")
    static let recovery = os.Logger(subsystem: "com.luxiang0412.EvidenceDesk", category: "recovery")
    static let export = os.Logger(subsystem: "com.luxiang0412.EvidenceDesk", category: "export")
}