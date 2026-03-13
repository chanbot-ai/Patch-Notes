import SwiftUI
import Foundation

func compactRelativeTimestamp(_ date: Date, now: Date = Date()) -> String {
    let delta = max(Int(now.timeIntervalSince(date)), 0)
    if delta < 60 { return "now" }
    if delta < 3_600 { return "\(delta / 60)m" }
    if delta < 86_400 { return "\(delta / 3_600)h" }
    if delta < 604_800 { return "\(delta / 86_400)d" }
    if delta < 2_592_000 { return "\(delta / 604_800)w" }
    if delta < 31_536_000 { return "\(delta / 2_592_000)mo" }
    return "\(delta / 31_536_000)y"
}

private enum FeedFilter: Hashable {
    case forYou
    case game(Game.ID)
}

struct FeedView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var settings: AppSettings

    @State private var showingComposer = false
    @State private var showingNotifications = false
    @State private var showProfileDrawer = false
    @State private var selectedCommentsPost: Post?
    @State private var highlightCommentID: UUID?
    @State private var feedFilter: FeedFilter = .forYou

    // MARK: - Active Feed Computed Properties

    private var activePosts: [Post] {
        switch feedFilter {
        case .forYou:
            // Fall back to hot feed when user follows no games
            return store.followedGameIDs.isEmpty ? store.posts : store.followingPosts
        case .game(let gameID):
            return store.gameFeedPostsByGameID[gameID] ?? []
        }
    }

    private var activeFeedIsLoading: Bool {
        switch feedFilter {
        case .forYou:
            return store.followedGameIDs.isEmpty ? store.feedIsLoading : store.followingFeedIsLoading
        case .game(let gameID):
            return store.gameFeedIsLoadingByGameID[gameID] ?? false
        }
    }

    private var activeFeedErrorMessage: String? {
        switch feedFilter {
        case .forYou:
            return store.followedGameIDs.isEmpty ? store.feedErrorMessage : store.followingFeedErrorMessage
        case .game(let gameID):
            return store.gameFeedErrorByGameID[gameID]
        }
    }

    private var activeFeedHasMore: Bool {
        switch feedFilter {
        case .forYou:
            return store.followedGameIDs.isEmpty ? store.hotFeedHasMore : store.followingFeedHasMore
        case .game(let gameID):
            return store.gameFeedHasMoreByGameID[gameID] ?? true
        }
    }

    private var activeFeedIsLoadingMore: Bool {
        switch feedFilter {
        case .forYou:
            return store.followedGameIDs.isEmpty ? store.hotFeedIsLoadingMore : store.followingFeedIsLoadingMore
        case .game(let gameID):
            return store.gameFeedIsLoadingMoreByGameID[gameID] ?? false
        }
    }

    private var activeGameTitle: String? {
        if case .game(let gameID) = feedFilter {
            return store.game(for: gameID)?.title
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title card
                feedTitleCard

                // Game channel icons (Sleeper-style)
                gameChannelBar

                // Feed content
                if activeFeedIsLoading && activePosts.isEmpty {
                    GlassCard {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Loading feed...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }

                if let errorMessage = activeFeedErrorMessage {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Feed Error")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(errorMessage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .textSelection(.enabled)
                        }
                    }
                }

                if !activeFeedIsLoading && activePosts.isEmpty && activeFeedErrorMessage == nil {
                    emptyStateView
                }

                LazyVStack(spacing: 14) {
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
                            onOpenPostDetail: {
                                selectedCommentsPost = post
                            },
                            onOpenComments: {
                                selectedCommentsPost = post
                            },
                            onGameTap: { gameID in
                                feedFilter = .game(gameID)
                            },
                            showJoinButton: store.followedGameIDs.isEmpty,
                            isGameFollowed: {
                                guard let gameID = post.gameID else { return true }
                                return store.followedGameIDs.contains(gameID)
                            }(),
                            onJoinGame: {
                                guard let gameID = post.gameID else { return }
                                store.followGameByID(gameID)
                            }
                        )
                        .onAppear {
                            if shouldLoadMore(for: post) {
                                loadMoreForActiveScope()
                            }
                        }
                    }
                }

                if activeFeedIsLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 16)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 14) {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showProfileDrawer = true
                    }
                } label: {
                    Text(store.currentUserAvatarEmoji)
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")

                Spacer(minLength: 0)

                circleFeedActionButton(
                    systemImage: "bell",
                    accessibilityLabel: store.unreadNotificationsCount > 0
                    ? "Notifications, \(store.unreadNotificationsCount) unread"
                    : "Notifications",
                    badgeCount: store.unreadNotificationsCount
                ) {
                    showingNotifications = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .background(Color.clear)
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                PostComposerView {
                    store.loadHotFeed()
                    store.loadFollowingFeed()
                }
                .environmentObject(authManager)
                .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCommentsPost) { post in
            NavigationStack {
                PostCommentsDetailView(post: post, highlightCommentID: highlightCommentID)
                    .environmentObject(store)
                    .onDisappear { highlightCommentID = nil }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            if showProfileDrawer {
                ProfileDrawerView(isPresented: $showProfileDrawer)
                    .environmentObject(store)
                    .environmentObject(authManager)
                    .environmentObject(settings)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationStack {
                NotificationsInboxView { notification in
                    showingNotifications = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard let post = await store.resolveNotificationPost(notification) else { return }
                        highlightCommentID = notification.commentID
                        selectedCommentsPost = post
                    }
                }
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .refreshable {
            switch feedFilter {
            case .forYou:
                await store.refreshFollowingFeed()
            case .game(let gameID):
                await store.refreshGameFeed(for: gameID)
            }
        }
        .onChange(of: feedFilter) { _, newValue in
            switch newValue {
            case .forYou:
                // Reload if we have no cached posts
                if store.followingPosts.isEmpty && !store.followingFeedIsLoading {
                    store.loadFollowingFeed()
                }
            case .game(let gameID):
                if store.gameFeedPostsByGameID[gameID] == nil {
                    store.loadGameFeed(for: gameID)
                }
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
        .task {
            // Ensure followed games are loaded for pill bar (fixes Prompts 3/4/5)
            if store.followedGameIDs.isEmpty && !store.followedGamesIsLoading {
                store.loadFollowedGames()
            }
            if store.followingPosts.isEmpty && !store.followingFeedIsLoading {
                store.loadFollowingFeed()
            }
        }
    }

    // MARK: - Title Card

    private var feedTitleCard: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "newspaper.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Text("My Patch Notes")
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Game Channel Bar (Sleeper-style)

    private var gameChannelBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.followedGamesForPillBar) { game in
                    let isSelected = feedFilter == .game(game.id)
                    VStack(spacing: 6) {
                        RemoteMediaImage(
                            primaryURL: game.coverImageURL,
                            fallbackURL: MediaFallback.gameCover
                        )
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? AppTheme.accent.opacity(0.8)
                                        : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        }
                        .shadow(
                            color: isSelected ? AppTheme.accent.opacity(0.35) : .clear,
                            radius: 6, y: 2
                        )

                        Text(game.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                            .lineLimit(1)
                            .frame(width: 88)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelected {
                            feedFilter = .forYou
                        } else {
                            feedFilter = .game(game.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Empty State

    private var activeGameID: Game.ID? {
        if case .game(let gameID) = feedFilter { return gameID }
        return nil
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if case .game(let gameID) = feedFilter {
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.accent.opacity(0.6))

                    VStack(spacing: 6) {
                        Text("Nothing here yet")
                            .font(.headline.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)

                        if let healthMessage = store.communityHealth(for: gameID)?.quiet_message {
                            Text(healthMessage)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("When news drops for \(activeGameTitle ?? "this game"), it'll show up here and in your home feed since you follow this community.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            store.loadGameFeed(for: gameID)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            feedFilter = .forYou
                        } label: {
                            Text("Back to For You")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.accent.opacity(0.28), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .onAppear {
                store.refreshGameCommunityHealth(for: gameID)
            }
        } else {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your feed is empty")
                        .font(.headline.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                    Text("Follow some games to see posts in your feed.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))

                    HStack(spacing: 10) {
                        NavigationLink {
                            ReleaseCalendarView()
                        } label: {
                            Text("Browse Calendar")
                                .font(.caption.weight(.bold))
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
                                .font(.caption.weight(.bold))
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
    }

    // MARK: - Helpers

    private func shouldLoadMore(for post: Post) -> Bool {
        guard activeFeedHasMore, !activeFeedIsLoadingMore else { return false }
        let posts = activePosts
        guard posts.count >= 5 else { return false }
        return post.id == posts[posts.count - 5].id
    }

    private func loadMoreForActiveScope() {
        switch feedFilter {
        case .forYou:
            store.loadMoreFollowingFeed()
        case .game(let gameID):
            store.loadMoreGameFeed(for: gameID)
        }
    }

    @ViewBuilder
    private func circleFeedActionButton(
        systemImage: String,
        accessibilityLabel: String,
        badgeCount: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }

                if let badgeCount, badgeCount > 0 {
                    Text("\(min(badgeCount, 99))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent, in: Capsule())
                        .offset(x: 8, y: -6)
                }
            }
            .frame(width: 48, height: 48, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ReactionErrorToast: View {
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

// MARK: - Previews

#if DEBUG
#Preview("FeedView - Populated") {
    let post1 = PreviewHelpers.makePost(title: "Marathon season 1 details leaked", reactionCount: 44, hotScore: 88.0)
    let post2 = PreviewHelpers.makeImagePost()
    let post3 = PreviewHelpers.makeLinkPost()
    let reactions = PreviewHelpers.makeReactionTypes()
    let store = AppStore()
    store.seedPreviewState(AppPreviewState(
        posts: [post1, post2, post3],
        reactionTypes: reactions,
        reactionCountsByPost: [
            post1.id: PreviewHelpers.makeReactionCounts(postID: post1.id, fireCount: 40, hypeCount: 4),
            post2.id: [],
            post3.id: []
        ],
        reactionTotalsByPost: [post1.id: 44, post2.id: 0, post3.id: 0]
    ))
    let authManager = AuthManager()
    return NavigationStack {
        FeedView()
            .environmentObject(store)
            .environmentObject(authManager)
    }
    .preferredColorScheme(.dark)
}

#Preview("FeedView - Loading") {
    let store = AppStore()
    store.seedPreviewState(AppPreviewState(feedIsLoading: true))
    let authManager = AuthManager()
    return NavigationStack {
        FeedView()
            .environmentObject(store)
            .environmentObject(authManager)
    }
    .preferredColorScheme(.dark)
}

#Preview("FeedView - Empty") {
    let store = AppStore()
    let authManager = AuthManager()
    return NavigationStack {
        FeedView()
            .environmentObject(store)
            .environmentObject(authManager)
    }
    .preferredColorScheme(.dark)
}
#endif
