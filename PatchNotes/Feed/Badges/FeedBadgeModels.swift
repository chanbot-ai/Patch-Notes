import Foundation

struct FeedBadgeKey: RawRepresentable, Codable, Hashable, Equatable {
    let rawValue: String

    init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = FeedBadgeKey.normalizedRawValue(trimmed)
    }

    init(category: FeedBadgeCategory) {
        rawValue = category.rawValue
    }

    init(gameID: String) {
        let cleaned = gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        rawValue = cleaned.isEmpty ? FeedBadgeCategory.unspecified.rawValue : "game:\(cleaned)"
    }

    static func normalizedRawValue(_ candidate: String) -> String {
        guard !candidate.isEmpty else { return FeedBadgeCategory.unspecified.rawValue }
        if let category = FeedBadgeCategory(rawValue: candidate) {
            return category.rawValue
        }
        if candidate.hasPrefix("game:"),
           let gameID = candidate.split(separator: ":", maxSplits: 1).last,
           !gameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "game:\(gameID)"
        }
        return FeedBadgeCategory.unspecified.rawValue
    }

    var category: FeedBadgeCategory? {
        FeedBadgeCategory(rawValue: rawValue)
    }

    var gameID: String? {
        guard rawValue.hasPrefix("game:") else { return nil }
        let value = String(rawValue.dropFirst("game:".count))
        return value.isEmpty ? nil : value
    }

    var isGame: Bool { gameID != nil }

    var isFallback: Bool {
        category == .generalGaming || category == .unspecified
    }
}

enum FeedBadgeCategory: String, Codable, CaseIterable, Hashable {
    case multiGame = "multi_game"
    case esports
    case creator
    case industry
    case platform
    case event
    case generalGaming = "general_gaming"
    case unspecified
}

enum FeedBadgeVariant: String, Codable, CaseIterable, Hashable {
    case feedCompact
    case feedFull
    case filterChip
    case detailBadge
    case iconOnly
}

enum FeedBadgeConfidenceTier: String, Codable {
    case high
    case medium
    case low
    case none
}

enum FeedBadgeAssignmentSource: String, Codable {
    case user
    case composerContext = "composer_context"
    case attachment
    case textRules = "text_rules"
    case linkMetadata = "link_metadata"
    case asyncEnrichment = "async_enrichment"
}

enum FeedBadgeAssignmentStatus: String, Codable {
    case assigned
    case userOverridden = "user_overridden"
    case pendingEnrichment = "pending_enrichment"
    case superseded
    case rejected
}

struct FeedBadgeDetectedEntity: Codable, Hashable, Equatable {
    enum Kind: String, Codable {
        case game
        case esports
        case creator
        case industry
        case platform
        case event
        case generalGaming = "general_gaming"
    }

    let kind: Kind
    let key: String
    let displayName: String
    let score: Double
}

struct FeedBadgeAssignment: Codable, Hashable, Equatable {
    let postID: UUID
    let primaryBadgeKey: FeedBadgeKey
    let secondaryBadgeKey: FeedBadgeKey?
    let confidence: FeedBadgeConfidenceTier
    let confidenceScore: Double?
    let source: FeedBadgeAssignmentSource
    let status: FeedBadgeAssignmentStatus
    let detectedEntities: [FeedBadgeDetectedEntity]
    let assignedAt: Date

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case primaryBadgeKey = "primary_badge_key"
        case secondaryBadgeKey = "secondary_badge_key"
        case confidence = "confidence_tier"
        case confidenceScore = "confidence_score"
        case source
        case status
        case detectedEntities = "detected_entities"
        case assignedAt = "assigned_at"
    }
}

struct FeedBadgeVariantContent: Codable, Hashable, Equatable {
    let label: String
    let accessibilityLabel: String
    let symbolName: String
    let tooltip: String?
}

struct FeedBadgeContentSpec: Codable, Hashable, Equatable {
    let badgeKey: FeedBadgeKey
    let variants: [FeedBadgeVariant: FeedBadgeVariantContent]
    let colorToken: String
    let shapeToken: String
    let frameToken: String
}

