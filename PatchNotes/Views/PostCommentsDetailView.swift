import SwiftUI

struct PostCommentsDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let post: Post

    @State private var draftComment = ""
    @State private var replyingToRootCommentID: UUID?
    @State private var expandedReplyParentIDs: Set<UUID> = []

    private var comments: [Comment] {
        store.comments(for: post.id)
    }

    private var rootComments: [Comment] {
        let roots = comments.filter { $0.parentCommentID == nil }
        let replies = Dictionary(
            grouping: comments.filter { $0.parentCommentID != nil },
            by: { $0.parentCommentID! }
        )

        switch store.commentSortMode(for: post.id) {
        case .new:
            return roots.sorted { $0.created_at > $1.created_at }
        case .top:
            return roots.sorted { lhs, rhs in
                let lhsReplyCount = replies[lhs.id]?.count ?? 0
                let rhsReplyCount = replies[rhs.id]?.count ?? 0
                let lhsScore = topSortScore(for: lhs, replyCount: lhsReplyCount)
                let rhsScore = topSortScore(for: rhs, replyCount: rhsReplyCount)
                if lhsScore == rhsScore {
                    return lhs.created_at > rhs.created_at
                }
                return lhsScore > rhsScore
            }
        }
    }

    private var repliesByParent: [UUID: [Comment]] {
        let grouped = Dictionary(
            grouping: comments.filter { $0.parentCommentID != nil },
            by: { $0.parentCommentID! }
        )
        switch store.commentSortMode(for: post.id) {
        case .new:
            return grouped.mapValues { $0.sorted { $0.created_at > $1.created_at } }
        case .top:
            return grouped.mapValues { comments in
                comments.sorted { lhs, rhs in
                    let lhsScore = topSortScore(for: lhs, replyCount: 0)
                    let rhsScore = topSortScore(for: rhs, replyCount: 0)
                    if lhsScore == rhsScore {
                        return lhs.created_at > rhs.created_at
                    }
                    return lhsScore > rhsScore
                }
            }
        }
    }

    private var replyTargetComment: Comment? {
        guard let replyingToRootCommentID else { return nil }
        return rootComments.first(where: { $0.id == replyingToRootCommentID })
    }

    private var canSubmit: Bool {
        !draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var commentSortSelection: Binding<CommentSortMode> {
        Binding(
            get: { store.commentSortMode(for: post.id) },
            set: { store.setCommentSort($0, for: post.id) }
        )
    }

    private var linkedGame: Game? {
        store.game(for: post.gameID)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                postHeader
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if store.commentIsLoadingByPost.contains(post.id) && comments.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading comments...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if let loadError = store.commentLoadErrorByPost[post.id], comments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comments failed to load")
                            .font(.headline)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            store.loadInitialComments(for: post.id)
                        }
                    }
                    .foregroundStyle(.red)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if !store.commentIsLoadingByPost.contains(post.id),
                   comments.isEmpty,
                   store.commentLoadErrorByPost[post.id] == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No comments yet")
                            .font(.headline)
                        Text("Start the conversation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(rootComments) { comment in
                    let replies = repliesByParent[comment.id] ?? []
                    let repliesExpanded = expandedReplyParentIDs.contains(comment.id)
                    VStack(alignment: .leading, spacing: 0) {
                        CommentRowCard(
                            comment: comment,
                            authorProfile: store.publicProfile(for: comment.userID) ?? comment.authorProfile,
                            isReply: false,
                            reactionTypes: store.reactionTypes,
                            reactionCounts: store.commentReactionCounts(for: comment.id),
                            selectedReactionTypeIDs: store.viewerCommentReactionTypeIDsByComment[comment.id] ?? [],
                            reactionTotalOverride: store.commentReactionTotal(for: comment),
                            authorFavoriteGames: store.favoriteGames(for: comment.userID),
                            onReact: { reactionTypeID in
                                store.reactToComment(comment.id, reactionTypeId: reactionTypeID)
                            },
                            onReply: {
                                replyingToRootCommentID = comment.id
                            }
                        )

                        if !replies.isEmpty {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 2)
                                    .padding(.leading, 16)

                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        if repliesExpanded {
                                            expandedReplyParentIDs.remove(comment.id)
                                        } else {
                                            expandedReplyParentIDs.insert(comment.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: repliesExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption2.weight(.bold))
                                        Text("\(replies.count) \(replies.count == 1 ? "Reply" : "Replies")")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.white.opacity(0.60))
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }

                            if repliesExpanded {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(replies) { reply in
                                        HStack(alignment: .top, spacing: 8) {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.10))
                                                .frame(width: 2)

                                            CommentRowCard(
                                                comment: reply,
                                                authorProfile: store.publicProfile(for: reply.userID) ?? reply.authorProfile,
                                                isReply: true,
                                                reactionTypes: store.reactionTypes,
                                                reactionCounts: store.commentReactionCounts(for: reply.id),
                                                selectedReactionTypeIDs: store.viewerCommentReactionTypeIDsByComment[reply.id] ?? [],
                                                reactionTotalOverride: store.commentReactionTotal(for: reply),
                                                authorFavoriteGames: store.favoriteGames(for: reply.userID),
                                                onReact: { reactionTypeID in
                                                    store.reactToComment(reply.id, reactionTypeId: reactionTypeID)
                                                },
                                                onReply: {
                                                    replyingToRootCommentID = comment.id
                                                }
                                            )
                                        }
                                        .padding(.leading, 16)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.top, 3)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if store.commentHasMoreByPost[post.id] == true,
                   store.commentLoadErrorByPost[post.id] == nil {
                    VStack(spacing: 6) {
                        HStack {
                            Spacer()
                            Button {
                                store.loadMoreComments(for: post.id)
                            } label: {
                                if store.commentIsLoadingByPost.contains(post.id) {
                                    ProgressView()
                                } else {
                                    Text("Load More Comments")
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        Text("Showing \(comments.count) comments")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)

            commentComposer
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.25)
                }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task(id: post.id) {
            store.ensureCommentsLoaded(for: post.id)
        }
        .overlay(alignment: .top) {
            if let reactionErrorMessage = store.reactionErrorMessage {
                ReactionErrorToast(message: reactionErrorMessage)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.reactionErrorMessage)
    }

    private var postHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Game icon + info
            HStack(alignment: .top, spacing: 10) {
                if let linkedGame {
                    RemoteMediaImage(
                        primaryURL: linkedGame.coverImageURL,
                        fallbackURL: MediaFallback.gameCover
                    )
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let linkedGame {
                        Text(linkedGame.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    if let authorProfile = store.publicProfile(for: post.authorID) {
                        HStack(spacing: 5) {
                            Image(systemName: "seal.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                            Text(authorDisplayName(for: authorProfile))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                            let postAuthorBadges = store.favoriteGames(for: post.authorID)
                            if !postAuthorBadges.isEmpty {
                                HStack(spacing: 3) {
                                    ForEach(postAuthorBadges.prefix(3)) { badge in
                                        RemoteMediaImage(
                                            primaryURL: badge.coverImageURL,
                                            fallbackURL: MediaFallback.gameCover
                                        )
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text(compactRelativeTimestamp(post.created_at))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)
            }

            if post.isExternalSource {
                PostSourceMetaRow(post: post, showsOpenLink: true)
            }

            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            } else if post.isExternalSource {
                Text(post.fallbackHeadlineText)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }

            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.76))
            }

            PostMediaPreview(post: post, height: 230)

            HStack(spacing: 10) {
                Label("\(post.comment_count ?? 0)", systemImage: "bubble.right")
                if let hotScore = post.hot_score {
                    Label(String(format: "%.1f", hotScore), systemImage: "flame.fill")
                }
                Spacer()
                Picker("Comment Sort", selection: commentSortSelection) {
                    ForEach(CommentSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 150)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppTheme.surfaceTop.opacity(0.96), AppTheme.surfaceBottom.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    private func authorDisplayName(for profile: PublicProfile) -> String {
        if let displayName = profile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return profile.username
    }

    private func topSortScore(for comment: Comment, replyCount: Int) -> Double {
        let liveReactionTotal = store.commentReactionTotal(for: comment)
        let reactionScore = max(
            Double(comment.reaction_count ?? 0),
            Double(liveReactionTotal),
            comment.hot_score ?? 0
        )
        let replyScore = Double(replyCount) * 2.0
        return reactionScore + replyScore
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if replyTargetComment != nil {
                HStack(spacing: 8) {
                    Text("Replying to comment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Button("Cancel") {
                        replyingToRootCommentID = nil
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    replyTargetComment == nil ? "Add a comment..." : "Write a reply...",
                    text: $draftComment,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    let parentId = replyingToRootCommentID
                    store.addComment(to: post.id, body: draftComment, parentId: parentId)
                    draftComment = ""
                    replyingToRootCommentID = nil
                } label: {
                    Text("Send")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

struct CommentRowCard: View {
    let comment: Comment
    let authorProfile: PublicProfile?
    let isReply: Bool
    let reactionTypes: [ReactionType]
    let reactionCounts: [CommentReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let reactionTotalOverride: Int
    var authorFavoriteGames: [FavoriteGameBadge] = []
    let onReact: (UUID) -> Void
    let onReply: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header: author + badges + timestamp + Reply
            HStack(spacing: 5) {
                if let authorText = authorDisplayName {
                    Text(authorText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                if !authorFavoriteGames.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(authorFavoriteGames.prefix(3)) { badge in
                            RemoteMediaImage(
                                primaryURL: badge.coverImageURL,
                                fallbackURL: MediaFallback.gameCover
                            )
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            }
                        }
                    }
                }

                Text("\u{00B7}")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))

                Text(compactRelativeTimestamp(comment.created_at))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                if let onReply {
                    Button {
                        onReply()
                    } label: {
                        Text("Reply")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Body
            Text(comment.body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Inline reactions (compact row)
            if !reactionTypes.isEmpty {
                HStack(spacing: 4) {
                    ForEach(reactionTypes.prefix(4)) { type in
                        let count = reactionCounts.first(where: { $0.reactionTypeID == type.id })?.count ?? 0
                        let isSelected = selectedReactionTypeIDs.contains(type.id)
                        Button {
                            onReact(type.id)
                        } label: {
                            HStack(spacing: 2) {
                                Text(type.emoji)
                                    .font(.caption2)
                                Text("\(count)")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.50))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                isSelected ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.04),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: "face.smiling")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
    }

    private var authorDisplayName: String? {
        // Try passed-in profile
        if let authorProfile {
            if let displayName = authorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !displayName.isEmpty {
                return displayName
            }
            return authorProfile.username
        }
        // Fall back to comment's embedded author data
        if let displayName = comment.author_display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return comment.author_username
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Comments - Populated") {
    let post = PreviewHelpers.makePost(commentCount: 3)
    let comments = [
        PreviewHelpers.makeComment(postID: post.id, body: "Absolutely wild reveal."),
        PreviewHelpers.makeComment(postID: post.id, body: "Been waiting for this since 2023."),
        PreviewHelpers.makeComment(postID: post.id, body: "Day one buy for me.")
    ]
    let profile = PreviewHelpers.makeProfile()
    let reactions = PreviewHelpers.makeReactionTypes()
    let store = AppStore()
    store.seedPreviewState(AppPreviewState(
        posts: [post],
        reactionTypes: reactions,
        reactionCountsByPost: [post.id: PreviewHelpers.makeReactionCounts(postID: post.id)],
        reactionTotalsByPost: [post.id: 12],
        publicProfilesByID: [profile.id: profile],
        commentsByPost: [post.id: comments]
    ))
    return NavigationStack {
        PostCommentsDetailView(post: post)
            .environmentObject(store)
    }
    .preferredColorScheme(.dark)
}

#Preview("Comments - Empty") {
    let post = PreviewHelpers.makePost(commentCount: 0)
    let store = AppStore()
    store.seedPreviewState(AppPreviewState(
        posts: [post],
        reactionTypes: PreviewHelpers.makeReactionTypes(),
        commentsByPost: [post.id: []]
    ))
    return NavigationStack {
        PostCommentsDetailView(post: post)
            .environmentObject(store)
    }
    .preferredColorScheme(.dark)
}
#endif
