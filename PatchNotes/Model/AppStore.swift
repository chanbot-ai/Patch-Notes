import Foundation
import SwiftUI
import Supabase

protocol AppDataProviding {
    func makeSeedData(referenceDate: Date) -> AppSeedData
}

struct MockAppDataProvider: AppDataProviding {
    func makeSeedData(referenceDate: Date) -> AppSeedData {
        AppSeedData(referenceDate: referenceDate)
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var posts: [Post]
    @Published private(set) var reactionTypes: [ReactionType]
    @Published private(set) var reactionCountsByPost: [UUID: [PostReactionCount]]
    @Published private(set) var viewerReactionTypeIDsByPost: [UUID: Set<UUID>]
    @Published private(set) var reactionTotalsByPost: [UUID: Int]
    @Published private(set) var reactionErrorMessage: String?
    @Published private(set) var commentsByPost: [UUID: [Comment]]
    @Published private(set) var commentIsLoadingByPost: Set<UUID>
    @Published private(set) var commentLoadErrorByPost: [UUID: String]
    @Published private(set) var commentHasMoreByPost: [UUID: Bool]
    @Published private(set) var commentSortByPost: [UUID: CommentSortMode]
    @Published private(set) var commentReactionCountsByComment: [UUID: [CommentReactionCount]]
    @Published private(set) var viewerCommentReactionTypeIDsByComment: [UUID: Set<UUID>]
    @Published private(set) var notifications: [AppNotification]
    @Published private(set) var notificationActorProfilesByID: [UUID: PublicProfile]
    @Published private(set) var publicProfilesByID: [UUID: PublicProfile]
    @Published private(set) var notificationsIsLoading: Bool
    @Published private(set) var notificationsErrorMessage: String?
    @Published private(set) var followedGameIDs: Set<Game.ID>
    @Published private(set) var followedGamesIsLoading: Bool
    @Published private(set) var followedGamesErrorMessage: String?
    @Published private(set) var feedIsLoading: Bool
    @Published private(set) var feedErrorMessage: String?
    @Published private(set) var followingPosts: [Post]
    @Published private(set) var followingFeedIsLoading: Bool
    @Published private(set) var followingFeedErrorMessage: String?
    @Published private(set) var gameCatalogByID: [Game.ID: Game]
    @Published private(set) var ownedGames: [Game]
    @Published private(set) var upcomingReleases: [Game]
    @Published private(set) var favoriteReleaseIDs: Set<Game.ID>
    @Published private(set) var newsFeed: [NewsItem]
    @Published private(set) var shortVideos: [ShortVideo]
    @Published private(set) var esportsMatches: [EsportsMatch]
    @Published private(set) var esportsMarkets: [EsportsMarket]
    @Published private(set) var leagueStandings: [String: [LeagueStanding]]
    @Published private(set) var favoriteTeams: Set<String>
    @Published private(set) var isLoadingEsports: Bool

    private var threadsByGame: [Game.ID: [ThreadPost]]
    private let calendar = Calendar.current
    private let dataProvider: AppDataProviding
    private let feedService = FeedService()
    private let publicProfileService = PublicProfileService()
    private var hasSubscribed = false
    private var authenticatedSession: Session?
    private var reactionErrorDismissTask: Task<Void, Never>?
    private var hasSubscribedToCommentMetrics = false
    private var hasSubscribedToNotifications = false
    private var commentOffsetsByPost: [UUID: Int]
    private let commentPageSize = 20
    private let maxCachedCommentsPerPost = 100
    private var inFlightPostRefreshIDs: Set<UUID>
    private var inFlightPostReactionKeys: Set<String>
    private var inFlightCommentReactionKeys: Set<String>
    private var pendingCommentRealtimePostIDs: Set<UUID>
    private var pendingCommentRealtimeRefreshTask: Task<Void, Never>?
    private var pendingNotificationsRefreshTask: Task<Void, Never>?
    private var pendingFollowingFeedRealtimeRefreshTask: Task<Void, Never>?
    private var inFlightFollowToggleGameIDs: Set<Game.ID>
    private var hasLoadedFollowingFeedOnce: Bool

    init(
        dataProvider: AppDataProviding = MockAppDataProvider(),
        referenceDate: Date = Date()
    ) {
        self.dataProvider = dataProvider
        self.posts = []
        self.reactionTypes = []
        self.reactionCountsByPost = [:]
        self.viewerReactionTypeIDsByPost = [:]
        self.reactionTotalsByPost = [:]
        self.reactionErrorMessage = nil
        self.commentsByPost = [:]
        self.commentIsLoadingByPost = []
        self.commentLoadErrorByPost = [:]
        self.commentHasMoreByPost = [:]
        self.commentSortByPost = [:]
        self.commentReactionCountsByComment = [:]
        self.viewerCommentReactionTypeIDsByComment = [:]
        self.notifications = []
        self.notificationActorProfilesByID = [:]
        self.publicProfilesByID = [:]
        self.notificationsIsLoading = false
        self.notificationsErrorMessage = nil
        self.followedGameIDs = []
        self.followedGamesIsLoading = false
        self.followedGamesErrorMessage = nil
        self.feedIsLoading = false
        self.feedErrorMessage = nil
        self.followingPosts = []
        self.followingFeedIsLoading = false
        self.followingFeedErrorMessage = nil
        self.gameCatalogByID = [:]
        self.ownedGames = []
        self.upcomingReleases = []
        self.favoriteReleaseIDs = []
        self.newsFeed = []
        self.shortVideos = []
        self.esportsMatches = []
        self.esportsMarkets = []
        self.leagueStandings = [:]
        let storedFavorites = UserDefaults.standard.stringArray(forKey: "pn.esports.favoriteTeams") ?? []
        self.favoriteTeams = Set(storedFavorites)
        self.isLoadingEsports = false
        self.threadsByGame = [:]
        self.commentOffsetsByPost = [:]
        self.inFlightPostRefreshIDs = []
        self.inFlightPostReactionKeys = []
        self.inFlightCommentReactionKeys = []
        self.pendingCommentRealtimePostIDs = []
        self.inFlightFollowToggleGameIDs = []
        self.hasLoadedFollowingFeedOnce = false
        refresh(referenceDate: referenceDate)
        configureFeedOwnership()
    }

    var favoritedReleases: [Game] {
        upcomingReleases
            .filter { favoriteReleaseIDs.contains($0.id) }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    var socialGames: [Game] {
        var seen = Set<Game.ID>()
        let candidates = ownedGames + favoritedReleases + Array(upcomingReleases.prefix(6))
        return candidates.filter { game in
            seen.insert(game.id).inserted
        }
    }

    func game(for gameID: Game.ID?) -> Game? {
        guard let gameID else { return nil }
        if let game = gameCatalogByID[gameID] {
            return game
        }
        return socialGames.first(where: { $0.id == gameID })
    }

    func toggleFavorite(_ game: Game) {
        if favoriteReleaseIDs.contains(game.id) {
            favoriteReleaseIDs.remove(game.id)
        } else {
            favoriteReleaseIDs.insert(game.id)
        }
    }

    func isFavorite(_ game: Game) -> Bool {
        favoriteReleaseIDs.contains(game.id)
    }

    func toggleFavoriteTeam(_ team: String) {
        if favoriteTeams.contains(team) {
            favoriteTeams.remove(team)
        } else {
            favoriteTeams.insert(team)
        }
        UserDefaults.standard.set(Array(favoriteTeams), forKey: "pn.esports.favoriteTeams")
    }

    func isFavoriteTeam(_ team: String) -> Bool {
        favoriteTeams.contains(team)
    }
    
    func isFollowingGame(_ game: Game) -> Bool {
        followedGameIDs.contains(game.id)
    }

    func toggleFollowedGame(_ game: Game) {
        guard let session = authenticatedSession else {
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else { return }
        guard !inFlightFollowToggleGameIDs.contains(game.id) else { return }

        let userID = session.user.id
        let wasFollowing = followedGameIDs.contains(game.id)
        let previous = followedGameIDs

        inFlightFollowToggleGameIDs.insert(game.id)
        if wasFollowing {
            var next = followedGameIDs
            next.remove(game.id)
            followedGameIDs = next
        } else {
            var next = followedGameIDs
            next.insert(game.id)
            followedGameIDs = next
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlightFollowToggleGameIDs.remove(game.id) }
            do {
                if wasFollowing {
                    try await self.feedService.unfollowGame(
                        gameID: game.id,
                        userID: userID,
                        accessToken: accessToken
                    )
                } else {
                    try await self.feedService.followGame(
                        game,
                        userID: userID,
                        accessToken: accessToken
                    )
                }
                self.followedGamesErrorMessage = nil
                await self.refreshFollowingFeed()
            } catch {
                self.followedGameIDs = previous
                self.followedGamesErrorMessage = error.localizedDescription
                print("Failed to toggle followed game:", error)
            }
        }
    }

    func releases(forMonthContaining date: Date) -> [Game] {
        upcomingReleases
            .filter {
                calendar.isDate($0.releaseDate, equalTo: date, toGranularity: .month) &&
                calendar.isDate($0.releaseDate, equalTo: date, toGranularity: .year)
            }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    func releases(onDay date: Date) -> [Game] {
        upcomingReleases
            .filter { calendar.isDate($0.releaseDate, inSameDayAs: date) }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    func socialThreads(for gameID: Game.ID?) -> [ThreadPost] {
        guard let gameID else { return [] }
        return (threadsByGame[gameID] ?? [])
            .sorted { lhs, rhs in
                if lhs.hotScore == rhs.hotScore {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.hotScore > rhs.hotScore
            }
    }

    func videos(for game: Game) -> [ShortVideo] {
        shortVideos
            .filter { clip in
                clip.relatedGameTitles.contains(where: { $0.caseInsensitiveCompare(game.title) == .orderedSame })
            }
            .prefix(6)
            .map { $0 }
    }

    func refresh(referenceDate: Date = Date()) {
        let seed = dataProvider.makeSeedData(referenceDate: referenceDate)
        ownedGames = seed.ownedGames
        upcomingReleases = seed.upcomingReleases
        newsFeed = seed.newsFeed
        shortVideos = seed.shortVideos
        esportsMatches = seed.esportsMatches
        esportsMarkets = seed.esportsMarkets
        leagueStandings = seed.leagueStandings
        threadsByGame = seed.threadsByGame

        let defaultFavorites = Set(seed.defaultFavoriteIDs)
        if favoriteReleaseIDs.isEmpty {
            favoriteReleaseIDs = defaultFavorites
        } else {
            favoriteReleaseIDs = favoriteReleaseIDs
                .intersection(Set(upcomingReleases.map(\.id)))
        }
    }

    func startHotFeed() {
        loadReactionTypes()
        subscribeToFeedRealtime()
        subscribeToCommentMetricsRealtime()
        subscribeToNotificationsRealtime()
        if posts.isEmpty && !feedIsLoading {
            loadHotFeed()
        }
        if authenticatedSession != nil, notifications.isEmpty && !notificationsIsLoading {
            loadNotifications()
        }
        if authenticatedSession != nil, followedGameIDs.isEmpty && !followedGamesIsLoading {
            loadFollowedGames()
        }
    }

    func setAuthenticatedSession(_ session: Session?) {
        let previousUserID = authenticatedSession?.user.id
        let previousAccessToken = authenticatedSession?.accessToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
        authenticatedSession = session
        let newUserID = session?.user.id
        let newAccessToken = session?.accessToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let didRotateAccessToken = previousUserID == newUserID && previousAccessToken != newAccessToken

        if previousUserID != newUserID || didRotateAccessToken {
            hasSubscribedToNotifications = false
            feedService.resetNotificationsSubscription()
        }

        if previousUserID != newUserID {
            pendingNotificationsRefreshTask?.cancel()
            pendingNotificationsRefreshTask = nil
            notifications = []
            notificationActorProfilesByID = [:]
            notificationsErrorMessage = nil
            notificationsIsLoading = false
            followedGameIDs = []
            followedGamesErrorMessage = nil
            followedGamesIsLoading = false
            hasLoadedFollowingFeedOnce = false
        }

        if didRotateAccessToken,
           newUserID != nil,
           notificationsErrorMessage != nil {
            loadNotifications()
        }

        if session == nil {
            viewerReactionTypeIDsByPost = [:]
            viewerCommentReactionTypeIDsByComment = [:]
            commentReactionCountsByComment = [:]
            commentsByPost = [:]
            commentIsLoadingByPost = []
            commentLoadErrorByPost = [:]
            commentHasMoreByPost = [:]
            commentSortByPost = [:]
            commentOffsetsByPost = [:]
            reactionErrorMessage = nil
            followingPosts = []
            followingFeedErrorMessage = nil
            inFlightPostReactionKeys = []
            inFlightCommentReactionKeys = []
            inFlightPostRefreshIDs = []
            inFlightFollowToggleGameIDs = []
            pendingCommentRealtimePostIDs = []
            pendingCommentRealtimeRefreshTask?.cancel()
            pendingCommentRealtimeRefreshTask = nil
            pendingNotificationsRefreshTask?.cancel()
            pendingNotificationsRefreshTask = nil
            pendingFollowingFeedRealtimeRefreshTask?.cancel()
            pendingFollowingFeedRealtimeRefreshTask = nil
            hasLoadedFollowingFeedOnce = false
        }
    }

    func loadReactionTypes() {
        Task {
            await refreshReactionTypes()
        }
    }

    func loadHotFeed() {
        Task {
            await refreshHotFeed()
        }
    }

    func loadFollowingFeed() {
        Task {
            await refreshFollowingFeed()
        }
    }

    func loadNotifications() {
        Task {
            await refreshNotifications()
        }
    }

    func loadFollowedGames() {
        Task {
            await refreshFollowedGames()
        }
    }

    func loadInitialComments(for postId: UUID) {
        commentOffsetsByPost[postId] = 0
        var nextComments = commentsByPost
        nextComments[postId] = []
        commentsByPost = nextComments

        var nextHasMore = commentHasMoreByPost
        nextHasMore[postId] = true
        commentHasMoreByPost = nextHasMore

        loadMoreComments(for: postId)
    }

    func ensureCommentsLoaded(for postId: UUID) {
        if commentsByPost[postId] == nil {
            loadInitialComments(for: postId)
        }
    }

    func commentSortMode(for postId: UUID) -> CommentSortMode {
        commentSortByPost[postId] ?? .top
    }

    func setCommentSort(_ sort: CommentSortMode, for postId: UUID) {
        let current = commentSortByPost[postId] ?? .top
        guard current != sort else { return }
        var nextSort = commentSortByPost
        nextSort[postId] = sort
        commentSortByPost = nextSort
        loadInitialComments(for: postId)
    }

    func loadMoreComments(for postId: UUID) {
        guard !commentIsLoadingByPost.contains(postId) else { return }
        if let hasMore = commentHasMoreByPost[postId], !hasMore { return }

        let offset = commentOffsetsByPost[postId] ?? 0
        Task {
            await fetchCommentsPage(for: postId, offset: offset, replaceExisting: offset == 0)
        }
    }

    func addComment(to postId: UUID, body: String, parentId: UUID? = nil) {
        let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard let session = authenticatedSession else {
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            return
        }

        let userId = session.user.id
        let normalizedParentId: UUID?
        if let parentId,
           let parent = commentsByPost[postId]?.first(where: { $0.id == parentId }),
           let rootParentId = parent.parentCommentID {
            normalizedParentId = rootParentId
        } else {
            normalizedParentId = parentId
        }

        let tempComment = Comment(
            id: UUID(),
            post_id: postId,
            user_id: userId,
            body: cleaned,
            parent_comment_id: normalizedParentId,
            created_at: Date(),
            reaction_count: 0,
            hot_score: 0,
            author_username: nil,
            author_display_name: nil,
            author_avatar_url: nil,
            author_created_at: nil
        )

        applyOptimisticCommentInsert(tempComment)
        Task { @MainActor [weak self] in
            await self?.refreshPublicProfiles(for: [userId])
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.feedService.insertComment(
                    postId: postId,
                    body: cleaned,
                    parentCommentId: normalizedParentId,
                    userId: userId,
                    accessToken: accessToken
                )
                // Realtime on post_metrics.comment_count will reconcile the full comment list.
            } catch {
                self.removeOptimisticComment(tempComment)
                print("Comment insert failed:", error)
            }
        }
    }

    func commentReactionCounts(for commentId: UUID) -> [CommentReactionCount] {
        commentReactionCountsByComment[commentId] ?? []
    }

    func commentReactionCount(for commentId: UUID, reactionTypeId: UUID) -> Int {
        commentReactionCountsByComment[commentId]?
            .first(where: { $0.reactionTypeID == reactionTypeId })?
            .count ?? 0
    }

    func commentReactionTotal(for comment: Comment) -> Int {
        if let counts = commentReactionCountsByComment[comment.id] {
            return counts.reduce(0) { $0 + $1.count }
        }
        return comment.reaction_count ?? 0
    }

    func hasReactedToComment(_ commentId: UUID, reactionTypeId: UUID) -> Bool {
        viewerCommentReactionTypeIDsByComment[commentId, default: []].contains(reactionTypeId)
    }

    func reactToComment(_ commentId: UUID, reactionTypeId: UUID) {
        guard let session = authenticatedSession else {
            showReactionError("Sign in again to add reactions.")
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            showReactionError("Your session expired. Sign in again to react.")
            return
        }

        guard let postId = postID(containingCommentID: commentId) else {
            return
        }

        let operationKey = "\(commentId.uuidString)|\(reactionTypeId.uuidString)"
        guard !inFlightCommentReactionKeys.contains(operationKey) else { return }
        inFlightCommentReactionKeys.insert(operationKey)

        let userId = session.user.id
        let currentlySelected = viewerCommentReactionTypeIDsByComment[commentId, default: []].contains(reactionTypeId)
        let previousCounts = commentReactionCountsByComment[commentId] ?? []
        let previousSelected = viewerCommentReactionTypeIDsByComment[commentId] ?? []

        applyOptimisticCommentReactionMutation(
            commentId: commentId,
            reactionTypeId: reactionTypeId,
            isRemoving: currentlySelected
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlightCommentReactionKeys.remove(operationKey) }
            do {
                if currentlySelected {
                    try await self.feedService.removeCommentReaction(
                        commentId: commentId,
                        reactionTypeId: reactionTypeId,
                        userId: userId,
                        accessToken: accessToken
                    )
                } else {
                    try await self.feedService.addCommentReaction(
                        commentId: commentId,
                        reactionTypeId: reactionTypeId,
                        userId: userId,
                        accessToken: accessToken
                    )
                }
                clearReactionError()
            } catch {
                var nextCounts = self.commentReactionCountsByComment
                nextCounts[commentId] = previousCounts
                self.commentReactionCountsByComment = nextCounts

                var nextSelected = self.viewerCommentReactionTypeIDsByComment
                nextSelected[commentId] = previousSelected
                self.viewerCommentReactionTypeIDsByComment = nextSelected

                self.showReactionError(self.friendlyReactionErrorMessage(for: error))
                print("Comment reaction toggle failed:", error)
                await self.refreshCommentReactionState(for: [commentId])
                await self.refreshLoadedComments(for: postId)
            }
        }
    }

    func subscribeToFeedRealtime() {
        guard !hasSubscribed else { return }
        hasSubscribed = true
        feedService.subscribeToPostMetrics { [weak self] updatedPostID in
            guard let self else { return }
            if let updatedPostID {
                Task { await self.refreshPost(postId: updatedPostID) }
            }
        }
    }

    func refreshEsports() async {
        isLoadingEsports = true
        try? await Task.sleep(for: .milliseconds(700))
        let seed = dataProvider.makeSeedData(referenceDate: Date())
        esportsMatches = seed.esportsMatches
        esportsMarkets = seed.esportsMarkets
        leagueStandings = seed.leagueStandings
        isLoadingEsports = false
    }
    
    func subscribeToCommentMetricsRealtime() {
        guard !hasSubscribedToCommentMetrics else { return }
        hasSubscribedToCommentMetrics = true
        feedService.subscribeToCommentMetrics { [weak self] updatedCommentID in
            guard let self, let updatedCommentID else { return }
            Task { await self.handleCommentMetricsRealtime(commentId: updatedCommentID) }
        }
    }

    func subscribeToNotificationsRealtime() {
        guard !hasSubscribedToNotifications else { return }
        guard let session = authenticatedSession else { return }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else { return }

        hasSubscribedToNotifications = true
        feedService.subscribeToNotifications(accessToken: accessToken) { [weak self] in
            self?.scheduleNotificationsRefresh()
        }
    }

    func refreshHotFeed() async {
        subscribeToFeedRealtime()
        subscribeToCommentMetricsRealtime()
        subscribeToNotificationsRealtime()
        feedIsLoading = true
        feedErrorMessage = nil
        defer { feedIsLoading = false }

        do {
            let fetchedPosts = try await feedService.fetchHotFeed()
            cachePublicProfiles(from: fetchedPosts)
            await refreshPublicProfiles(for: fetchedPosts.compactMap(\.authorID))
            await hydrateGameCatalog(for: fetchedPosts)
            applyHotFeedPosts(fetchedPosts, animated: false)
            let postIDs = fetchedPosts.map(\.id)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refreshReactionState(for: postIDs)
            }
        } catch {
            feedErrorMessage = error.localizedDescription
            print("Error loading hot feed:", error)
        }
    }

    func refreshFollowingFeed() async {
        guard let session = authenticatedSession else {
            followingPosts = []
            followingFeedErrorMessage = nil
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            followingPosts = []
            followingFeedErrorMessage = "Session expired"
            return
        }

        subscribeToFeedRealtime()
        subscribeToCommentMetricsRealtime()
        subscribeToNotificationsRealtime()
        followingFeedIsLoading = true
        followingFeedErrorMessage = nil
        defer { followingFeedIsLoading = false }

        do {
            let fetched = try await feedService.fetchFollowingFeed(accessToken: accessToken)
            cachePublicProfiles(from: fetched)
            await refreshPublicProfiles(for: fetched.compactMap(\.authorID))
            await hydrateGameCatalog(for: fetched)
            hasLoadedFollowingFeedOnce = true
            followingPosts = fetched.sorted(by: Self.sortPosts)
            let postIDs = fetched.map(\.id)
            await refreshReactionState(for: postIDs)
        } catch {
            followingFeedErrorMessage = error.localizedDescription
            print("Error loading following feed:", error)
        }
    }

    func refreshFollowedGames() async {
        guard let session = authenticatedSession else {
            followedGameIDs = []
            followedGamesErrorMessage = nil
            followedGamesIsLoading = false
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            followedGameIDs = []
            followedGamesErrorMessage = "Session expired"
            followedGamesIsLoading = false
            return
        }

        followedGamesIsLoading = true
        followedGamesErrorMessage = nil
        defer { followedGamesIsLoading = false }

        do {
            followedGameIDs = try await feedService.fetchFollowedGameIDs(
                userID: session.user.id,
                accessToken: accessToken
            )
        } catch {
            followedGamesErrorMessage = error.localizedDescription
            print("Error loading followed games:", error)
        }
    }

    func refreshPost(postId: UUID) async {
        guard !inFlightPostRefreshIDs.contains(postId) else { return }
        inFlightPostRefreshIDs.insert(postId)
        defer { inFlightPostRefreshIDs.remove(postId) }
        do {
            guard let updated = try await feedService.fetchPost(postID: postId) else {
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    let removedCommentIDs = commentsByPost[postId]?.map(\.id) ?? []
                    withAnimation(.easeInOut(duration: 0.2)) {
                        var nextPosts = posts
                        nextPosts.remove(at: index)
                        posts = nextPosts
                        followingPosts = followingPosts.filter { $0.id != postId }

                        var nextTotals = reactionTotalsByPost
                        nextTotals.removeValue(forKey: postId)
                        reactionTotalsByPost = nextTotals

                        var nextCounts = reactionCountsByPost
                        nextCounts.removeValue(forKey: postId)
                        reactionCountsByPost = nextCounts

                        var nextViewerSelections = viewerReactionTypeIDsByPost
                        nextViewerSelections.removeValue(forKey: postId)
                        viewerReactionTypeIDsByPost = nextViewerSelections

                        var nextComments = commentsByPost
                        nextComments.removeValue(forKey: postId)
                        commentsByPost = nextComments

                        var nextCommentLoading = commentIsLoadingByPost
                        nextCommentLoading.remove(postId)
                        commentIsLoadingByPost = nextCommentLoading

                        var nextCommentErrors = commentLoadErrorByPost
                        nextCommentErrors.removeValue(forKey: postId)
                        commentLoadErrorByPost = nextCommentErrors

                        var nextCommentHasMore = commentHasMoreByPost
                        nextCommentHasMore.removeValue(forKey: postId)
                        commentHasMoreByPost = nextCommentHasMore

                        var nextCommentSort = commentSortByPost
                        nextCommentSort.removeValue(forKey: postId)
                        commentSortByPost = nextCommentSort
                    }
                    commentOffsetsByPost.removeValue(forKey: postId)
                    if !removedCommentIDs.isEmpty {
                        var nextCommentReactionCounts = commentReactionCountsByComment
                        var nextViewerCommentReactions = viewerCommentReactionTypeIDsByComment
                        for commentID in removedCommentIDs {
                            nextCommentReactionCounts.removeValue(forKey: commentID)
                            nextViewerCommentReactions.removeValue(forKey: commentID)
                        }
                        commentReactionCountsByComment = nextCommentReactionCounts
                        viewerCommentReactionTypeIDsByComment = nextViewerCommentReactions
                    }
                }
                return
            }

            let shouldReconcileFollowingFeedMembership = hasLoadedFollowingFeedOnce
                && !followingPosts.contains(where: { $0.id == postId })
                && {
                    guard let gameID = updated.gameID else { return false }
                    return followedGameIDs.contains(gameID)
                }()

            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let previousCommentCount = posts[index].comment_count
                withAnimation(.easeInOut(duration: 0.2)) {
                    var nextPosts = posts
                    nextPosts[index] = updated
                    nextPosts.sort(by: Self.sortPosts)
                    posts = nextPosts

                    var nextTotals = reactionTotalsByPost
                    nextTotals[postId] = updated.reaction_count ?? 0
                    reactionTotalsByPost = nextTotals
                }
                await refreshReactionState(for: [postId])
                if commentsByPost[postId] != nil,
                   previousCommentCount != updated.comment_count {
                    await refreshLoadedComments(for: postId)
                }
                if let followingIndex = followingPosts.firstIndex(where: { $0.id == postId }) {
                    var nextFollowing = followingPosts
                    nextFollowing[followingIndex] = updated
                    nextFollowing.sort(by: Self.sortPosts)
                    followingPosts = nextFollowing
                }
            } else {
                if let followingIndex = followingPosts.firstIndex(where: { $0.id == postId }) {
                    var nextFollowing = followingPosts
                    nextFollowing[followingIndex] = updated
                    nextFollowing.sort(by: Self.sortPosts)
                    followingPosts = nextFollowing
                } else {
                    // No full-feed realtime refetch here; manual refresh/load can reconcile membership.
                }
            }
            if shouldReconcileFollowingFeedMembership {
                scheduleFollowingFeedRealtimeRefresh()
            }
            cachePublicProfiles(from: [updated])
            if let authorID = updated.authorID {
                await refreshPublicProfiles(for: [authorID])
            }
            await hydrateGameCatalog(for: [updated])
        } catch {
            print("Failed to refresh post:", error)
        }
    }

