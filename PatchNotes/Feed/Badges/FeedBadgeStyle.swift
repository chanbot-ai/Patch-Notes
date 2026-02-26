import SwiftUI

struct FeedBadgePalette {
    let fillTop: Color
    let fillBottom: Color
    let stroke: Color
    let text: Color
    let icon: Color
}

enum FeedBadgeStyleTokens {
    static func palette(for spec: FeedBadgeContentSpec) -> FeedBadgePalette {
        switch spec.colorToken {
        case "amber":
            return .init(fillTop: Color(red: 0.42, green: 0.25, blue: 0.06), fillBottom: Color(red: 0.29, green: 0.17, blue: 0.04), stroke: Color(red: 0.96, green: 0.73, blue: 0.29), text: .white, icon: Color(red: 1.00, green: 0.86, blue: 0.52))
        case "red":
            return .init(fillTop: Color(red: 0.45, green: 0.10, blue: 0.14), fillBottom: Color(red: 0.27, green: 0.07, blue: 0.10), stroke: Color(red: 0.98, green: 0.43, blue: 0.43), text: .white, icon: Color(red: 1.00, green: 0.78, blue: 0.78))
        case "magenta":
            return .init(fillTop: Color(red: 0.39, green: 0.12, blue: 0.34), fillBottom: Color(red: 0.23, green: 0.08, blue: 0.22), stroke: Color(red: 0.95, green: 0.48, blue: 0.85), text: .white, icon: Color(red: 1.00, green: 0.80, blue: 0.96))
        case "slate":
            return .init(fillTop: Color(red: 0.17, green: 0.21, blue: 0.30), fillBottom: Color(red: 0.10, green: 0.13, blue: 0.20), stroke: Color(red: 0.57, green: 0.65, blue: 0.82), text: .white, icon: Color(red: 0.86, green: 0.90, blue: 1.00))
        case "cyan":
            return .init(fillTop: Color(red: 0.10, green: 0.28, blue: 0.35), fillBottom: Color(red: 0.06, green: 0.17, blue: 0.22), stroke: Color(red: 0.37, green: 0.90, blue: 1.00), text: .white, icon: Color(red: 0.79, green: 0.98, blue: 1.00))
        case "orange":
            return .init(fillTop: Color(red: 0.42, green: 0.18, blue: 0.08), fillBottom: Color(red: 0.26, green: 0.11, blue: 0.05), stroke: Color(red: 1.00, green: 0.58, blue: 0.30), text: .white, icon: Color(red: 1.00, green: 0.84, blue: 0.69))
        case "game":
            return .init(fillTop: Color(red: 0.14, green: 0.22, blue: 0.50), fillBottom: Color(red: 0.08, green: 0.13, blue: 0.31), stroke: Color(red: 0.47, green: 0.73, blue: 1.00), text: .white, icon: Color(red: 0.86, green: 0.94, blue: 1.00))
        default:
            return .init(fillTop: Color(red: 0.18, green: 0.19, blue: 0.23), fillBottom: Color(red: 0.12, green: 0.13, blue: 0.16), stroke: Color(red: 0.57, green: 0.58, blue: 0.64), text: .white, icon: Color(red: 0.90, green: 0.91, blue: 0.95))
        }
    }

    static func cornerRadius(for variant: FeedBadgeVariant) -> CGFloat {
        switch variant {
        case .filterChip:
            return 12
        case .detailBadge:
            return 10
        case .iconOnly:
            return 8
        case .feedCompact, .feedFull:
            return 9
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

    // TODO: Replace symbolic/SF Symbol placeholders with final category + game art assets.
}
