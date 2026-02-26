import XCTest
@testable import PatchNotes

final class FeedBadgeSystemTests: XCTestCase {
    func testParsesCategoryKey() {
        let key = FeedBadgeKey(rawValue: "esports")
        XCTAssertEqual(key.category, .esports)
        XCTAssertNil(key.gameID)
    }

    func testParsesGameKey() {
        let key = FeedBadgeKey(rawValue: "game:elden-ring")
        XCTAssertEqual(key.gameID, "elden-ring")
        XCTAssertTrue(key.isGame)
    }

    func testInvalidKeyFallsBackToUnspecified() {
        let key = FeedBadgeKey(rawValue: "totally-invalid")
        XCTAssertEqual(key.category, .unspecified)
        XCTAssertEqual(key.rawValue, "unspecified")
    }

    func testLabelLookupMatchesApprovedCompactLabels() {
        XCTAssertEqual(FeedBadgeLabels.labels(for: .generalGaming).compact, "GEN")
        XCTAssertEqual(FeedBadgeLabels.labels(for: .multiGame).compact, "MULTI")
        XCTAssertEqual(FeedBadgeLabels.labels(for: .unspecified).compact, "GEN")
    }

    func testContentRegistryReturnsIconOnlyAccessibilityLabel() {
        let spec = FeedBadgeContentRegistry.contentSpec(for: FeedBadgeKey(category: .platform))
        XCTAssertEqual(spec.variants[.iconOnly]?.accessibilityLabel, "Platform")
        XCTAssertEqual(spec.variants[.feedCompact]?.label, "PLT")
    }

    func testCodableRoundTripForAssignment() throws {
        let assignment = FeedBadgeAssignment(
            postID: UUID(),
            primaryBadgeKey: FeedBadgeKey(rawValue: "game:elden-ring"),
            secondaryBadgeKey: FeedBadgeKey(category: .event),
            confidence: .high,
            confidenceScore: 0.93,
            source: .textRules,
            status: .assigned,
            detectedEntities: [.init(kind: .game, key: "game:elden-ring", displayName: "Elden Ring", score: 0.93)],
            assignedAt: Date(timeIntervalSince1970: 0)
        )

        let encoded = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(FeedBadgeAssignment.self, from: encoded)
        XCTAssertEqual(decoded.primaryBadgeKey.rawValue, "game:elden-ring")
        XCTAssertEqual(decoded.secondaryBadgeKey?.rawValue, "event")
        XCTAssertEqual(decoded.confidence, .high)
    }
}
