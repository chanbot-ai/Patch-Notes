import SwiftUI

struct PostCommentsDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let post: Post
    var highlightCommentID: UUID? = nil

    @State private var draftComment = ""
    @State private var replyingToRootCommentID: UUID?
    @State private var replyToSpecificCommentID: UUID?
    @State private var expandedReplyParentIDs: Set<UUID> = []
    @State private var hasScrolledToHighlight = false
    @FocusState private var isCommentFocused: Bool

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
            ScrollViewReader { scrollProxy in
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
                            authorDisplayBadges: store.displayBadges(for: comment.userID),
                            onReact: { reactionTypeID in
                                store.reactToComment(comment.id, reactionTypeId: reactionTypeID)
                            },
                            onReply: {
                                replyingToRootCommentID = comment.id
                                replyToSpecificCommentID = nil
                            },
                            currentUserID: store.authenticatedUserID,
                            currentUserAvatarEmoji: store.currentUserAvatarEmoji
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
                                                authorDisplayBadges: store.displayBadges(for: reply.userID),
                                                onReact: { reactionTypeID in
                                                    store.reactToComment(reply.id, reactionTypeId: reactionTypeID)
                                                },
                                                onReply: {
                                                    replyingToRootCommentID = comment.id
                                                    replyToSpecificCommentID = reply.id
                                                },
                                                currentUserID: store.authenticatedUserID,
                                                currentUserAvatarEmoji: store.currentUserAvatarEmoji
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
                    .id(comment.id)
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
            .onChange(of: comments.count) { _, _ in
                scrollToHighlightIfNeeded(proxy: scrollProxy)
            }
            } // ScrollViewReader

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
        .overlay(alignment: .top) {
            if let badge = store.newlyUnlockedBadge {
                HStack(spacing: 10) {
                    Text(badge.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Badge Unlocked!")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(badge.label)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.newlyUnlockedBadge?.slug)
        .onAppear {
            if highlightCommentID == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCommentFocused = true
                }
            }
        }
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
                            Text(authorProfile.avatarEmoji)
                                .font(.system(size: 14))
                            Text(authorDisplayName(for: authorProfile))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                            let postAuthorBadges = store.displayBadges(for: post.authorID)
                            if !postAuthorBadges.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(postAuthorBadges.prefix(3)) { badge in
                                        Text(badge.emoji)
                                            .font(.system(size: 12))
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

    private func scrollToHighlightIfNeeded(proxy: ScrollViewProxy) {
        guard let targetID = highlightCommentID,
              !hasScrolledToHighlight,
              !comments.isEmpty else { return }

        // Check if the target comment exists in the loaded comments
        guard comments.contains(where: { $0.id == targetID }) else { return }

        // If the target is a reply, auto-expand its parent's reply chain
        if let targetComment = comments.first(where: { $0.id == targetID }),
           let parentID = targetComment.parentCommentID {
            expandedReplyParentIDs.insert(parentID)
        }

        hasScrolledToHighlight = true

        // Delay slightly to let expansion animation settle
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                // If it's a reply, scroll to the parent (since replies are inside the parent row)
                if let targetComment = comments.first(where: { $0.id == targetID }),
                   let parentID = targetComment.parentCommentID {
                    proxy.scrollTo(parentID, anchor: .top)
                } else {
                    proxy.scrollTo(targetID, anchor: .top)
                }
            }
        }
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
                .focused($isCommentFocused)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    let parentId = replyingToRootCommentID
                    let replyToId = replyToSpecificCommentID
                    store.addComment(to: post.id, body: draftComment, parentId: parentId, replyToCommentId: replyToId)
                    if let parentId {
                        expandedReplyParentIDs.insert(parentId)
                    }
                    draftComment = ""
                    replyingToRootCommentID = nil
                    replyToSpecificCommentID = nil
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
    var authorDisplayBadges: [DisplayBadge] = []
    let onReact: (UUID) -> Void
    let onReply: (() -> Void)?
    var currentUserID: UUID? = nil
    var currentUserAvatarEmoji: String = "🎮"

    @State private var showingCommentReactionPicker = false

    private var activeCommentReactions: [(type: ReactionType, count: Int)] {
        reactionCounts.compactMap { rc in
            guard let type = reactionTypes.first(where: { $0.id == rc.reactionTypeID }), rc.count > 0 else { return nil }
            return (type: type, count: rc.count)
        }
        .sorted { $0.count > $1.count }
        .prefix(3)
        .map { $0 }
    }

    private var heartReactionType: ReactionType? {
        reactionTypes.first { $0.emoji == "💜" } ?? reactionTypes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header: avatar + author + badges + timestamp + Reply
            HStack(spacing: 5) {
                Text({
                    if let uid = currentUserID, comment.user_id == uid {
                        return currentUserAvatarEmoji
                    }
                    return authorProfile?.avatarEmoji ?? AvatarCatalog.emoji(for: comment.author_avatar_slug)
                }())
                    .font(.system(size: 18))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08), in: Circle())

                if let authorText = authorDisplayName {
                    Text(authorText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                if !authorDisplayBadges.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(authorDisplayBadges.prefix(3)) { badge in
                            Text(badge.emoji)
                                .font(.system(size: 12))
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

            // Inline reactions: heart + top reactions + picker
            if !reactionTypes.isEmpty {
                HStack(spacing: 4) {
                    // Default heart reaction button
                    if let heart = heartReactionType {
                        let heartSelected = selectedReactionTypeIDs.contains(heart.id)
                        let heartCount = reactionCounts.first(where: { $0.reactionTypeID == heart.id })?.count ?? 0
                        Button {
                            onReact(heart.id)
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: heartSelected ? "heart.fill" : "heart")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(heartSelected ? .purple : .white.opacity(0.50))
                                if heartCount > 0 {
                                    Text("\(heartCount)")
                                        .font(.caption2.weight(.semibold))
                                }
                            }
                            .foregroundStyle(.white.opacity(heartSelected ? 0.96 : 0.50))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                heartSelected ? Color.purple.opacity(0.15) : Color.white.opacity(0.04),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Top 2-3 most-used reactions (excluding heart if already shown)
                    ForEach(activeCommentReactions.filter { $0.type.id != heartReactionType?.id }, id: \.type.id) { item in
                        let isSelected = selectedReactionTypeIDs.contains(item.type.id)
                        Button {
                            onReact(item.type.id)
                        } label: {
                            HStack(spacing: 2) {
                                Text(item.type.emoji)
                                    .font(.caption2)
                                Text("\(item.count)")
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

                    // Full picker button
                    Button {
                        showingCommentReactionPicker = true
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingCommentReactionPicker) {
                        ReactionPickerSheet(
                            reactionTypes: reactionTypes,
                            selectedReactionTypeIDs: selectedReactionTypeIDs,
                            onReact: { typeID in
                                onReact(typeID)
                                showingCommentReactionPicker = false
                            }
                        )
                    }
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
