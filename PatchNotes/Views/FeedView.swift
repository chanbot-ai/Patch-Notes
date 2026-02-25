import SwiftUI
import Foundation
import Supabase

private enum FeedScope: String, CaseIterable, Identifiable {
    case hot
    case following

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot: return "Hot"
        case .following: return "Following"
        }
    }
}

private func compactRelativeTimestamp(_ date: Date, now: Date = Date()) -> String {
    let delta = max(Int(now.timeIntervalSince(date)), 0)
    if delta < 60 { return "now" }
    if delta < 3_600 { return "\(delta / 60)m" }
    if delta < 86_400 { return "\(delta / 3_600)h" }
    if delta < 604_800 { return "\(delta / 86_400)d" }
    if delta < 2_592_000 { return "\(delta / 604_800)w" }
    if delta < 31_536_000 { return "\(delta / 2_592_000)mo" }
    return "\(delta / 31_536_000)y"
}

private extension URL {
    var isGIFAsset: Bool {
        pathExtension.lowercased() == "gif"
    }
}

struct FeedView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore

    @State private var showingComposer = false
    @State private var showingNotifications = false
    @State private var selectedCommentsPost: Post?
    @State private var feedScope: FeedScope = .hot

    private var activePosts: [Post] {
        switch feedScope {
        case .hot: return store.posts
        case .following: return store.followingPosts
        }
    }

    private var activeFeedIsLoading: Bool {
        switch feedScope {
        case .hot: return store.feedIsLoading
        case .following: return store.followingFeedIsLoading
        }
    }

    private var activeFeedErrorMessage: String? {
        switch feedScope {
        case .hot: return store.feedErrorMessage
        case .following: return store.followingFeedErrorMessage
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Feed", selection: $feedScope) {
                    ForEach(FeedScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Color.clear)

            if activeFeedIsLoading && activePosts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading feed...")
                    Spacer()
                }
            }

            if let errorMessage = activeFeedErrorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feed Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .foregroundStyle(.red)
            }

            if !activeFeedIsLoading && activePosts.isEmpty && activeFeedErrorMessage == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No posts yet")
                        .font(.headline)
                    Text(feedScope == .hot ? "Create the first post from the compose button." : "Follow some games to populate your following feed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if feedScope == .following {
                        HStack(spacing: 10) {
                            NavigationLink {
                                ReleaseCalendarView()
                            } label: {
                                Text("Browse Calendar")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.accent.opacity(0.28), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                MyGamesView()
                            } label: {
                                Text("My Games")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            ForEach(activePosts) { post in
                FeedPostRow(
                    post: post,
                    authorProfile: store.publicProfile(for: post.authorID),
                    linkedGame: store.game(for: post.gameID),
                    reactionCountOverride: store.reactionTotal(for: post),
                    reactionTypes: store.reactionTypes,
                    reactionCounts: store.reactionCountsByPost[post.id] ?? [],
                    selectedReactionTypeIDs: store.viewerReactionTypeIDsByPost[post.id] ?? [],
                    onReact: { reactionTypeID in
                        store.react(to: post.id, with: reactionTypeID)
                    },
                    onOpenComments: {
                        selectedCommentsPost = post
                    }
                )
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 36, minHeight: 36)
                .accessibilityLabel("Create post")
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(10)
                            .background(Color.white.opacity(0.08), in: Circle())

                        if store.unreadNotificationsCount > 0 {
                            Text("\(min(store.unreadNotificationsCount, 99))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent, in: Capsule())
                                .offset(x: 12, y: -10)
                        }
                    }
                    .frame(minWidth: 34, minHeight: 34)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .accessibilityLabel(
                    store.unreadNotificationsCount > 0
                    ? "Notifications, \(store.unreadNotificationsCount) unread"
                    : "Notifications"
                )
            }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                PostComposerView {
                    store.loadHotFeed()
                }
                .environmentObject(authManager)
                .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCommentsPost) { post in
            NavigationStack {
                PostCommentsDetailView(post: post)
                    .environmentObject(store)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationStack {
                NotificationsInboxView { notification in
                    Task { @MainActor in
                        guard let post = await store.resolveNotificationPost(notification) else { return }
                        selectedCommentsPost = post
                    }
                }
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .refreshable {
            switch feedScope {
            case .hot:
                await store.refreshHotFeed()
            case .following:
                await store.refreshFollowingFeed()
            }
        }
        .onChange(of: feedScope) { _, newValue in
            if newValue == .following, store.followingPosts.isEmpty, !store.followingFeedIsLoading {
                store.loadFollowingFeed()
            }
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
        .task {
            if feedScope == .following, store.followingPosts.isEmpty, !store.followingFeedIsLoading {
                store.loadFollowingFeed()
            }
        }
    }
}

private struct FeedPostRow: View {
    let post: Post
    let authorProfile: PublicProfile?
    let linkedGame: Game?
    let reactionCountOverride: Int
    let reactionTypes: [ReactionType]
    let reactionCounts: [PostReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void
    let onOpenComments: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let authorText = authorDisplayName {
                Text(authorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(post.type.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            }

            PostMediaPreview(post: post, height: 190)

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
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var authorDisplayName: String? {
        guard let authorProfile else { return nil }
        if let displayName = authorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "u/\(authorProfile.username)"
    }
}

private struct GameContextChip: View {
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

private struct PostMediaPreview: View {
    let post: Post
    var height: CGFloat = 190

    var body: some View {
        Group {
            if let mediaURL = post.mediaURL, post.contentType != .text {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(height: height)

                    switch post.contentType {
                    case .text:
                        EmptyView()
                    case .image:
                        if mediaURL.isGIFAsset {
                            EmbeddedVideoPlayer(source: .web(mediaURL))
                                .frame(height: height)
                                .allowsHitTesting(false)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            RemoteMediaImage(primaryURL: mediaURL, fallbackURL: MediaFallback.gameScreenshot)
                                .frame(height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    case .video:
                        let previewURL = post.thumbnailURL ?? mediaURL
                        RemoteMediaImage(primaryURL: previewURL, fallbackURL: MediaFallback.videoThumbnail)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: height * 0.3, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                            }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .accessibilityHidden(true)
            }
        }
    }
}

private struct PostCommentsDetailView: View {
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
                    VStack(alignment: .leading, spacing: 10) {
                        CommentRowCard(
                            comment: comment,
                            authorProfile: store.publicProfile(for: comment.userID),
                            isReply: false,
                            reactionTypes: store.reactionTypes,
                            reactionCounts: store.commentReactionCounts(for: comment.id),
                            selectedReactionTypeIDs: store.viewerCommentReactionTypeIDsByComment[comment.id] ?? [],
                            reactionTotalOverride: store.commentReactionTotal(for: comment),
                            onReact: { reactionTypeID in
                                store.reactToComment(comment.id, reactionTypeId: reactionTypeID)
                            },
                            onReply: {
                                replyingToRootCommentID = comment.id
                            }
                        )

                        if !replies.isEmpty {
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        if repliesExpanded {
                                            expandedReplyParentIDs.remove(comment.id)
                                        } else {
                                            expandedReplyParentIDs.insert(comment.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: repliesExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption2.weight(.bold))
                                        Text(repliesExpanded ? "Hide Replies" : "View Replies")
                                            .font(.caption.weight(.semibold))
                                        Text("\(replies.count)")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.08), in: Capsule())
                                    }
                                    .foregroundStyle(.white.opacity(0.78))
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                            .padding(.leading, 4)

                            if repliesExpanded {
                                VStack(spacing: 10) {
                                    ForEach(replies) { reply in
                                CommentRowCard(
                                    comment: reply,
                                    authorProfile: store.publicProfile(for: reply.userID),
                                    isReply: true,
                                    reactionTypes: store.reactionTypes,
                                    reactionCounts: store.commentReactionCounts(for: reply.id),
                                    selectedReactionTypeIDs: store.viewerCommentReactionTypeIDsByComment[reply.id] ?? [],
                                    reactionTotalOverride: store.commentReactionTotal(for: reply),
                                            onReact: { reactionTypeID in
                                                store.reactToComment(reply.id, reactionTypeId: reactionTypeID)
                                            },
                                            onReply: {
                                                replyingToRootCommentID = comment.id
                                            }
                                        )
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .padding(.leading, 18)
                            }
                        }
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
        VStack(alignment: .leading, spacing: 8) {
            if let authorProfile = store.publicProfile(for: post.authorID) {
                Text(authorDisplayName(for: authorProfile))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.78))
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
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func authorDisplayName(for profile: PublicProfile) -> String {
        if let displayName = profile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "u/\(profile.username)"
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

private struct CommentRowCard: View {
    let comment: Comment
    let authorProfile: PublicProfile?
    let isReply: Bool
    let reactionTypes: [ReactionType]
    let reactionCounts: [CommentReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let reactionTotalOverride: Int
    let onReact: (UUID) -> Void
    let onReply: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let authorText = authorDisplayName {
                    Text(authorText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Text(isReply ? "Reply" : "Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                if reactionTotalOverride > 0 {
                    Label("\(reactionTotalOverride)", systemImage: "face.smiling")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                if let hotScore = comment.hot_score, hotScore > 0 {
                    Label(String(format: "%.0f", hotScore), systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(compactRelativeTimestamp(comment.created_at))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(comment.body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .leading)

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
                                        .font(.caption2.weight(.semibold))
                                }
                                .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.74))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    (isSelected ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.04)),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected ? AppTheme.accent.opacity(0.4) : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        if reactionTotalOverride > 0 {
                            Text("Total \(reactionTotalOverride)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.48))
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if let onReply {
                Button {
                    onReply()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isReply ? 0.03 : 0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isReply ? 0.06 : 0.08), lineWidth: 1)
        }
    }

    private var authorDisplayName: String? {
        guard let authorProfile else { return nil }
        if let displayName = authorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "u/\(authorProfile.username)"
    }
}

private struct NotificationsInboxView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onOpenNotificationPost: @MainActor (AppNotification) -> Void
    @State private var selectedFilter: NotificationsFilter = .all

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(NotificationsFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if store.notificationsIsLoading && store.notifications.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading notifications…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let errorMessage = store.notificationsErrorMessage, store.notifications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications failed to load")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        store.loadNotifications()
                    }
                }
                .foregroundStyle(.red)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !store.notificationsIsLoading && store.notifications.isEmpty && store.notificationsErrorMessage == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No notifications yet")
                        .font(.headline)
                    Text("Comments and replies on your posts will show up here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !store.notificationsIsLoading && store.notificationsErrorMessage == nil {
                if filteredNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedFilter.emptyStateTitle)
                            .font(.headline)
                        Text(selectedFilter.emptyStateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(notificationSections) { section in
                        Section(section.title) {
                            ForEach(section.notifications) { notification in
                                Button {
                                    store.markNotificationRead(notification.id)
                                    if notification.postID != nil {
                                        dismiss()
                                        Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 250_000_000)
                                            onOpenNotificationPost(notification)
                                        }
                                    }
                                } label: {
                                    NotificationRow(
                                        notification: notification,
                                        actorProfile: store.notificationActorProfile(for: notification.actorUserID)
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .textCase(nil)
                        .listSectionSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if store.unreadNotificationsCount > 0 {
                    Button("Mark All Read") {
                        store.markAllNotificationsRead()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
        .refreshable {
            await store.refreshNotifications()
        }
        .task {
            if store.notifications.isEmpty && !store.notificationsIsLoading {
                store.loadNotifications()
            }
        }
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return store.notifications
        case .unread:
            return store.notifications.filter { !$0.isRead }
        }
    }

    private var notificationSections: [NotificationSection] {
        let calendar = Calendar.current
        let sorted = filteredNotifications.sorted { $0.createdAt > $1.createdAt }
        var today: [AppNotification] = []
        var yesterday: [AppNotification] = []
        var thisWeek: [AppNotification] = []
        var earlier: [AppNotification] = []

        for notification in sorted {
            let date = notification.createdAt
            if calendar.isDateInToday(date) {
                today.append(notification)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(notification)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
                thisWeek.append(notification)
            } else {
                earlier.append(notification)
            }
        }

        var sections: [NotificationSection] = []
        if !today.isEmpty {
            sections.append(NotificationSection(title: "Today", notifications: today))
        }
        if !yesterday.isEmpty {
            sections.append(NotificationSection(title: "Yesterday", notifications: yesterday))
        }
        if !thisWeek.isEmpty {
            sections.append(NotificationSection(title: "This Week", notifications: thisWeek))
        }
        if !earlier.isEmpty {
            sections.append(NotificationSection(title: "Earlier", notifications: earlier))
        }
        return sections
    }
}

private enum NotificationsFilter: String, CaseIterable, Identifiable {
    case all
    case unread

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .all:
            return "No notifications yet"
        case .unread:
            return "You're all caught up"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .all:
            return "Comments and replies on your posts will show up here."
        case .unread:
            return "Unread notifications will show up here when new activity arrives."
        }
    }
}

private struct NotificationSection: Identifiable {
    let id = UUID()
    let title: String
    let notifications: [AppNotification]
}

private struct NotificationRow: View {
    let notification: AppNotification
    let actorProfile: PublicProfile?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.white.opacity(0.16) : AppTheme.accent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(notification.titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(notification.isRead ? 0.78 : 0.95))
                    if !notification.isRead {
                        Text("NEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(compactRelativeTimestamp(notification.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text(notificationMessageText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(notification.isRead ? 0.03 : 0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(notification.isRead ? Color.white.opacity(0.06) : AppTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var notificationMessageText: String {
        if let actorProfile {
            let actorName = actorProfile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let actor = (actorName?.isEmpty == false ? actorName! : actorProfile.username)
            switch notification.type {
            case "comment_reply":
                return "\(actor) replied to your comment."
            case "post_comment":
                return "\(actor) commented on your post."
            default:
                return "\(actor) interacted with your content."
            }
        }
        return notification.bodyText
    }
}

private struct ReactionErrorToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }
}

private enum ComposerMediaKind: String {
    case image
    case video
}

private struct ComposerMediaAttachment {
    let url: URL
    let thumbnailURL: URL?
    let kind: ComposerMediaKind
}

private struct PostComposerView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onPostCreated: @MainActor () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedGameID: UUID?
    @State private var mediaURLText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = PostComposerService()

    var body: some View {
        Form {
            Section("Create Post") {
                TextField("Title (optional)", text: $title)

                TextField("What's happening?", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)

                Picker("Attach Game (optional)", selection: $selectedGameID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(availableGames) { game in
                        Text(store.isFollowingGame(game) ? "Following · \(game.title)" : game.title)
                            .tag(Optional(game.id))
                    }
                }
            }

            Section("Media (optional)") {
                TextField("Image or video URL", text: $mediaURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                if let mediaAttachment {
                    ComposerMediaPreview(attachment: mediaAttachment, height: 180)

                    Button("Remove Media") {
                        mediaURLText = ""
                    }
                    .foregroundStyle(.white.opacity(0.8))
                } else if let mediaValidationMessage {
                    Text(mediaValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        }
                        Text(isSaving ? "Posting..." : "Post")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving || !canSubmit)
            }
        }
        .navigationTitle("New Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
        }
    }

    private var canSubmit: Bool {
        !trimmedTitle.isEmpty || !trimmedBody.isEmpty || mediaAttachment != nil
    }

    private var availableGames: [Game] {
        store.socialGames.sorted { lhs, rhs in
            let lhsFollowing = store.isFollowingGame(lhs)
            let rhsFollowing = store.isFollowingGame(rhs)
            if lhsFollowing != rhsFollowing {
                return lhsFollowing && !rhsFollowing
            }
            if lhs.releaseDate == rhs.releaseDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.releaseDate < rhs.releaseDate
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedMediaURL: String {
        mediaURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mediaAttachment: ComposerMediaAttachment? {
        guard let url = normalizeMediaURL(trimmedMediaURL) else { return nil }
        guard let kind = inferMediaKind(url: url) else { return nil }
        let thumbnailURL = inferThumbnailURL(for: url, kind: kind)
        return ComposerMediaAttachment(url: url, thumbnailURL: thumbnailURL, kind: kind)
    }

    private var mediaValidationMessage: String? {
        guard !trimmedMediaURL.isEmpty else { return nil }
        return mediaAttachment == nil ? "Enter a valid image or video URL." : nil
    }

    private func save() {
        guard let session = authManager.session else {
            errorMessage = "You need to sign in before posting."
            return
        }

        guard canSubmit else { return }
        if !trimmedMediaURL.isEmpty, mediaAttachment == nil {
            errorMessage = "Please enter a valid image or video URL."
            return
        }

        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }

            do {
                try await service.createPost(
                    session: session,
                    linkedGame: availableGames.first(where: { $0.id == selectedGameID }),
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    body: trimmedBody.isEmpty ? nil : trimmedBody,
                    mediaAttachment: mediaAttachment
                )
                onPostCreated()
                dismiss()
            } catch {
                errorMessage = service.friendlyMessage(for: error)
            }
        }
    }

    private func normalizeMediaURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }

    private func inferMediaKind(url: URL) -> ComposerMediaKind? {
        if YouTubeIDParser.videoID(from: url) != nil {
            return .video
        }
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "webm"].contains(ext) {
            return .video
        }
        if ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"].contains(ext) {
            return .image
        }
        return nil
    }

    private func inferThumbnailURL(for url: URL, kind: ComposerMediaKind) -> URL? {
        if kind == .video, let id = YouTubeIDParser.videoID(from: url) {
            return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
        }
        if kind == .image {
            return url
        }
        return nil
    }
}

private struct ComposerMediaPreview: View {
    let attachment: ComposerMediaAttachment
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(height: height)

            switch attachment.kind {
            case .image:
                RemoteMediaImage(primaryURL: attachment.url, fallbackURL: MediaFallback.gameScreenshot)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .video:
                let previewURL = attachment.thumbnailURL ?? attachment.url
                RemoteMediaImage(primaryURL: previewURL, fallbackURL: MediaFallback.videoThumbnail)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: height * 0.3, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                    }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct PostComposerService {
    private struct NewPostInsert: Encodable {
        let author_id: UUID
        let game_id: UUID?
        let type: String
        let title: String?
        let body: String?
        let media_url: String?
        let thumbnail_url: String?
        let is_system_generated: Bool
    }

    private let feedService = FeedService()

    func createPost(
        session: Session,
        linkedGame: Game?,
        title: String?,
        body: String?,
        mediaAttachment: ComposerMediaAttachment?
    ) async throws {
        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            throw NSError(
                domain: "PatchNotes.PostComposer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Your session is missing an access token. Please sign out and sign in again."]
            )
        }

        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        if let linkedGame {
            try await feedService.ensureGameExists(linkedGame, accessToken: accessToken)
        }

        let resolvedMediaURL = mediaAttachment?.url.absoluteString
        let resolvedThumbnailURL = mediaAttachment?.thumbnailURL?.absoluteString
        let resolvedType = mediaAttachment?.kind.rawValue ?? "text"

        try await client
            .from("posts")
            .insert(
                NewPostInsert(
                    author_id: session.user.id,
                    game_id: linkedGame?.id,
                    type: resolvedType,
                    title: title,
                    body: body,
                    media_url: resolvedMediaURL,
                    thumbnail_url: resolvedThumbnailURL,
                    is_system_generated: false
                )
            )
            .execute()
    }

    func friendlyMessage(for error: Error) -> String {
        let message = [error.localizedDescription, String(describing: error)]
            .joined(separator: " | ")
            .lowercased()

        if message.contains("42501") || message.contains("row-level security") {
            return "Your account does not have permission to create posts yet."
        }

        if message.contains("users can insert posts") || message.contains("author_id") {
            return "Post creation failed because the author ID was rejected."
        }

        return error.localizedDescription
    }

}