    func refreshNotifications() async {
        guard let session = authenticatedSession else {
            notifications = []
            notificationActorProfilesByID = [:]
            notificationsErrorMessage = nil
            notificationsIsLoading = false
            return
        }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            notifications = []
            notificationsErrorMessage = "Session expired"
            notificationsIsLoading = false
            return
        }

        subscribeToNotificationsRealtime()
        notificationsIsLoading = true
        notificationsErrorMessage = nil
        defer { notificationsIsLoading = false }

        do {
            let fetched = try await feedService.fetchNotifications(accessToken: accessToken, limit: 50)
            notifications = fetched
            await refreshNotificationActorProfiles(for: fetched)
        } catch {
            if isNotificationsAuthError(error),
               syncAuthenticatedSessionFromSupabaseIfNeeded(expectedUserID: session.user.id) {
                hasSubscribedToNotifications = false
                feedService.resetNotificationsSubscription()
                await refreshNotifications()
                return
            }

            if isNotificationsAuthError(error) {
                hasSubscribedToNotifications = false
                feedService.resetNotificationsSubscription()
            }

            notificationsErrorMessage = friendlyNotificationsErrorMessage(for: error)
            print("Error loading notifications:", error)
        }
    }

    func react(to postId: UUID, with reactionTypeId: UUID) {
        guard let session = authenticatedSession else {
            showReactionError("Sign in again to add reactions.")
            return
        }
        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            showReactionError("Your session expired. Sign in again to react.")
            return
        }

        let userId = session.user.id
        let operationKey = "\(postId.uuidString)|\(reactionTypeId.uuidString)"
        guard !inFlightPostReactionKeys.contains(operationKey) else { return }
        inFlightPostReactionKeys.insert(operationKey)
        let currentlySelected = viewerReactionTypeIDsByPost[postId, default: []].contains(reactionTypeId)
        let previousCounts = reactionCountsByPost[postId] ?? []
        let previousSelected = viewerReactionTypeIDsByPost[postId] ?? []
        let previousTotal = reactionTotalsByPost[postId] ?? posts.first(where: { $0.id == postId })?.reaction_count ?? 0

        applyOptimisticReactionMutation(
            postId: postId,
            reactionTypeId: reactionTypeId,
            isRemoving: currentlySelected
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlightPostReactionKeys.remove(operationKey) }
            do {
                if currentlySelected {
                    try await self.feedService.removeReaction(
                        postId: postId,
                        reactionTypeId: reactionTypeId,
                        userId: userId,
                        accessToken: accessToken
                    )
                } else {
                    try await self.feedService.addReaction(
                        postId: postId,
                        reactionTypeId: reactionTypeId,
                        userId: userId,
                        accessToken: accessToken
                    )
                }
                clearReactionError()
                // Metrics + counts reconcile through realtime callbacks.
            } catch {
                var nextCounts = self.reactionCountsByPost
                nextCounts[postId] = previousCounts
                self.reactionCountsByPost = nextCounts

                var nextViewerSelections = self.viewerReactionTypeIDsByPost
                nextViewerSelections[postId] = previousSelected
                self.viewerReactionTypeIDsByPost = nextViewerSelections

                var nextTotals = self.reactionTotalsByPost
                nextTotals[postId] = previousTotal
                self.reactionTotalsByPost = nextTotals

                self.showReactionError(self.friendlyReactionErrorMessage(for: error))
                print("Reaction toggle failed:", error)
                await self.refreshReactionState(for: [postId])
                await self.refreshPost(postId: postId)
            }
        }
    }

    func reactionTotal(for post: Post) -> Int {
        reactionTotalsByPost[post.id] ?? post.reaction_count ?? 0
    }

    func reactionCount(for postId: UUID, reactionTypeId: UUID) -> Int {
        reactionCountsByPost[postId]?
            .first(where: { $0.reactionTypeID == reactionTypeId })?
            .count ?? 0
    }

    func hasReacted(to postId: UUID, reactionTypeId: UUID) -> Bool {
        viewerReactionTypeIDsByPost[postId, default: []].contains(reactionTypeId)
    }

    func loadReactionCounts(for postId: UUID) {
        Task {
            await refreshReactionCounts(for: [postId])
        }
    }

    func comments(for postId: UUID) -> [Comment] {
        commentsByPost[postId] ?? []
    }

    var unreadNotificationsCount: Int {
        notifications.reduce(into: 0) { count, item in
            if !item.isRead { count += 1 }
        }
    }

    func notificationActorProfile(for userID: UUID) -> PublicProfile? {
        notificationActorProfilesByID[userID]
    }

    func publicProfile(for userID: UUID?) -> PublicProfile? {
        guard let userID else { return nil }
        return publicProfilesByID[userID]
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let session = authenticatedSession else { return }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else { return }

        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        guard notifications[index].isRead == false else { return }

        let previous = notifications[index]
        var next = notifications
        next[index] = AppNotification(
            id: previous.id,
            user_id: previous.user_id,
            actor_user_id: previous.actor_user_id,
            post_id: previous.post_id,
            comment_id: previous.comment_id,
            type: previous.type,
            created_at: previous.created_at,
            read: true
        )
        notifications = next

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.feedService.markNotificationRead(id: notificationID, accessToken: accessToken)
            } catch {
                if let rollbackIndex = self.notifications.firstIndex(where: { $0.id == notificationID }) {
                    var rollback = self.notifications
                    rollback[rollbackIndex] = previous
                    self.notifications = rollback
                }
                print("Failed to mark notification read:", error)
            }
        }
    }

    func markAllNotificationsRead() {
        guard let session = authenticatedSession else { return }

        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else { return }

        let previous = notifications
        guard previous.contains(where: { !$0.isRead }) else { return }

        notifications = previous.map { item in
            guard item.isRead == false else { return item }
            return AppNotification(
                id: item.id,
                user_id: item.user_id,
                actor_user_id: item.actor_user_id,
                post_id: item.post_id,
                comment_id: item.comment_id,
                type: item.type,
                created_at: item.created_at,
                read: true
            )
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.feedService.markAllNotificationsRead(accessToken: accessToken)
            } catch {
                self.notifications = previous
                print("Failed to mark all notifications read:", error)
            }
        }
    }

    func resolveNotificationPost(_ notification: AppNotification) async -> Post? {
        guard let postID = notification.postID else { return nil }
        if let cached = posts.first(where: { $0.id == postID }) ?? followingPosts.first(where: { $0.id == postID }) {
            return cached
        }
        do {
            return try await feedService.fetchPost(postID: postID)
        } catch {
            print("Failed to resolve notification post:", error)
            return nil
        }
    }

    private func configureFeedOwnership() {
        // reserved for future centralized store wiring (e.g., notifications/analytics hooks)
    }

    private func clearReactionError() {
        reactionErrorDismissTask?.cancel()
        reactionErrorDismissTask = nil
        reactionErrorMessage = nil
    }

    private func showReactionError(_ message: String) {
        reactionErrorDismissTask?.cancel()
        reactionErrorMessage = message
        reactionErrorDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.reactionErrorMessage = nil
        }
    }

    private func friendlyReactionErrorMessage(for error: Error) -> String {
        let raw = [error.localizedDescription, String(describing: error)]
            .joined(separator: " | ")
            .lowercased()

        if raw.contains("duplicate key") || raw.contains("reactions_post_id_user_id_reaction_type_id_key") {
            return "That reaction is already applied."
        }
        if raw.contains("42501") || raw.contains("row-level security") || raw.contains("permission") {
            return "Your account does not have permission to react yet."
        }
        if raw.contains("network") || raw.contains("offline") {
            return "Couldn’t update reaction. Check your connection and try again."
        }
        return "Couldn’t update reaction right now. Try again."
    }

    private func syncAuthenticatedSessionFromSupabaseIfNeeded(expectedUserID: UUID) -> Bool {
        guard let latest = SupabaseManager.shared.client.auth.currentSession,
              latest.user.id == expectedUserID else { return false }

        let currentToken = authenticatedSession?.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestToken = latest.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latestToken.isEmpty, currentToken != latestToken else { return false }

        setAuthenticatedSession(latest)
        return true
    }

    private func isNotificationsAuthError(_ error: Error) -> Bool {
        let raw = [error.localizedDescription, String(describing: error)]
            .joined(separator: " | ")
            .lowercased()
        return raw.contains("jwt expired")
            || raw.contains("token is expired")
            || raw.contains("invalid jwt")
            || raw.contains("401")
            || raw.contains("unauthorized")
            || raw.contains("sub")
    }

    private func friendlyNotificationsErrorMessage(for error: Error) -> String {
        if isNotificationsAuthError(error) {
            return "Your session expired while loading notifications. Pull to refresh or reopen after re-auth."
        }

        let raw = [error.localizedDescription, String(describing: error)]
            .joined(separator: " | ")
            .lowercased()
        if raw.contains("network") || raw.contains("offline") {
            return "Couldn’t load notifications. Check your connection and try again."
        }
        return "Couldn’t load notifications right now. Try again."
    }

    private func refreshLoadedComments(for postId: UUID) async {
        guard commentsByPost[postId] != nil else { return }
        let targetCount = max(commentOffsetsByPost[postId] ?? 0, commentPageSize)
        await fetchCommentsPage(for: postId, offset: 0, limit: targetCount, replaceExisting: true)
    }

    private func handleCommentMetricsRealtime(commentId: UUID) async {
        guard let postId = postID(containingCommentID: commentId) else { return }
        await refreshCommentReactionState(for: [commentId])
        scheduleCommentThreadRefresh(for: postId)
    }

    private func scheduleCommentThreadRefresh(for postId: UUID) {
        guard commentsByPost[postId] != nil else { return }
        pendingCommentRealtimePostIDs.insert(postId)
        guard pendingCommentRealtimeRefreshTask == nil else { return }

        pendingCommentRealtimeRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            let postIDs = Array(self.pendingCommentRealtimePostIDs)
            self.pendingCommentRealtimePostIDs.removeAll()
            self.pendingCommentRealtimeRefreshTask = nil
            for postID in postIDs {
                await self.refreshLoadedComments(for: postID)
            }
        }
    }

    private func scheduleNotificationsRefresh() {
        guard authenticatedSession != nil else { return }
        pendingNotificationsRefreshTask?.cancel()
        pendingNotificationsRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self.pendingNotificationsRefreshTask = nil
            await self.refreshNotifications()
        }
    }

    private func scheduleFollowingFeedRealtimeRefresh() {
        guard authenticatedSession != nil else { return }
        guard hasLoadedFollowingFeedOnce else { return }
        guard !followedGameIDs.isEmpty else { return }

        pendingFollowingFeedRealtimeRefreshTask?.cancel()
        pendingFollowingFeedRealtimeRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self.pendingFollowingFeedRealtimeRefreshTask = nil
            guard !self.followingFeedIsLoading else { return }
            await self.refreshFollowingFeed()
        }
    }

    private func refreshNotificationActorProfiles(for notifications: [AppNotification]) async {
        let actorIDs = notifications.map(\.actorUserID)
        guard !actorIDs.isEmpty else {
            notificationActorProfilesByID = [:]
            return
        }

        await refreshPublicProfiles(for: actorIDs)
        let actorSet = Set(actorIDs)
        notificationActorProfilesByID = publicProfilesByID.filter { actorSet.contains($0.key) }
    }

    private func refreshPublicProfiles(for userIDs: [UUID]) async {
        let uniqueIDs = Array(Set(userIDs))
        guard !uniqueIDs.isEmpty else { return }
        let missing = uniqueIDs.filter { publicProfilesByID[$0] == nil }
        guard !missing.isEmpty else { return }

        do {
            let profiles = try await publicProfileService.fetchPublicProfiles(ids: missing)
            cachePublicProfiles(profiles)
        } catch {
            print("Failed to load public profiles:", error)
        }
    }

    private func cachePublicProfiles(_ profiles: [PublicProfile]) {
        guard !profiles.isEmpty else { return }
        var next = publicProfilesByID
        for profile in profiles {
            next[profile.id] = profile
        }
        publicProfilesByID = next
    }

    private func cachePublicProfiles(from posts: [Post]) {
        let profiles = posts.compactMap(\.authorProfile)
        cachePublicProfiles(profiles)
    }

    private func cachePublicProfiles(from comments: [Comment]) {
        let profiles = comments.compactMap(\.authorProfile)
        cachePublicProfiles(profiles)
    }

    private func hydrateGameCatalog(for posts: [Post]) async {
        let gameIDs = Set(posts.compactMap(\.gameID))
            .union(posts.compactMap(\.primaryBadgeGameID))
        guard !gameIDs.isEmpty else { return }
        let missing = gameIDs.filter { gameCatalogByID[$0] == nil }
        guard !missing.isEmpty else { return }

        do {
            let games = try await feedService.fetchGameCatalog(ids: Array(missing))
            cacheGameCatalog(games)
        } catch {
            print("Failed to load game catalog:", error)
        }
    }

    private func cacheGameCatalog(_ games: [Game]) {
        guard !games.isEmpty else { return }
        var next = gameCatalogByID
        for game in games {
            next[game.id] = game
        }
        gameCatalogByID = next
    }

    private func fetchCommentsPage(
        for postId: UUID,
        offset: Int,
        limit: Int? = nil,
        replaceExisting: Bool
    ) async {
        guard visibleFeedPostIDs.contains(postId) else { return }

        var nextLoading = commentIsLoadingByPost
        nextLoading.insert(postId)
        commentIsLoadingByPost = nextLoading

        var nextErrors = commentLoadErrorByPost
        nextErrors.removeValue(forKey: postId)
        commentLoadErrorByPost = nextErrors

        let pageLimit = max(limit ?? commentPageSize, 1)

        defer {
            var latestLoading = commentIsLoadingByPost
            latestLoading.remove(postId)
            commentIsLoadingByPost = latestLoading
        }

        do {
            let fetched = try await feedService.fetchComments(
                postID: postId,
                sort: commentSortMode(for: postId),
                limit: pageLimit,
                offset: offset
            )

            let merged: [Comment]
            if replaceExisting || offset == 0 {
                merged = fetched
            } else {
                let existing = commentsByPost[postId] ?? []
                var seen = Set(existing.map(\.id))
                var appended = existing
                for comment in fetched where seen.insert(comment.id).inserted {
                    appended.append(comment)
                }
                merged = appended
            }

            let trimmed = Array(merged.prefix(maxCachedCommentsPerPost))

            var nextComments = commentsByPost
            nextComments[postId] = trimmed
            commentsByPost = nextComments

            commentOffsetsByPost[postId] = min(offset + fetched.count, trimmed.count)

            var nextHasMore = commentHasMoreByPost
            nextHasMore[postId] = fetched.count == pageLimit && trimmed.count < maxCachedCommentsPerPost
            commentHasMoreByPost = nextHasMore

            await refreshCommentReactionState(for: trimmed.map(\.id))
            cachePublicProfiles(from: trimmed)
            await refreshPublicProfiles(for: trimmed.map(\.userID))
        } catch {
            var latestErrors = commentLoadErrorByPost
            latestErrors[postId] = error.localizedDescription
            commentLoadErrorByPost = latestErrors

            var latestHasMore = commentHasMoreByPost
            latestHasMore[postId] = false
            commentHasMoreByPost = latestHasMore

            print("Failed to load comments:", error)
        }
    }

    private func applyOptimisticCommentInsert(_ comment: Comment) {
        var nextComments = commentsByPost
        var current = nextComments[comment.postID] ?? []
        current.insert(comment, at: 0)
        nextComments[comment.postID] = current
        commentsByPost = nextComments
    }

    private func removeOptimisticComment(_ comment: Comment) {
        guard var current = commentsByPost[comment.postID] else { return }
        current.removeAll { $0.id == comment.id }

        var nextComments = commentsByPost
        nextComments[comment.postID] = current
        commentsByPost = nextComments

        var nextCommentReactionCounts = commentReactionCountsByComment
        nextCommentReactionCounts.removeValue(forKey: comment.id)
        commentReactionCountsByComment = nextCommentReactionCounts

        var nextViewerCommentReactions = viewerCommentReactionTypeIDsByComment
        nextViewerCommentReactions.removeValue(forKey: comment.id)
        viewerCommentReactionTypeIDsByComment = nextViewerCommentReactions
    }

    private func refreshCommentReactionState(for commentIDs: [UUID]) async {
        await refreshCommentReactionCounts(for: commentIDs)
        await loadViewerCommentReactions(for: commentIDs)
    }

    private func refreshCommentReactionCounts(for commentIDs: [UUID]) async {
        let visibleCommentIDs = Set(commentsByPost.values.flatMap { $0.map(\.id) })
        let targetCommentIDs = commentIDs.filter { visibleCommentIDs.contains($0) }
        guard !targetCommentIDs.isEmpty else { return }

        do {
            let grouped = try await feedService.fetchCommentReactionCounts(commentIDs: targetCommentIDs)
            var next = commentReactionCountsByComment
            for commentID in targetCommentIDs {
                next[commentID] = grouped[commentID] ?? []
            }
            commentReactionCountsByComment = next
        } catch {
            print("Failed to load comment reaction counts:", error)
        }
    }

    private func loadViewerCommentReactions(for commentIDs: [UUID]) async {
        guard let session = authenticatedSession else { return }

        let visibleCommentIDs = Set(commentsByPost.values.flatMap { $0.map(\.id) })
        let targetCommentIDs = commentIDs.filter { visibleCommentIDs.contains($0) }
        guard !targetCommentIDs.isEmpty else { return }

        do {
            let grouped = try await feedService.fetchViewerReactionsByComment(
                userID: session.user.id,
                commentIDs: targetCommentIDs
            )
            var next = viewerCommentReactionTypeIDsByComment
            for commentID in targetCommentIDs {
                next[commentID] = grouped[commentID] ?? []
            }
            viewerCommentReactionTypeIDsByComment = next
        } catch {
            print("Failed to load viewer comment reactions:", error)
        }
    }

    private func refreshReactionTypes() async {
        do {
            reactionTypes = try await feedService.fetchReactionTypes()
        } catch {
            print("Failed to load reaction types:", error)
        }
    }

    private func refreshReactionState(for postIDs: [UUID]) async {
        await refreshReactionCounts(for: postIDs)
        await loadViewerReactions(for: postIDs)
    }

    private func refreshReactionCounts(for postIDs: [UUID]) async {
        let visiblePostIDs = Set(posts.map(\.id))
        let targetPostIDs = postIDs.filter { visiblePostIDs.contains($0) }
        guard !targetPostIDs.isEmpty else { return }

        do {
            let grouped = try await feedService.fetchReactionCounts(postIDs: targetPostIDs)
            var nextCountsByPost = reactionCountsByPost
            var nextTotalsByPost = reactionTotalsByPost

            for postID in targetPostIDs {
                let counts = grouped[postID] ?? []
                nextCountsByPost[postID] = counts
                nextTotalsByPost[postID] = counts.reduce(0) { $0 + $1.count }
            }

            reactionCountsByPost = nextCountsByPost
            reactionTotalsByPost = nextTotalsByPost
        } catch {
            print("Failed to load reaction counts:", error)
        }
    }

    private func loadViewerReactions(for postIDs: [UUID]) async {
        guard let session = authenticatedSession else { return }

        let visiblePostIDs = Set(posts.map(\.id))
        let targetPostIDs = postIDs.filter { visiblePostIDs.contains($0) }
        guard !targetPostIDs.isEmpty else { return }

        do {
            let grouped = try await feedService.fetchViewerReactionsByPost(
                userID: session.user.id,
                postIDs: targetPostIDs
            )

            var nextViewerSelections = viewerReactionTypeIDsByPost
            for postID in targetPostIDs {
                nextViewerSelections[postID] = grouped[postID] ?? []
            }
            viewerReactionTypeIDsByPost = nextViewerSelections
        } catch {
            print("Failed to load viewer reactions:", error)
        }
    }

    private func applyHotFeedPosts(_ newPosts: [Post], animated: Bool) {
        let previousBreakdowns = reactionCountsByPost
        let previousViewerSelections = viewerReactionTypeIDsByPost
        let assign = {
            self.posts = newPosts
            self.reactionTotalsByPost = Dictionary(
                uniqueKeysWithValues: newPosts.map { ($0.id, $0.reaction_count ?? 0) }
            )
            self.reactionCountsByPost = Dictionary(
                uniqueKeysWithValues: newPosts.map { ($0.id, previousBreakdowns[$0.id] ?? []) }
            )
            self.viewerReactionTypeIDsByPost = Dictionary(
                uniqueKeysWithValues: newPosts.map { ($0.id, previousViewerSelections[$0.id] ?? []) }
            )
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                assign()
            }
        } else {
            assign()
        }
    }

    private static func sortPosts(_ lhs: Post, _ rhs: Post) -> Bool {
        if (lhs.hot_score ?? .leastNormalMagnitude) == (rhs.hot_score ?? .leastNormalMagnitude) {
            return lhs.created_at > rhs.created_at
        }
        return (lhs.hot_score ?? .leastNormalMagnitude) > (rhs.hot_score ?? .leastNormalMagnitude)
    }

    private var visibleFeedPostIDs: Set<UUID> {
        Set(posts.map(\.id))
            .union(followingPosts.map(\.id))
            .union(commentsByPost.keys)
    }

    private func postID(containingCommentID commentId: UUID) -> UUID? {
        for (postID, comments) in commentsByPost where comments.contains(where: { $0.id == commentId }) {
            return postID
        }
        return nil
    }

    private static func incrementReactionCount(
        _ counts: [PostReactionCount],
        postID: UUID,
        reactionTypeID: UUID
    ) -> [PostReactionCount] {
        var next = counts
        if let index = next.firstIndex(where: { $0.reactionTypeID == reactionTypeID }) {
            next[index].count += 1
        } else {
            next.append(PostReactionCount(post_id: postID, reaction_type_id: reactionTypeID, count: 1))
        }
        return next
    }

    private static func decrementReactionCount(
        _ counts: [PostReactionCount],
        reactionTypeID: UUID
    ) -> [PostReactionCount] {
        var next = counts
        guard let index = next.firstIndex(where: { $0.reactionTypeID == reactionTypeID }) else {
            return next
        }
        next[index].count -= 1
        if next[index].count <= 0 {
            next.remove(at: index)
        }
        return next
    }

    private func applyOptimisticReactionMutation(
        postId: UUID,
        reactionTypeId: UUID,
        isRemoving: Bool
    ) {
        let previousCounts = reactionCountsByPost[postId] ?? []
        let previousTotal = reactionTotalsByPost[postId] ?? posts.first(where: { $0.id == postId })?.reaction_count ?? 0
        let previousSelected = viewerReactionTypeIDsByPost[postId] ?? []

        var nextCountsByPost = reactionCountsByPost
        nextCountsByPost[postId] = isRemoving
            ? Self.decrementReactionCount(previousCounts, reactionTypeID: reactionTypeId)
            : Self.incrementReactionCount(previousCounts, postID: postId, reactionTypeID: reactionTypeId)
        reactionCountsByPost = nextCountsByPost

        var nextTotalsByPost = reactionTotalsByPost
        nextTotalsByPost[postId] = isRemoving ? max(previousTotal - 1, 0) : previousTotal + 1
        reactionTotalsByPost = nextTotalsByPost

        var nextSelected = previousSelected
        if isRemoving {
            nextSelected.remove(reactionTypeId)
        } else {
            nextSelected.insert(reactionTypeId)
        }
        var nextViewerSelections = viewerReactionTypeIDsByPost
        nextViewerSelections[postId] = nextSelected
        viewerReactionTypeIDsByPost = nextViewerSelections
    }

    private static func incrementCommentReactionCount(
        _ counts: [CommentReactionCount],
        commentID: UUID,
        reactionTypeID: UUID
    ) -> [CommentReactionCount] {
        var next = counts
        if let index = next.firstIndex(where: { $0.reactionTypeID == reactionTypeID }) {
            next[index].count += 1
        } else {
            next.append(CommentReactionCount(comment_id: commentID, reaction_type_id: reactionTypeID, count: 1))
        }
        return next
    }

    private static func decrementCommentReactionCount(
        _ counts: [CommentReactionCount],
        reactionTypeID: UUID
    ) -> [CommentReactionCount] {
        var next = counts
        guard let index = next.firstIndex(where: { $0.reactionTypeID == reactionTypeID }) else {
            return next
        }
        next[index].count -= 1
        if next[index].count <= 0 {
            next.remove(at: index)
        }
        return next
    }

    private func applyOptimisticCommentReactionMutation(
        commentId: UUID,
        reactionTypeId: UUID,
        isRemoving: Bool
    ) {
        let previousCounts = commentReactionCountsByComment[commentId] ?? []
        let previousSelected = viewerCommentReactionTypeIDsByComment[commentId] ?? []

        var nextCounts = commentReactionCountsByComment
        nextCounts[commentId] = isRemoving
            ? Self.decrementCommentReactionCount(previousCounts, reactionTypeID: reactionTypeId)
            : Self.incrementCommentReactionCount(previousCounts, commentID: commentId, reactionTypeID: reactionTypeId)
        commentReactionCountsByComment = nextCounts

        var nextSelected = previousSelected
        if isRemoving {
            nextSelected.remove(reactionTypeId)
        } else {
            nextSelected.insert(reactionTypeId)
        }
        var nextViewer = viewerCommentReactionTypeIDsByComment
        nextViewer[commentId] = nextSelected
        viewerCommentReactionTypeIDsByComment = nextViewer
    }
}

