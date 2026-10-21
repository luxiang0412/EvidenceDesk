import Foundation
import Testing
@testable import EvidenceDesk

@MainActor
struct SmokeTests {
    @Test func urlValidationAcceptsHTTPS() {
        let result = URLValidation.validate("https://example.com/news/1")
        guard case .success(let url) = result else {
            Issue.record("expected success")
            return
        }
        #expect(url.scheme == "https")
        #expect(url.host == "example.com")
    }

    @Test func urlValidationRejectsFileScheme() {
        let result = URLValidation.validate("file:///tmp/something")
        guard case .failure(.invalidScheme(let scheme)) = result else {
            Issue.record("expected invalidScheme")
            return
        }
        #expect(scheme == "file")
    }

    @Test func shortCodeFormatting() {
        #expect(ShortCodeFormatter.code(prefix: "S", index: 0) == "S-001")
        #expect(ShortCodeFormatter.code(prefix: "E", index: 41) == "E-042")
        #expect(ShortCodeFormatter.nextCode(prefix: "S", existing: ["S-001", "S-003", "x"]) { $0 } == "S-004")
    }
}