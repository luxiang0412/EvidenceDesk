import Foundation
import Testing
@testable import EvidenceDesk

@MainActor
struct ShortCodeTests {
    @Test func formattingPadsToThreeDigits() {
        #expect(ShortCodeFormatter.code(prefix: "S", index: 0) == "S-001")
        #expect(ShortCodeFormatter.code(prefix: "E", index: 9) == "E-010")
        #expect(ShortCodeFormatter.code(prefix: "F", index: 999) == "F-1000")
    }

    @Test func nextCodeSkipsExistingAndIgnoresForeign() {
        let existing = ["S-001", "S-003", "A-099", "garbage", "S-011"]
        #expect(ShortCodeFormatter.nextCode(prefix: "S", existing: existing) { $0 } == "S-012")
    }

    @Test func codesAreStableAcrossOrders() {
        // Re-ordering the same set yields the same max->next regardless.
        let a = ["S-001", "S-002"]
        let b = ["S-002", "S-001"]
        #expect(ShortCodeFormatter.nextCode(prefix: "S", existing: a) { $0 }
                == ShortCodeFormatter.nextCode(prefix: "S", existing: b) { $0 })
    }
}