struct AppSeedData {
    let ownedGames: [Game]
    let upcomingReleases: [Game]
    let defaultFavoriteIDs: [Game.ID]
    let newsFeed: [NewsItem]
    let shortVideos: [ShortVideo]
    let esportsMatches: [EsportsMatch]
    let esportsMarkets: [EsportsMarket]
    let leagueStandings: [String: [LeagueStanding]]
    let threadsByGame: [Game.ID: [ThreadPost]]

    init(referenceDate: Date) {
        let calendar = Calendar.current

        func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? referenceDate
        }

        func parseURL(_ value: String?) -> URL? {
            guard let value else { return nil }
            return URL(string: value)
        }

        func game(
            _ title: String,
            publisher: String,
            genre: String,
            releaseDate: Date,
            similar: [String],
            scores: [(String, Int)],
            isOwned: Bool = false,
            coverURL: String? = nil,
            screenshotURLs: [String] = []
        ) -> Game {
            Game(
                id: UUID(),
                title: title,
                publisher: publisher,
                genre: genre,
                releaseDate: releaseDate,
                similarTitles: similar,
                reviewScores: scores.map { ReviewScore(source: $0.0, value: $0.1) },
                isOwned: isOwned,
                coverImageURL: parseURL(coverURL),
                screenshotURLs: screenshotURLs.compactMap(parseURL)
            )
        }

