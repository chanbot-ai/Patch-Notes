import SwiftUI

struct FeedPostRow: View {
    let post: Post
    let authorProfile: PublicProfile?
    let linkedGame: Game?
    let badgeGame: Game?
    let reactionCountOverride: Int
    let reactionTypes: [ReactionType]
    let reactionCounts: [PostReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void
    let onOpenPostDetail: (() -> Void)?
    let onOpenComments: () -> Void

    var body: some View {
        let badgeKey = primaryBadgeKey
        let badgeTitle = badgeGameTitle
        let badgeAlias = badgeCompactAlias

        VStack(alignment: .leading, spacing: 8) {
            if let authorText = authorDisplayName {
                Text(authorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenComments()
                    }
            }
            if post.isExternalSource {
                PostSourceMetaRow(post: post)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenComments()
                    }
            } else {
                Text(post.fallbackHeadlineText)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenComments()
                    }
            }

            if let linkedGame {
                NavigationLink {
                    GameReleaseDetailView(game: linkedGame)
                } label: {
                    GameContextChip(game: linkedGame)
                }
                .buttonStyle(.plain)
            }

            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenComments()
                    }
            }

            PostMediaPreview(post: post, height: 190, onVideoTap: onOpenPostDetail)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard post.contentType == .image else { return }
                        onOpenComments()
                    }
                )

            if !reactionTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reactionTypes) { type in
                            let count = reactionCounts.first(where: { $0.reactionTypeID == type.id })?.count ?? 0
                            let isSelected = selectedReactionTypeIDs.contains(type.id)

                            Button {
                                onReact(type.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(type.emoji)
                                    Text("\(count)")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.78))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    (isSelected ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.06)),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected ? AppTheme.accent.opacity(0.45) : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 12) {
                Label("\(reactionCountOverride)", systemImage: "face.smiling")
                Button {
                    onOpenComments()
                } label: {
                    Label("\(post.comment_count ?? 0)", systemImage: "bubble.right")
                }
                .buttonStyle(.plain)
                if let hotScore = post.hot_score {
                    Label(String(format: "%.1f", hotScore), systemImage: "flame.fill")
                }
                Spacer()
                Text(compactRelativeTimestamp(post.created_at))
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))

            Button {
                onOpenComments()
            } label: {
                Text((post.comment_count ?? 0) > 0 ? "View Comments" : "Add Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            cornerBadgeOverlay(key: badgeKey, gameTitle: badgeTitle, gameCompactAlias: badgeAlias)
        }
    }

    @ViewBuilder
    private func cornerBadgeOverlay(
        key: FeedBadgeKey,
        gameTitle: String?,
        gameCompactAlias: String?
    ) -> some View {
        FeedPostCornerBadgeView(
            key: key,
            gameTitle: gameTitle,
            gameCompactAlias: gameCompactAlias
        )
        .allowsHitTesting(false)
        .padding(.trailing, 10)
        .padding(.top, 8)
    }

    private var authorDisplayName: String? {
        guard let authorProfile else { return nil }
        if let displayName = authorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "u/\(authorProfile.username)"
    }

    private var primaryBadgeKey: FeedBadgeKey {
        if let rawBadgeKey = post.primaryBadgeKeyRaw {
            let parsed = FeedBadgeKey(rawValue: rawBadgeKey)
            if parsed.category != .unspecified || rawBadgeKey == FeedBadgeCategory.unspecified.rawValue {
                return parsed
            }
            // Invalid server value: continue to local fallback instead of rendering as unspecified.
        }
        if let linkedGame {
            return FeedBadgeKey(gameID: linkedGame.id.uuidString.lowercased())
        }
        if let gameID = post.gameID {
            return FeedBadgeKey(gameID: gameID.uuidString.lowercased())
        }
        return FeedBadgeKey(category: .generalGaming)
    }

    private var badgeGameTitle: String? {
        guard primaryBadgeKey.isGame else { return nil }
        if let badgeGame {
            return badgeGame.title
        }
        if post.gameID != nil {
            return "Game"
        }
        return nil
    }

    private var badgeCompactAlias: String? {
        guard primaryBadgeKey.isGame else { return nil }
        if let title = badgeGame?.title {
            return compactGameBadgeAlias(from: title)
        }
        if post.gameID != nil {
            return "GAME"
        }
        return nil
    }

    private func compactGameBadgeAlias(from title: String) -> String {
        let parts = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let initials = parts
                .prefix(4)
                .compactMap(\.first)
            let alias = String(initials).uppercased()
            if !alias.isEmpty {
                return alias
            }
        }

        return String(title.prefix(4)).uppercased()
    }
}

struct GameContextChip: View {
    let game: Game

    var body: some View {
        HStack(spacing: 8) {
            RemoteMediaImage(primaryURL: game.coverImageURL, fallbackURL: MediaFallback.gameCover)
                .frame(width: 22, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            Text(game.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct PostSourceMetaRow: View {
    let post: Post
    var showsOpenLink: Bool = false

    private var sourceLabel: String? {
        post.sourcePillLabel
    }

    private var sourceURL: URL? {
        post.sourceURL
    }

    private var sourceActionLabel: String {
        if post.sourceProviderDisplayName == "X" {
            return "Open Original X Post"
        }
        return "Open Original"
    }

    private var iconName: String {
        if post.sourceProviderDisplayName == "X" {
            return "bubble.left.and.bubble.right.fill"
        }
        return "link"
    }

    var body: some View {
        Group {
            if sourceLabel != nil || (showsOpenLink && sourceURL != nil) {
                HStack(spacing: 8) {
                    if let sourceLabel {
                        HStack(spacing: 6) {
                            Image(systemName: iconName)
                                .font(.caption2.weight(.bold))
                            Text(sourceLabel)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    if showsOpenLink, let sourceURL {
                        Link(destination: sourceURL) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.right")
                                Text(sourceActionLabel)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("FeedPostRow - Text") {
    let post = PreviewHelpers.makePost()
    let reactions = PreviewHelpers.makeReactionTypes()
    let counts = PreviewHelpers.makeReactionCounts(postID: post.id)
    return ScrollView {
        FeedPostRow(
            post: post,
            authorProfile: PreviewHelpers.makeProfile(),
            linkedGame: PreviewHelpers.makeGame(),
            badgeGame: nil,
            reactionCountOverride: 12,
            reactionTypes: reactions,
            reactionCounts: counts,
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("FeedPostRow - Image") {
    let post = PreviewHelpers.makeImagePost()
    return ScrollView {
        FeedPostRow(
            post: post,
            authorProfile: PreviewHelpers.makeProfile(),
            linkedGame: nil,
            badgeGame: nil,
            reactionCountOverride: 5,
            reactionTypes: PreviewHelpers.makeReactionTypes(),
            reactionCounts: [],
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("FeedPostRow - Link") {
    let post = PreviewHelpers.makeLinkPost()
    return ScrollView {
        FeedPostRow(
            post: post,
            authorProfile: PreviewHelpers.makeProfile(),
            linkedGame: nil,
            badgeGame: nil,
            reactionCountOverride: 3,
            reactionTypes: PreviewHelpers.makeReactionTypes(),
            reactionCounts: [],
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