enum FeedBadgeContentRegistry {
    static func contentSpec(for key: FeedBadgeKey, gameTitle: String? = nil, gameCompactAlias: String? = nil) -> FeedBadgeContentSpec {
        if let gameID = key.gameID {
            let detailName = (gameTitle?.isEmpty == false ? gameTitle! : gameID.replacingOccurrences(of: "-", with: " ").capitalized)
            let compact = gameCompactAlias ?? String(detailName.prefix(8)).uppercased()
            return FeedBadgeContentSpec(
                badgeKey: key,
                variants: [
                    .feedCompact: .init(label: compact, accessibilityLabel: detailName, symbolName: "gamecontroller.fill", tooltip: detailName),
                    .feedFull: .init(label: detailName, accessibilityLabel: detailName, symbolName: "gamecontroller.fill", tooltip: detailName),
                    .filterChip: .init(label: detailName, accessibilityLabel: detailName, symbolName: "gamecontroller.fill", tooltip: detailName),
                    .detailBadge: .init(label: detailName, accessibilityLabel: detailName, symbolName: "gamecontroller.fill", tooltip: detailName),
                    .iconOnly: .init(label: "", accessibilityLabel: detailName, symbolName: "gamecontroller.fill", tooltip: detailName)
                ],
                colorToken: "game",
                shapeToken: "pill-rich",
                frameToken: "badge-frame-game"
            )
        }

        let category = key.category ?? .unspecified
        let labelSet = FeedBadgeLabels.labels(for: category)
        let symbol = FeedBadgeLabels.symbolName(for: category)
        return FeedBadgeContentSpec(
            badgeKey: FeedBadgeKey(category: category),
            variants: [
                .feedCompact: .init(label: labelSet.compact, accessibilityLabel: labelSet.detail, symbolName: symbol, tooltip: labelSet.full),
                .feedFull: .init(label: labelSet.full, accessibilityLabel: labelSet.detail, symbolName: symbol, tooltip: labelSet.detail),
                .filterChip: .init(label: labelSet.detail, accessibilityLabel: labelSet.detail, symbolName: symbol, tooltip: labelSet.detail),
                .detailBadge: .init(label: labelSet.detail, accessibilityLabel: labelSet.detail, symbolName: symbol, tooltip: labelSet.detail),
                .iconOnly: .init(label: "", accessibilityLabel: labelSet.detail, symbolName: symbol, tooltip: labelSet.detail)
            ],
            colorToken: FeedBadgeLabels.colorToken(for: category),
            shapeToken: FeedBadgeLabels.shapeToken(for: category),
            frameToken: "badge-frame-shared"
        )
    }
}

enum FeedBadgeLabels {
    struct LabelSet {
        let compact: String
        let full: String
        let detail: String
    }

    static func labels(for category: FeedBadgeCategory) -> LabelSet {
        switch category {
        case .multiGame:
            return .init(compact: "MULTI", full: "Multi-Game", detail: "Multi-Game")
        case .esports:
            return .init(compact: "ESP", full: "Esports", detail: "Esports")
        case .creator:
            return .init(compact: "CRT", full: "Creator", detail: "Creator")
        case .industry:
            return .init(compact: "IND", full: "Industry", detail: "Industry")
        case .platform:
            return .init(compact: "PLT", full: "Platform", detail: "Platform")
        case .event:
            return .init(compact: "EVT", full: "Event", detail: "Event")
        case .generalGaming:
            return .init(compact: "GEN", full: "Gaming", detail: "General Gaming")
        case .unspecified:
            // UI groups unspecified under the General Gaming badge presentation.
            return .init(compact: "GEN", full: "Gaming", detail: "General Gaming")
        }
    }

    static func symbolName(for category: FeedBadgeCategory) -> String {
        switch category {
        case .multiGame:
            return "square.split.2x1.fill"
        case .esports:
            return "trophy.fill"
        case .creator:
            return "dot.radiowaves.left.and.right"
        case .industry:
            return "building.2.fill"
        case .platform:
            return "cpu.fill"
        case .event:
            return "ticket.fill"
        case .generalGaming:
            return "gamecontroller"
        case .unspecified:
            return "gamecontroller"
        }
    }

    static func colorToken(for category: FeedBadgeCategory) -> String {
        switch category {
        case .multiGame: return "amber"
        case .esports: return "red"
        case .creator: return "magenta"
        case .industry: return "slate"
        case .platform: return "cyan"
        case .event: return "orange"
        case .generalGaming: return "blue"
        case .unspecified: return "blue"
        }
    }

    static func shapeToken(for category: FeedBadgeCategory) -> String {
        switch category {
        case .multiGame: return "split-pill"
        case .esports: return "angled-pill"
        case .creator: return "broadcast-pill"
        case .industry: return "rect-pill"
        case .platform: return "chip-pill"
        case .event: return "ticket-pill"
        case .generalGaming: return "soft-pill"
        case .unspecified: return "soft-pill"
        }
    }
}
