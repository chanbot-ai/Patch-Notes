import SwiftUI

struct FeedBadgeView: View {
    let key: FeedBadgeKey
    let variant: FeedBadgeVariant
    let gameTitle: String?
    let gameCompactAlias: String?

    init(
        key: FeedBadgeKey,
        variant: FeedBadgeVariant,
        gameTitle: String? = nil,
        gameCompactAlias: String? = nil
    ) {
        self.key = key
        self.variant = variant
        self.gameTitle = gameTitle
        self.gameCompactAlias = gameCompactAlias
    }

    private var spec: FeedBadgeContentSpec {
        FeedBadgeContentRegistry.contentSpec(for: key, gameTitle: gameTitle, gameCompactAlias: gameCompactAlias)
    }

    private var content: FeedBadgeVariantContent {
        spec.variants[variant] ?? spec.variants[.feedCompact] ?? .init(label: "UNSP", accessibilityLabel: "Unspecified", symbolName: "questionmark.circle.fill", tooltip: "Unspecified")
    }

    private var palette: FeedBadgePalette {
        FeedBadgeStyleTokens.palette(for: spec)
    }

    var body: some View {
        HStack(spacing: variant == .iconOnly ? 0 : 6) {
            Image(systemName: content.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(palette.icon)
                .frame(width: iconFrameWidth, height: FeedBadgeStyleTokens.height(for: variant))

            if variant != .iconOnly {
                Text(content.label)
                    .font(textFont)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, 8)
            }
        }
        .padding(.leading, variant == .iconOnly ? 0 : 4)
        .frame(height: FeedBadgeStyleTokens.height(for: variant))
        .background(backgroundShape.fill(fillGradient))
        .overlay(backgroundShape.stroke(palette.stroke.opacity(0.9), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityHint(Text(content.tooltip ?? content.accessibilityLabel))
        .frame(minWidth: variant == .iconOnly ? FeedBadgeStyleTokens.height(for: variant) : nil)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [palette.fillTop, palette.fillBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FeedBadgeStyleTokens.cornerRadius(for: variant), style: .continuous)
    }

    private var iconSize: CGFloat {
        switch variant {
        case .feedCompact: return 11
        case .feedFull, .filterChip, .detailBadge: return 12
        case .iconOnly: return 13
        }
    }

    private var iconFrameWidth: CGFloat {
        switch variant {
        case .iconOnly:
            return FeedBadgeStyleTokens.height(for: variant)
        case .feedCompact, .feedFull, .filterChip, .detailBadge:
            return 18
        }
    }

    private var textFont: Font {
        switch variant {
        case .feedCompact:
            return .system(size: 10, weight: .bold, design: .rounded)
        case .feedFull:
            return .system(size: 11, weight: .semibold, design: .rounded)
        case .filterChip, .detailBadge:
            return .system(size: 11, weight: .medium, design: .rounded)
        case .iconOnly:
            return .system(size: 11, weight: .medium, design: .rounded)
        }
    }
}

private struct FeedBadgeDemoItem: Identifiable {
    let id = UUID()
    let title: String
    let key: FeedBadgeKey
    let gameTitle: String?
    let alias: String?
}

struct FeedBadgeDemoGallery: View {
    private let items: [FeedBadgeDemoItem] = [
        .init(title: "Single game", key: FeedBadgeKey(rawValue: "game:elden-ring"), gameTitle: "Elden Ring", alias: "ER"),
        .init(title: "Multi", key: FeedBadgeKey(category: .multiGame), gameTitle: nil, alias: nil),
        .init(title: "Esports", key: FeedBadgeKey(category: .esports), gameTitle: nil, alias: nil),
        .init(title: "Creator", key: FeedBadgeKey(category: .creator), gameTitle: nil, alias: nil),
        .init(title: "Industry", key: FeedBadgeKey(category: .industry), gameTitle: nil, alias: nil),
        .init(title: "Platform", key: FeedBadgeKey(category: .platform), gameTitle: nil, alias: nil),
        .init(title: "Event", key: FeedBadgeKey(category: .event), gameTitle: nil, alias: nil),
        .init(title: "Gaming fallback", key: FeedBadgeKey(category: .generalGaming), gameTitle: nil, alias: nil),
        .init(title: "Unspecified fallback", key: FeedBadgeKey(rawValue: "not-a-valid-key"), gameTitle: nil, alias: nil)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            FeedBadgeView(key: item.key, variant: .feedCompact, gameTitle: item.gameTitle, gameCompactAlias: item.alias)
                            FeedBadgeView(key: item.key, variant: .feedFull, gameTitle: item.gameTitle, gameCompactAlias: item.alias)
                            FeedBadgeView(key: item.key, variant: .filterChip, gameTitle: item.gameTitle, gameCompactAlias: item.alias)
                            FeedBadgeView(key: item.key, variant: .detailBadge, gameTitle: item.gameTitle, gameCompactAlias: item.alias)
                            FeedBadgeView(key: item.key, variant: .iconOnly, gameTitle: item.gameTitle, gameCompactAlias: item.alias)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.9))
    }
}

struct FeedBadgeDemoGallery_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeedBadgeDemoGallery()
                .previewDisplayName("Feed Badge Gallery")
            FeedBadgeView(key: FeedBadgeKey(rawValue: "game:monster-hunter-wilds"), variant: .feedFull, gameTitle: "Monster Hunter Wilds", gameCompactAlias: "MHW")
                .padding()
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Game Badge")
        }
    }
}