        // Real release targets sourced from official publisher/platform announcements.
        let allUpcoming = [
            game(
                "Resident Evil Requiem",
                publisher: "Capcom",
                genre: "Survival Horror",
                releaseDate: makeDate(2026, 2, 27),
                similar: ["Resident Evil Village", "The Evil Within 2", "Dead Space"],
                scores: [("IGN", 90), ("GameSpot", 88), ("OpenCritic", 89)],
                coverURL: "https://i.ytimg.com/vi/W6bGrIvnTrU/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/0.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/1.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/2.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/3.jpg"
                ]
            ),
            game(
                "Marathon",
                publisher: "Bungie",
                genre: "Extraction Shooter",
                releaseDate: makeDate(2026, 3, 5),
                similar: ["Hunt: Showdown", "Escape from Tarkov", "The Finals"],
                scores: [("IGN", 84), ("GameSpot", 82), ("OpenCritic", 83)],
                coverURL: "https://i.ytimg.com/vi/t3ZO8tbmCvc/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/0.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/1.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/2.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/3.jpg"
                ]
            ),
            game(
                "Monster Hunter Stories 3: Twisted Reflection",
                publisher: "Capcom",
                genre: "Turn-Based RPG",
                releaseDate: makeDate(2026, 3, 13),
                similar: ["Monster Hunter Stories 2", "Shin Megami Tensei V", "Persona 5 Royal"],
                scores: [("IGN", 86), ("GameSpot", 85), ("OpenCritic", 85)],
                coverURL: "https://i.ytimg.com/vi/YBkkrLe3WYE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/0.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/1.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/2.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/3.jpg"
                ]
            ),
            game(
                "Crimson Desert",
                publisher: "Pearl Abyss",
                genre: "Open World Action RPG",
                releaseDate: makeDate(2026, 3, 19),
                similar: ["Black Desert", "Dragon's Dogma 2", "The Witcher 3"],
                scores: [("IGN", 89), ("GameSpot", 87), ("OpenCritic", 88)],
                coverURL: "https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/0V8mt28YVwE/0.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/1.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/2.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/3.jpg"
                ]
            ),
            game(
                "Tomodachi Life: Living the Dream",
                publisher: "Nintendo",
                genre: "Life Sim",
                releaseDate: makeDate(2026, 4, 16),
                similar: ["Animal Crossing: New Horizons", "Miitopia", "The Sims 4"],
                scores: [("IGN", 82), ("GameSpot", 80), ("OpenCritic", 81)],
                coverURL: "https://i.ytimg.com/vi/K_0kl1WiSPg/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/0.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/1.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/2.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/3.jpg"
                ]
            ),
            game(
                "Pragmata",
                publisher: "Capcom",
                genre: "Sci-Fi Action Adventure",
                releaseDate: makeDate(2026, 4, 24),
                similar: ["Death Stranding", "Control", "Returnal"],
                scores: [("IGN", 85), ("GameSpot", 83), ("OpenCritic", 84)],
                coverURL: "https://i.ytimg.com/vi/jCA0S4yXSEE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/0.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/1.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/2.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/3.jpg"
                ]
            ),
            game(
                "Saros",
                publisher: "Housemarque",
                genre: "Sci-Fi Action",
                releaseDate: makeDate(2026, 4, 30),
                similar: ["Returnal", "Control", "Dead Space"],
                scores: [("IGN", 88), ("GameSpot", 86), ("OpenCritic", 87)],
                coverURL: "https://i.ytimg.com/vi/XtCS5tuvCKs/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/0.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/1.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/2.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/3.jpg"
                ]
            ),
            game(
                "Beast of Reincarnation",
                publisher: "Game Freak",
                genre: "Action Adventure",
                releaseDate: makeDate(2026, 8, 4),
                similar: ["NieR: Automata", "Scarlet Nexus", "Astral Chain"],
                scores: [("IGN", 84), ("GameSpot", 82), ("OpenCritic", 83)],
                coverURL: "https://i.ytimg.com/vi/zqxdVtJ24ms/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/0.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/1.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/2.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/3.jpg"
                ]
            )
        ]

        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .month, value: 6, to: start) ?? start
        upcomingReleases = allUpcoming
            .filter { $0.releaseDate >= start && $0.releaseDate <= end }
            .sorted { $0.releaseDate < $1.releaseDate }

        let libraryCandidates = [
            game(
                "Crimson Desert",
                publisher: "Pearl Abyss",
                genre: "Open World Action RPG",
                releaseDate: makeDate(2026, 3, 19),
                similar: ["Black Desert", "Dragon's Dogma 2"],
                scores: [("IGN", 89), ("GameSpot", 87), ("OpenCritic", 88)],
                isOwned: true,
                coverURL: "https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/0V8mt28YVwE/0.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/1.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/2.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/3.jpg"
                ]
            ),
            game(
                "Helldivers 2",
                publisher: "Arrowhead Game Studios",
                genre: "Co-op Shooter",
                releaseDate: makeDate(2024, 2, 8),
                similar: ["Deep Rock Galactic", "Warframe"],
                scores: [("IGN", 90), ("GameSpot", 85), ("OpenCritic", 87)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/library_hero.jpg"
                ]
            ),
            game(
                "Baldur's Gate 3",
                publisher: "Larian Studios",
                genre: "CRPG",
                releaseDate: makeDate(2023, 8, 3),
                similar: ["Divinity: Original Sin 2", "Dragon Age: Origins"],
                scores: [("IGN", 100), ("GameSpot", 90), ("OpenCritic", 96)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/library_hero.jpg"
                ]
            ),
            game(
                "Cyberpunk 2077",
                publisher: "CD PROJEKT RED",
                genre: "Action RPG",
                releaseDate: makeDate(2020, 12, 10),
                similar: ["Deus Ex", "The Outer Worlds"],
                scores: [("IGN", 90), ("GameSpot", 70), ("OpenCritic", 86)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_hero.jpg"
                ]
            )
        ]

        ownedGames = libraryCandidates.sorted { $0.title < $1.title }

        defaultFavoriteIDs = upcomingReleases
            .filter { ["Crimson Desert", "Resident Evil Requiem", "Pragmata"].contains($0.title) }
            .map(\.id)

        newsFeed = [
            NewsItem(
                id: UUID(),
                headline: "Crimson Desert launch set for March 19, 2026 with new gameplay reveal",
                summary: "Pearl Abyss confirmed the date and dropped a new trailer. Community interest is surging ahead of launch month.",
                publishedAt: referenceDate.addingTimeInterval(-2_800),
                category: "Hot",
                isHot: true
            ),
            NewsItem(
                id: UUID(),
                headline: "Bungie confirms Marathon release for March 5, 2026",
                summary: "New details highlighted faction contracts, progression systems, and an open preview weekend before launch.",
                publishedAt: referenceDate.addingTimeInterval(-7_800),
                category: "Studio",
                isHot: true
            ),
            NewsItem(
                id: UUID(),
                headline: "Capcom schedules Pragmata for April 24, 2026",
                summary: "The latest showcase included new footage and a clearer look at the game’s science-fiction world.",
                publishedAt: referenceDate.addingTimeInterval(-13_400),
                category: "Upcoming",
                isHot: false
            ),
            NewsItem(
                id: UUID(),
                headline: "Nintendo dates Tomodachi Life: Living the Dream for April 16, 2026",
                summary: "The social life-sim returns this spring, giving players another major release in April.",
                publishedAt: referenceDate.addingTimeInterval(-19_800),
                category: "Nintendo",
                isHot: false
            )
        ]

        shortVideos = [
            ShortVideo(
                id: UUID(),
                title: "Crimson Desert reveal trailer highlights open-world combat",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 58,
                viewCount: 1_280_000,
                relatedGameTitles: ["Crimson Desert"],
                videoURL: parseURL("https://www.youtube.com/watch?v=0V8mt28YVwE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Resident Evil Requiem trailer breakdown in under a minute",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 54,
                viewCount: 942_000,
                relatedGameTitles: ["Resident Evil Requiem"],
                videoURL: parseURL("https://www.youtube.com/watch?v=W6bGrIvnTrU"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/W6bGrIvnTrU/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Marathon gameplay reveal recap",
                creator: "Marathon",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 49,
                viewCount: 761_000,
                relatedGameTitles: ["Marathon"],
                videoURL: parseURL("https://www.youtube.com/live/t3ZO8tbmCvc"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/t3ZO8tbmCvc/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Saros reveal clip and lore setup",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 43,
                viewCount: 504_000,
                relatedGameTitles: ["Saros"],
                videoURL: parseURL("https://www.youtube.com/watch?v=XtCS5tuvCKs"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/XtCS5tuvCKs/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Pragmata trailer cut: key moments",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 47,
                viewCount: 411_000,
                relatedGameTitles: ["Pragmata"],
                videoURL: parseURL("https://www.youtube.com/watch?v=jCA0S4yXSEE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/jCA0S4yXSEE/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Monster Hunter Stories 3 reveal clip",
                creator: "IGN",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 44,
                viewCount: 287_000,
                relatedGameTitles: ["Monster Hunter Stories 3: Twisted Reflection"],
                videoURL: parseURL("https://www.youtube.com/watch?v=YBkkrLe3WYE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/YBkkrLe3WYE/hqdefault.jpg")
            )
        ]

        func scheduleTime(daysFromNow: Int, hour: Int, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: daysFromNow, to: referenceDate) ?? referenceDate
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        esportsMatches = [
            // Live
            EsportsMatch(id: UUID(), league: "VCT", homeTeam: "Sentinels", awayTeam: "Paper Rex", homeRecord: "12-4", awayRecord: "11-5", homeScore: 2, awayScore: 1, state: .live, detailLine: "LIVE · MAP 4", subDetail: "Ascent · 7m", isFeatured: true, seriesFormat: 5, streamURL: URL(string: "https://www.twitch.tv/valorant_esports")),
            EsportsMatch(id: UUID(), league: "LoL", homeTeam: "T1", awayTeam: "Gen.G", homeRecord: "10-2", awayRecord: "11-1", homeScore: 1, awayScore: 1, state: .live, detailLine: "LIVE · GAME 3", subDetail: "Baron in 1m", isFeatured: false, seriesFormat: 5, streamURL: URL(string: "https://www.twitch.tv/lck")),
            // Final
            EsportsMatch(id: UUID(), league: "CS2", homeTeam: "G2", awayTeam: "FaZe", homeRecord: "9-3", awayRecord: "8-4", homeScore: 16, awayScore: 13, state: .final, detailLine: "FINAL", subDetail: "Inferno", isFeatured: false),
            EsportsMatch(id: UUID(), league: "LoL", homeTeam: "G2", awayTeam: "Fnatic", homeRecord: "8-4", awayRecord: "8-4", homeScore: 2, awayScore: 0, state: .final, detailLine: "FINAL", subDetail: "Best of 3", isFeatured: false, seriesFormat: 3),
            EsportsMatch(id: UUID(), league: "Dota 2", homeTeam: "Spirit", awayTeam: "BetBoom", homeRecord: "6-3", awayRecord: "6-3", homeScore: 1, awayScore: 2, state: .final, detailLine: "FINAL", subDetail: "Best of 3", isFeatured: false, seriesFormat: 3),
            // Today – upcoming
            EsportsMatch(id: UUID(), league: "CS2", homeTeam: "Team Spirit", awayTeam: "MOUZ", homeRecord: "7-5", awayRecord: "7-5", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Stage Match", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 0, hour: 10)),
            EsportsMatch(id: UUID(), league: "Dota 2", homeTeam: "Falcons", awayTeam: "Liquid", homeRecord: "6-3", awayRecord: "5-4", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Group Stage", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 0, hour: 13, minute: 30)),
            EsportsMatch(id: UUID(), league: "VCT", homeTeam: "NRG", awayTeam: "100 Thieves", homeRecord: "9-3", awayRecord: "8-4", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Playoffs", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 0, hour: 17)),
            EsportsMatch(id: UUID(), league: "LoL", homeTeam: "Cloud9", awayTeam: "TSM", homeRecord: "7-5", awayRecord: "5-7", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO1", subDetail: "LCS Regular Season", isFeatured: false, scheduledAt: scheduleTime(daysFromNow: 0, hour: 20)),
            // Tomorrow – upcoming
            EsportsMatch(id: UUID(), league: "CS2", homeTeam: "Heroic", awayTeam: "Virtus.pro", homeRecord: "8-4", awayRecord: "7-5", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Group Stage", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 1, hour: 10)),
            EsportsMatch(id: UUID(), league: "VCT", homeTeam: "Loud", awayTeam: "Evil Geniuses", homeRecord: "10-2", awayRecord: "7-5", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Playoffs Quarterfinal", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 1, hour: 14)),
            EsportsMatch(id: UUID(), league: "LoL", homeTeam: "DRX", awayTeam: "KT Rolster", homeRecord: "9-3", awayRecord: "8-4", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO5", subDetail: "LCK Semifinals", isFeatured: false, seriesFormat: 5, scheduledAt: scheduleTime(daysFromNow: 1, hour: 18)),
            // Day +2 – upcoming
            EsportsMatch(id: UUID(), league: "Dota 2", homeTeam: "Team Secret", awayTeam: "OG", homeRecord: "5-4", awayRecord: "5-4", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Group Stage", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 2, hour: 11)),
            EsportsMatch(id: UUID(), league: "CS2", homeTeam: "FaZe", awayTeam: "Vitality", homeRecord: "8-4", awayRecord: "9-3", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO3", subDetail: "Playoffs Semifinal", isFeatured: false, seriesFormat: 3, scheduledAt: scheduleTime(daysFromNow: 2, hour: 15)),
            EsportsMatch(id: UUID(), league: "VCT", homeTeam: "Paper Rex", awayTeam: "Loud", homeRecord: "11-5", awayRecord: "10-2", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO5", subDetail: "Grand Final", isFeatured: false, seriesFormat: 5, scheduledAt: scheduleTime(daysFromNow: 2, hour: 19)),
            // Day +3 – upcoming
            EsportsMatch(id: UUID(), league: "LoL", homeTeam: "T1", awayTeam: "DRX", homeRecord: "10-2", awayRecord: "9-3", homeScore: 0, awayScore: 0, state: .upcoming, detailLine: "BO5", subDetail: "LCK Grand Final", isFeatured: false, seriesFormat: 5, scheduledAt: scheduleTime(daysFromNow: 3, hour: 16)),
        ]

        esportsMarkets = [
            EsportsMarket(
                id: UUID(),
                title: "Valorant Champions: Who wins the upper-final?",
                league: "VCT",
                startsAt: referenceDate.addingTimeInterval(9_000),
                outcomes: [
                    MarketOutcome(teamName: "Sentinels", price: 0.57, trend: .up),
                    MarketOutcome(teamName: "Paper Rex", price: 0.43, trend: .down)
                ],
                volumeUSD: 1_420_000,
                isLive: false
            ),
            EsportsMarket(
                id: UUID(),
                title: "League MSI: Total maps over 3.5?",
                league: "LoL",
                startsAt: referenceDate.addingTimeInterval(24_000),
                outcomes: [
                    MarketOutcome(teamName: "Yes", price: 0.62, trend: .flat),
                    MarketOutcome(teamName: "No", price: 0.38, trend: .flat)
                ],
                volumeUSD: 860_000,
                isLive: false
            ),
            EsportsMarket(
                id: UUID(),
                title: "CS2 Major: Team Spirit vs G2 match winner",
                league: "CS2",
                startsAt: referenceDate.addingTimeInterval(1_200),
                outcomes: [
                    MarketOutcome(teamName: "Team Spirit", price: 0.49, trend: .down),
                    MarketOutcome(teamName: "G2", price: 0.51, trend: .up)
                ],
                volumeUSD: 2_210_000,
                isLive: true
            ),
            EsportsMarket(
                id: UUID(),
                title: "Dota Pro Circuit: Falcons top 2 finish",
                league: "Dota 2",
                startsAt: referenceDate.addingTimeInterval(172_800),
                outcomes: [
                    MarketOutcome(teamName: "Yes", price: 0.41, trend: .up),
                    MarketOutcome(teamName: "No", price: 0.59, trend: .down)
                ],
                volumeUSD: 610_000,
                isLive: false
            )
        ]

        var threadMap: [Game.ID: [ThreadPost]] = [:]
        let allGames = ownedGames + upcomingReleases

        let strategyOpeners = [
            "Best launch route for \(calendar.component(.year, from: referenceDate))",
            "What should be optimized first?",
            "Meta early-game strategy check",
            "First-week progression path thread"
        ]
        let discussionPrompts = [
            "Share your cleanest screenshot and where you captured it.",
            "Post your favorite environment shot from trailers or previews.",
            "Drop your best character/city/combat stills.",
            "Photo thread: visual details worth rewatching."
        ]
        let clipPrompts = [
            "Which moments in this clip should the community break down next?",
            "Video thread: best sequence and why?",
            "Trailer timing thread: strongest 10 seconds?",
            "Clip review: what detail did everyone miss?"
        ]
        let authors = ["PatchWizard", "LorePilot", "FrameDoctor", "QuestPilot", "MetaScout"]
        let defaultVideoURL = shortVideos.first?.videoURL
        let defaultVideoThumbnailURL = shortVideos.first?.thumbnailURL

        for (index, game) in allGames.enumerated() {
            let relatedClip = shortVideos.first { clip in
                clip.relatedGameTitles.contains(where: { $0.caseInsensitiveCompare(game.title) == .orderedSame })
            }
            let imageURL = game.coverImageURL ?? game.screenshotURLs.first
            let alternateImageURL = game.screenshotURLs.dropFirst().first ?? game.coverImageURL
            let nowOffset = TimeInterval(index * 280)

            threadMap[game.id] = [
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) \(strategyOpeners[index % strategyOpeners.count])",
                    body: "For \(game.genre), what are the first 2-3 things everyone should do? Build routes, quest order, and settings tips all welcome.",
                    author: authors[index % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-2_200 - nowOffset),
                    upvotes: 172 + (index * 3),
                    comments: 68 + (index * 2),
                    contentType: .text
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) visual thread",
                    body: discussionPrompts[index % discussionPrompts.count],
                    author: authors[(index + 1) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-5_900 - nowOffset),
                    upvotes: 136 + (index * 2),
                    comments: 42 + index,
                    contentType: .image,
                    mediaURL: imageURL ?? alternateImageURL
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) clip breakdown",
                    body: clipPrompts[index % clipPrompts.count],
                    author: authors[(index + 2) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-8_400 - nowOffset),
                    upvotes: 145 + (index * 2),
                    comments: 51 + index,
                    contentType: .video,
                    mediaURL: relatedClip?.videoURL ?? defaultVideoURL,
                    mediaThumbnailURL: relatedClip?.thumbnailURL ?? imageURL ?? defaultVideoThumbnailURL
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "Performance settings thread",
                    body: "Share platform-specific settings that improve frame pacing and reduce stutter.",
                    author: authors[(index + 3) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-11_200 - nowOffset),
                    upvotes: 101 + index,
                    comments: 27 + (index % 4),
                    contentType: .text
                )
            ]
        }

        threadsByGame = threadMap

        func makeStandings(_ data: [(String, Int, Int)]) -> [LeagueStanding] {
            data.enumerated().map { i, entry in
                LeagueStanding(id: UUID(), rank: i + 1, teamName: entry.0, wins: entry.1, losses: entry.2)
            }
        }

        leagueStandings = [
            "VCT": makeStandings([
                ("Loud",          10, 2),
                ("NRG",            9, 3),
                ("Sentinels",     12, 4),
                ("Paper Rex",     11, 5),
                ("100 Thieves",    8, 4),
                ("Evil Geniuses",  7, 5),
            ]),
            "LoL": makeStandings([
                ("Gen.G",      11, 1),
                ("T1",         10, 2),
                ("DRX",         9, 3),
                ("G2",          8, 4),
                ("KT Rolster",  8, 4),
                ("Fnatic",      8, 4),
                ("Cloud9",      7, 5),
                ("TSM",         5, 7),
            ]),
            "CS2": makeStandings([
                ("G2",           9, 3),
                ("Vitality",     9, 3),
                ("FaZe",         8, 4),
                ("Heroic",       8, 4),
                ("Team Spirit",  7, 5),
                ("MOUZ",         7, 5),
                ("Virtus.pro",   7, 5),
            ]),
            "Dota 2": makeStandings([
                ("Spirit",       6, 3),
                ("BetBoom",      6, 3),
                ("Falcons",      6, 3),
                ("Liquid",       5, 4),
                ("Team Secret",  5, 4),
                ("OG",           5, 4),
            ]),
        ]
    }
}
