import Foundation
import Testing
@testable import EvidenceDesk

@MainActor
struct URLValidationTests {
    @Test func acceptsHTTPSAndHTTP() {
        #expect(URLValidation.validate("https://example.com/a?b=1") == .success(URL(string: "https://example.com/a?b=1")!))
        #expect(URLValidation.validate("http://example.com") == .success(URL(string: "http://example.com")!))
    }

    @Test func normalisesBareDomain() {
        guard case .success(let url) = URLValidation.validate("example.com/news") else {
            Issue.record("expected success")
            return
        }
        #expect(url.scheme == "http")
        #expect(url.host == "example.com")
    }

    @Test func rejectsUnsafeSchemes() {
        #expect(URLValidation.validate("file:///etc/passwd") == .failure(.invalidScheme("file")))
        #expect(URLValidation.validate("javascript:alert(1)") == .failure(.invalidScheme("javascript")))
        #expect(URLValidation.validate("data:text/plain;base64,SGk=") == .failure(.invalidScheme("data")))
    }

    @Test func rejectsEmptyAndMalformed() {
        #expect(URLValidation.validate("   ") == .failure(.empty))
        #expect(URLValidation.validate("not a url at all") == .failure(.malformed))
    }
}