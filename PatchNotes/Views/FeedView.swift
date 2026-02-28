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

    private var activeFeedHasMore: Bool {
        switch feedScope {
        case .hot: return store.hotFeedHasMore
        case .following: return store.followingFeedHasMore
        }
    }

    private var activeFeedIsLoadingMore: Bool {
        switch feedScope {
        case .hot: return store.hotFeedIsLoadingMore
        case .following: return store.followingFeedIsLoadingMore
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
                    badgeGame: store.game(for: post.primaryBadgeGameID ?? post.gameID),
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
                    }
                )
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onAppear {
                        if shouldLoadMore(for: post) {
                            loadMoreForActiveScope()
                        }
                    }
            }

            if activeFeedIsLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 16)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Feed")
        .safeAreaInset(edge: .top) {
            HStack(spacing: 14) {
                circleFeedActionButton(
                    systemImage: "square.and.pencil",
                    accessibilityLabel: "Create post",
                    badgeCount: nil
                ) {
                    showingComposer = true
                }

                circleFeedActionButton(
                    systemImage: "bell",
                    accessibilityLabel: store.unreadNotificationsCount > 0
                    ? "Notifications, \(store.unreadNotificationsCount) unread"
                    : "Notifications",
                    badgeCount: store.unreadNotificationsCount
                ) {
                    showingNotifications = true
                }

                Spacer(minLength: 0)
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

    private func shouldLoadMore(for post: Post) -> Bool {
        guard activeFeedHasMore, !activeFeedIsLoadingMore else { return false }
        let posts = activePosts
        guard posts.count >= 5 else { return false }
        return post.id == posts[posts.count - 5].id
    }

    private func loadMoreForActiveScope() {
        switch feedScope {
        case .hot: store.loadMoreHotFeed()
        case .following: store.loadMoreFollowingFeed()
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
