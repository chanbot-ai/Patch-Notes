import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        spec.variants[variant] ?? spec.variants[.feedCompact] ?? .init(label: "GEN", accessibilityLabel: "General Gaming", symbolName: "gamecontroller", tooltip: "General Gaming")
    }

    private var palette: FeedBadgePalette {
        FeedBadgeStyleTokens.palette(for: spec)
    }

    var body: some View {
        ZStack {
            backgroundShape
                .fill(fillGradient)

            // Top gloss to make badges feel less flat while we use placeholder icons.
            backgroundShape
                .fill(
                    LinearGradient(
                        colors: [palette.gloss, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            backgroundShape
                .stroke(palette.innerStroke, lineWidth: 1)
                .padding(1)

            if variant != .iconOnly {
                accentStripe
            }

            HStack(spacing: variant == .iconOnly ? 0 : 6) {
                iconChip
                    .frame(width: iconFrameWidth, height: FeedBadgeStyleTokens.height(for: variant))

                if variant != .iconOnly {
                    Text(content.label)
                        .font(textFont)
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.trailing, 9)
                }
            }
            .padding(.leading, variant == .iconOnly ? 0 : 4)
        }
        .frame(height: FeedBadgeStyleTokens.height(for: variant))
        .overlay(backgroundShape.stroke(palette.stroke.opacity(0.92), lineWidth: 1))
        .shadow(color: palette.shadow, radius: FeedBadgeStyleTokens.shadowRadius(for: variant), x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityHint(Text(content.tooltip ?? content.accessibilityLabel))
        .frame(minWidth: variant == .iconOnly ? FeedBadgeStyleTokens.height(for: variant) : nil)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [palette.fillTop, palette.fillMid, palette.fillBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FeedBadgeStyleTokens.cornerRadius(for: variant, shapeToken: spec.shapeToken), style: .continuous)
    }

    private var accentStripe: some View {
        VStack {
            Spacer()
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.95), palette.accent.opacity(0.22)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: accentStripeWidth, height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .padding(.bottom, 2)
        }
    }

    private var iconChip: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: FeedBadgeStyleTokens.iconChipCornerRadius(for: spec, variant: variant),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [palette.iconFillTop, palette.iconFillBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            RoundedRectangle(
                cornerRadius: FeedBadgeStyleTokens.iconChipCornerRadius(for: spec, variant: variant),
                style: .continuous
            )
            .stroke(palette.iconStroke.opacity(0.95), lineWidth: 1)

            RoundedRectangle(
                cornerRadius: FeedBadgeStyleTokens.iconChipCornerRadius(for: spec, variant: variant),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.16), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )

            Image(systemName: content.symbolName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(palette.icon)
                .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
        }
        .frame(width: iconChipWidth, height: iconChipHeight)
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

    private var iconChipWidth: CGFloat {
        switch variant {
        case .iconOnly:
            return FeedBadgeStyleTokens.height(for: variant) - 4
        case .feedCompact:
            return 16
        case .feedFull, .filterChip, .detailBadge:
            return 17
        }
    }

    private var iconChipHeight: CGFloat {
        switch variant {
        case .feedCompact:
            return 16
        case .feedFull, .filterChip, .detailBadge:
            return 17
        case .iconOnly:
            return FeedBadgeStyleTokens.height(for: variant) - 4
        }
    }

    private var accentStripeWidth: CGFloat {
        switch variant {
        case .feedCompact:
            return 24
        case .feedFull, .filterChip, .detailBadge:
            return 30
        case .iconOnly:
            return 0
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
        .init(title: "Unspecified -> GEN fallback", key: FeedBadgeKey(rawValue: "not-a-valid-key"), gameTitle: nil, alias: nil)
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

struct FeedPostCornerBadgeView: View {
    let key: FeedBadgeKey
    let gameTitle: String?
    let gameCompactAlias: String?

    // Roughly two emoji widths in-feed, per design request.
    private let frameSize = CGSize(width: 52, height: 62)

    var body: some View {
        if let assetName = FeedBadgeArtworkAssets.assetName(for: key), FeedBadgeArtworkAssets.hasImage(named: assetName) {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: frameSize.width, height: frameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilityLabel))
        } else {
            FeedBadgeView(
                key: key,
                variant: .feedCompact,
                gameTitle: gameTitle,
                gameCompactAlias: gameCompactAlias
            )
            .scaleEffect(1.15)
            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
        }
    }

    private var accessibilityLabel: String {
        FeedBadgeContentRegistry
            .contentSpec(for: key, gameTitle: gameTitle, gameCompactAlias: gameCompactAlias)
            .variants[.detailBadge]?
            .accessibilityLabel ?? "Post topic"
    }
}

enum FeedBadgeArtworkAssets {
    static func assetName(for key: FeedBadgeKey) -> String? {
        if key.isGame {
            return "FeedBadgeGameArt"
        }

        switch key.category ?? .unspecified {
        case .multiGame:
            return "FeedBadgeMultiGameArt"
        case .esports:
            return "FeedBadgeEsportsArt"
        case .creator:
            return "FeedBadgeCreatorArt"
        case .industry:
            return "FeedBadgeIndustryArt"
        case .platform:
            return "FeedBadgePlatformArt"
        case .event:
            return "FeedBadgeEventArt"
        case .generalGaming, .unspecified:
            return "FeedBadgeGeneralGamingArt"
        }
    }

    static func hasImage(named assetName: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: assetName) != nil
        #else
        return false
        #endif
    }
}
