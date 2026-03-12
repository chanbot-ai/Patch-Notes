import SwiftUI

struct FeedPostRow: View {
    let post: Post
    let authorProfile: PublicProfile?
    let linkedGame: Game?
    let reactionCountOverride: Int
    let reactionTypes: [ReactionType]
    let reactionCounts: [PostReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void
    let onOpenPostDetail: (() -> Void)?
    let onOpenComments: () -> Void
    let onGameTap: ((Game.ID) -> Void)?
    var showJoinButton: Bool = false
    var isGameFollowed: Bool = true
    var onJoinGame: (() -> Void)?

    @State private var showingReactionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Header: Game icon + info + Share
            HStack(alignment: .top, spacing: 12) {
                if let linkedGame {
                    Button {
                        onGameTap?(linkedGame.id)
                    } label: {
                        RemoteMediaImage(
                            primaryURL: linkedGame.coverImageURL,
                            fallbackURL: MediaFallback.gameCover
                        )
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let linkedGame {
                        Button {
                            onGameTap?(linkedGame.id)
                        } label: {
                            Text(linkedGame.title)
                                .font(.callout.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    authorRow

                    Text(compactRelativeTimestamp(post.created_at))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 4)

                if showJoinButton && !isGameFollowed, let onJoinGame {
                    Button {
                        onJoinGame()
                    } label: {
                        Text("Join")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    sharePost()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Share")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.50))
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            // MARK: - Title
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenComments() }
            }

            // MARK: - Source attribution
            if let viaLabel = post.viaAttributionLabel {
                Text(viaLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if post.isExternalSource {
                PostSourceMetaRow(post: post)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: - Body text
            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenComments() }
            }

            // MARK: - Media preview
            PostMediaPreview(post: post, height: 190, onVideoTap: onOpenPostDetail)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard post.contentType == .image else { return }
                        onOpenComments()
                    }
                )

            // MARK: - Sleeper-style reaction bar + comments
            HStack(spacing: 0) {
                // Top 5 reactions (large emoji + count below)
                if !reactionTypes.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(topReactions.prefix(4), id: \.type.id) { item in
                            Button {
                                onReact(item.type.id)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(item.type.emoji)
                                        .font(.title2)
                                    Text(compactCount(item.count))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(
                                            item.isSelected ? .white : .white.opacity(0.55)
                                        )
                                }
                                .frame(minWidth: 36)
                                .opacity(item.isSelected ? 1.0 : 0.85)
                            }
                            .buttonStyle(.plain)
                        }

                        // Reaction picker button
                        Button {
                            showingReactionPicker = true
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "face.smiling")
                                    .font(.title2)
                                Text("+")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(.white.opacity(0.40))
                            .frame(minWidth: 36)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingReactionPicker) {
                            reactionPickerGrid
                        }
                    }
                }

                Spacer(minLength: 8)

                // Comments button with count
                Button {
                    onOpenComments()
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20, weight: .semibold))
                            if let count = post.comment_count, count > 0 {
                                Text(compactCount(count))
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        Text("Comments")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(minWidth: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.surfaceTop.opacity(0.96), AppTheme.surfaceBottom.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 7)
    }

    // MARK: - Reaction Picker

    private var reactionPickerGrid: some View {
        ReactionPickerSheet(
            reactionTypes: reactionTypes,
            selectedReactionTypeIDs: selectedReactionTypeIDs,
            onReact: { typeID in
                onReact(typeID)
                showingReactionPicker = false
            }
        )
    }

    // MARK: - Author Row

    @ViewBuilder
    private var authorRow: some View {
        if let authorText = authorDisplayName {
            HStack(spacing: 4) {
                if authorProfile?.isBot == true {
                    Image(systemName: "gearshape.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accentBlue)
                } else {
                    Image(systemName: "seal.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
                Text(authorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                if authorProfile?.isBot == true {
                    Text("BOT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.accentBlue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppTheme.accentBlue.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    // MARK: - Reaction Helpers

    private struct ReactionItem {
        let type: ReactionType
        let count: Int
        let isSelected: Bool
    }

    private var topReactions: [ReactionItem] {
        reactionTypes.map { type in
            let count = reactionCounts.first(where: { $0.reactionTypeID == type.id })?.count ?? 0
            let isSelected = selectedReactionTypeIDs.contains(type.id)
            return ReactionItem(type: type, count: count, isSelected: isSelected)
        }
    }

    private func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }

    // MARK: - Share

    private func sharePost() {
        let title = post.title ?? "Check out this post on Patch Notes"
        let activityVC = UIActivityViewController(
            activityItems: [title],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Helpers

    private var authorDisplayName: String? {
        guard let authorProfile else { return nil }
        if let displayName = authorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return authorProfile.username
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
            reactionCountOverride: 12,
            reactionTypes: reactions,
            reactionCounts: counts,
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {},
            onGameTap: nil
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
            reactionCountOverride: 5,
            reactionTypes: PreviewHelpers.makeReactionTypes(),
            reactionCounts: [],
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {},
            onGameTap: nil
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
            reactionCountOverride: 3,
            reactionTypes: PreviewHelpers.makeReactionTypes(),
            reactionCounts: [],
            selectedReactionTypeIDs: [],
            onReact: { _ in },
            onOpenPostDetail: nil,
            onOpenComments: {},
            onGameTap: nil
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
