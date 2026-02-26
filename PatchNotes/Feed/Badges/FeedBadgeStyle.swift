import SwiftUI

struct FeedBadgePalette {
    let fillTop: Color
    let fillMid: Color
    let fillBottom: Color
    let gloss: Color
    let stroke: Color
    let innerStroke: Color
    let text: Color
    let icon: Color
    let iconFillTop: Color
    let iconFillBottom: Color
    let iconStroke: Color
    let accent: Color
    let shadow: Color
}

enum FeedBadgeStyleTokens {
    static func palette(for spec: FeedBadgeContentSpec) -> FeedBadgePalette {
        func make(
            fillTop: Color,
            fillMid: Color,
            fillBottom: Color,
            gloss: Color,
            stroke: Color,
            innerStroke: Color,
            text: Color = .white,
            icon: Color,
            iconFillTop: Color,
            iconFillBottom: Color,
            iconStroke: Color,
            accent: Color,
            shadow: Color
        ) -> FeedBadgePalette {
            .init(
                fillTop: fillTop,
                fillMid: fillMid,
                fillBottom: fillBottom,
                gloss: gloss,
                stroke: stroke,
                innerStroke: innerStroke,
                text: text,
                icon: icon,
                iconFillTop: iconFillTop,
                iconFillBottom: iconFillBottom,
                iconStroke: iconStroke,
                accent: accent,
                shadow: shadow
            )
        }

        switch spec.colorToken {
        case "amber":
            return make(
                fillTop: Color(red: 0.47, green: 0.29, blue: 0.08),
                fillMid: Color(red: 0.35, green: 0.20, blue: 0.05),
                fillBottom: Color(red: 0.21, green: 0.12, blue: 0.03),
                gloss: Color.white.opacity(0.22),
                stroke: Color(red: 0.99, green: 0.78, blue: 0.34),
                innerStroke: Color(red: 1.00, green: 0.93, blue: 0.62).opacity(0.28),
                icon: Color(red: 1.00, green: 0.93, blue: 0.66),
                iconFillTop: Color(red: 0.79, green: 0.49, blue: 0.13),
                iconFillBottom: Color(red: 0.52, green: 0.28, blue: 0.06),
                iconStroke: Color(red: 1.00, green: 0.82, blue: 0.42),
                accent: Color(red: 1.00, green: 0.77, blue: 0.28),
                shadow: Color(red: 0.84, green: 0.48, blue: 0.11).opacity(0.35)
            )
        case "red":
            return make(
                fillTop: Color(red: 0.52, green: 0.11, blue: 0.15),
                fillMid: Color(red: 0.36, green: 0.08, blue: 0.11),
                fillBottom: Color(red: 0.20, green: 0.05, blue: 0.08),
                gloss: Color.white.opacity(0.16),
                stroke: Color(red: 1.00, green: 0.45, blue: 0.45),
                innerStroke: Color(red: 1.00, green: 0.72, blue: 0.72).opacity(0.22),
                icon: Color(red: 1.00, green: 0.88, blue: 0.88),
                iconFillTop: Color(red: 0.80, green: 0.18, blue: 0.20),
                iconFillBottom: Color(red: 0.53, green: 0.09, blue: 0.14),
                iconStroke: Color(red: 1.00, green: 0.58, blue: 0.58),
                accent: Color(red: 1.00, green: 0.39, blue: 0.34),
                shadow: Color(red: 0.74, green: 0.12, blue: 0.18).opacity(0.35)
            )
        case "magenta":
            return make(
                fillTop: Color(red: 0.45, green: 0.12, blue: 0.39),
                fillMid: Color(red: 0.30, green: 0.08, blue: 0.28),
                fillBottom: Color(red: 0.19, green: 0.05, blue: 0.19),
                gloss: Color.white.opacity(0.18),
                stroke: Color(red: 0.97, green: 0.53, blue: 0.89),
                innerStroke: Color(red: 1.00, green: 0.85, blue: 0.98).opacity(0.22),
                icon: Color(red: 1.00, green: 0.90, blue: 0.98),
                iconFillTop: Color(red: 0.70, green: 0.21, blue: 0.63),
                iconFillBottom: Color(red: 0.46, green: 0.12, blue: 0.43),
                iconStroke: Color(red: 0.98, green: 0.63, blue: 0.93),
                accent: Color(red: 0.98, green: 0.53, blue: 0.89),
                shadow: Color(red: 0.62, green: 0.17, blue: 0.57).opacity(0.34)
            )
        case "slate":
            return make(
                fillTop: Color(red: 0.18, green: 0.23, blue: 0.34),
                fillMid: Color(red: 0.13, green: 0.16, blue: 0.25),
                fillBottom: Color(red: 0.08, green: 0.10, blue: 0.17),
                gloss: Color.white.opacity(0.15),
                stroke: Color(red: 0.61, green: 0.71, blue: 0.89),
                innerStroke: Color(red: 0.86, green: 0.91, blue: 1.00).opacity(0.18),
                icon: Color(red: 0.92, green: 0.95, blue: 1.00),
                iconFillTop: Color(red: 0.29, green: 0.36, blue: 0.51),
                iconFillBottom: Color(red: 0.20, green: 0.25, blue: 0.39),
                iconStroke: Color(red: 0.70, green: 0.80, blue: 0.96),
                accent: Color(red: 0.88, green: 0.73, blue: 0.43),
                shadow: Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.35)
            )
        case "cyan":
            return make(
                fillTop: Color(red: 0.08, green: 0.31, blue: 0.39),
                fillMid: Color(red: 0.06, green: 0.23, blue: 0.30),
                fillBottom: Color(red: 0.04, green: 0.14, blue: 0.19),
                gloss: Color.white.opacity(0.18),
                stroke: Color(red: 0.42, green: 0.94, blue: 1.00),
                innerStroke: Color(red: 0.82, green: 0.99, blue: 1.00).opacity(0.23),
                icon: Color(red: 0.90, green: 1.00, blue: 1.00),
                iconFillTop: Color(red: 0.13, green: 0.47, blue: 0.57),
                iconFillBottom: Color(red: 0.08, green: 0.30, blue: 0.38),
                iconStroke: Color(red: 0.52, green: 0.98, blue: 1.00),
                accent: Color(red: 0.41, green: 0.94, blue: 1.00),
                shadow: Color(red: 0.05, green: 0.40, blue: 0.46).opacity(0.32)
            )
        case "orange":
            return make(
                fillTop: Color(red: 0.49, green: 0.21, blue: 0.08),
                fillMid: Color(red: 0.34, green: 0.14, blue: 0.05),
                fillBottom: Color(red: 0.21, green: 0.09, blue: 0.03),
                gloss: Color.white.opacity(0.20),
                stroke: Color(red: 1.00, green: 0.61, blue: 0.30),
                innerStroke: Color(red: 1.00, green: 0.85, blue: 0.70).opacity(0.22),
                icon: Color(red: 1.00, green: 0.92, blue: 0.82),
                iconFillTop: Color(red: 0.80, green: 0.34, blue: 0.11),
                iconFillBottom: Color(red: 0.54, green: 0.21, blue: 0.07),
                iconStroke: Color(red: 1.00, green: 0.69, blue: 0.40),
                accent: Color(red: 1.00, green: 0.67, blue: 0.33),
                shadow: Color(red: 0.83, green: 0.34, blue: 0.08).opacity(0.34)
            )
        case "game":
            return make(
                fillTop: Color(red: 0.15, green: 0.24, blue: 0.58),
                fillMid: Color(red: 0.11, green: 0.17, blue: 0.42),
                fillBottom: Color(red: 0.07, green: 0.10, blue: 0.27),
                gloss: Color.white.opacity(0.22),
                stroke: Color(red: 0.49, green: 0.78, blue: 1.00),
                innerStroke: Color(red: 0.86, green: 0.95, blue: 1.00).opacity(0.24),
                icon: Color(red: 0.93, green: 0.98, blue: 1.00),
                iconFillTop: Color(red: 0.26, green: 0.40, blue: 0.86),
                iconFillBottom: Color(red: 0.17, green: 0.25, blue: 0.58),
                iconStroke: Color(red: 0.63, green: 0.85, blue: 1.00),
                accent: Color(red: 0.51, green: 0.90, blue: 1.00),
                shadow: Color(red: 0.13, green: 0.28, blue: 0.78).opacity(0.34)
            )
        case "blue":
            return make(
                fillTop: Color(red: 0.12, green: 0.26, blue: 0.44),
                fillMid: Color(red: 0.08, green: 0.20, blue: 0.33),
                fillBottom: Color(red: 0.05, green: 0.12, blue: 0.20),
                gloss: Color.white.opacity(0.18),
                stroke: Color(red: 0.40, green: 0.80, blue: 0.97),
                innerStroke: Color(red: 0.85, green: 0.97, blue: 1.00).opacity(0.20),
                icon: Color(red: 0.90, green: 0.98, blue: 1.00),
                iconFillTop: Color(red: 0.15, green: 0.43, blue: 0.61),
                iconFillBottom: Color(red: 0.10, green: 0.27, blue: 0.40),
                iconStroke: Color(red: 0.47, green: 0.90, blue: 1.00),
                accent: Color(red: 0.35, green: 0.91, blue: 0.87),
                shadow: Color(red: 0.05, green: 0.36, blue: 0.52).opacity(0.30)
            )
        default:
            return make(
                fillTop: Color(red: 0.22, green: 0.23, blue: 0.28),
                fillMid: Color(red: 0.17, green: 0.18, blue: 0.22),
                fillBottom: Color(red: 0.11, green: 0.12, blue: 0.16),
                gloss: Color.white.opacity(0.14),
                stroke: Color(red: 0.62, green: 0.64, blue: 0.71),
                innerStroke: Color.white.opacity(0.10),
                icon: Color(red: 0.92, green: 0.93, blue: 0.97),
                iconFillTop: Color(red: 0.30, green: 0.31, blue: 0.38),
                iconFillBottom: Color(red: 0.22, green: 0.23, blue: 0.28),
                iconStroke: Color(red: 0.70, green: 0.72, blue: 0.80),
                accent: Color(red: 0.68, green: 0.70, blue: 0.78),
                shadow: Color.black.opacity(0.28)
            )
        }
    }

    static func cornerRadius(for variant: FeedBadgeVariant, shapeToken: String? = nil) -> CGFloat {
        let base: CGFloat
        switch variant {
        case .filterChip:
            base = 12
        case .detailBadge:
            base = 10
        case .iconOnly:
            base = 8
        case .feedCompact, .feedFull:
            base = 9
        }

        guard let shapeToken else { return base }
        switch shapeToken {
        case "soft-pill", "broadcast-pill":
            return base + 2
        case "angled-pill", "rect-pill":
            return max(6, base - 2)
        case "ticket-pill", "split-pill", "chip-pill":
            return max(6, base - 1)
        case "pill-rich":
            return base + 1
        default:
            return base
        }
    }

    static func height(for variant: FeedBadgeVariant) -> CGFloat {
        switch variant {
        case .feedCompact:
            return 22
        case .feedFull, .filterChip, .detailBadge:
            return 24
        case .iconOnly:
            return 24
        }
    }

    static func iconChipCornerRadius(for spec: FeedBadgeContentSpec, variant: FeedBadgeVariant) -> CGFloat {
        let base: CGFloat
        switch variant {
        case .feedCompact:
            base = 5
        case .feedFull, .filterChip, .detailBadge:
            base = 6
        case .iconOnly:
            base = 7
        }
        switch spec.shapeToken {
        case "broadcast-pill", "soft-pill":
            return base + 2
        case "rect-pill":
            return max(3, base - 2)
        case "angled-pill", "ticket-pill", "split-pill":
            return max(4, base - 1)
        default:
            return base
        }
    }

    static func shadowRadius(for variant: FeedBadgeVariant) -> CGFloat {
        switch variant {
        case .feedCompact: return 6
        case .feedFull, .filterChip, .detailBadge: return 7
        case .iconOnly: return 5
        }
    }

    // TODO: Replace symbolic/SF Symbol placeholders with final category + game art assets.
}
