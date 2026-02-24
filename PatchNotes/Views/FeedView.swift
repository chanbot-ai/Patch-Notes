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
                }
            }

            ForEach(activePosts) { post in
                FeedPostRow(
                    post: post,
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
                    Label("Post", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("Create post")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                        if store.unreadNotificationsCount > 0 {
                            Text("\(min(store.unreadNotificationsCount, 99))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent, in: Capsule())
                                .offset(x: 10, y: -8)
                        }
                    }
                }
                .accessibilityLabel(store.unreadNotificationsCount > 0 ? "Notifications, \(store.unreadNotificationsCount) unread" : "Notifications")
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
                NotificationsInboxView()
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
    let reactionCountOverride: Int
    let reactionTypes: [ReactionType]
    let reactionCounts: [PostReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void
    let onOpenComments: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                Text(post.created_at, style: .relative)
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
        comments.filter { $0.parentCommentID == nil }
    }

    private var repliesByParent: [UUID: [Comment]] {
        Dictionary(
            grouping: comments.filter { $0.parentCommentID != nil },
            by: { $0.parentCommentID! }
        )
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

                if store.commentHasMoreByPost[post.id] == true {
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
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
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
                Text(comment.created_at, style: .relative)
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
}

private struct NotificationsInboxView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
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

            ForEach(store.notifications) { notification in
                Button {
                    store.markNotificationRead(notification.id)
                } label: {
                    NotificationRow(notification: notification)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
}

private struct NotificationRow: View {
    let notification: AppNotification

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
                    Text(notification.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Text(notification.bodyText)
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

private struct PostComposerView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onPostCreated: @MainActor () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedGameID: UUID?
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
                        Text(game.title).tag(Optional(game.id))
                    }
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
        !trimmedTitle.isEmpty || !trimmedBody.isEmpty
    }

    private var availableGames: [Game] {
        store.socialGames.sorted { lhs, rhs in
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

    private func save() {
        guard let session = authManager.session else {
            errorMessage = "You need to sign in before posting."
            return
        }

        guard canSubmit else { return }

        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }

            do {
                try await service.createTextPost(
                    session: session,
                    linkedGame: availableGames.first(where: { $0.id == selectedGameID }),
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    body: trimmedBody.isEmpty ? nil : trimmedBody
                )
                onPostCreated()
                dismiss()
            } catch {
                errorMessage = service.friendlyMessage(for: error)
            }
        }
    }
}

private struct PostComposerService {
    private struct NewPostInsert: Encodable {
        let author_id: UUID
        let game_id: UUID?
        let type: String
        let title: String?
        let body: String?
        let is_system_generated: Bool
    }

    private let feedService = FeedService()

    func createTextPost(
        session: Session,
        linkedGame: Game?,
        title: String?,
        body: String?
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

        try await client
            .from("posts")
            .insert(
                NewPostInsert(
                    author_id: session.user.id,
                    game_id: linkedGame?.id,
                    type: "text",
                    title: title,
                    body: body,
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
