import SwiftUI

private struct XPulseTweet: Identifiable, Hashable {
    let id: UUID
    let providerPostID: String
    let authorName: String
    let handle: String
    let body: String
    let createdAt: Date
    let relatedGameTitles: [String]
    let reposts: Int
    let likes: Int
    let sourceURL: URL?
}

private struct ReplyNode: Identifiable, Hashable {
    let id: UUID
    let author: String
    let body: String
    let createdAt: Date
    var children: [ReplyNode] = []
}

struct SocialView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedGameID: Game.ID?
    @State private var selectedClip: ShortVideo?
    @State private var cachedTweets: [XPulseTweet] = []
    @State private var isLoadingCachedTweets = false
    @State private var cachedTweetsErrorMessage: String?
    @State private var hasLoadedCachedTweets = false

    private let feedService = FeedService()

    private var selectedGame: Game? {
        if let selectedGameID,
           let game = store.socialGames.first(where: { $0.id == selectedGameID }) {
            return game
        }
        return store.socialGames.first
    }

    private var threads: [ThreadPost] {
        store.socialThreads(for: selectedGame?.id)
    }

    private var filteredTweets: [XPulseTweet] {
        guard let selectedGame else { return cachedTweets }
        return cachedTweets.filter { tweet in
            tweet.relatedGameTitles.contains { related in
                related.caseInsensitiveCompare(selectedGame.title) == .orderedSame
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Game Communities",
                    subtitle: "Open threads, react with emojis, and reply in nested chains."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.socialGames) { game in
                            Button {
                                selectedGameID = game.id
                            } label: {
                                HStack(spacing: 6) {
                                    Text(game.title)
                                    if store.isFollowingGame(game) {
                                        Image(systemName: "bell.fill")
                                            .font(.caption.bold())
                                    }
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    (selectedGame?.id == game.id ? AppTheme.accent.opacity(0.34) : Color.white.opacity(0.10)),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(Color.white.opacity(selectedGame?.id == game.id ? 0.45 : 0.15), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let game = selectedGame {
                    SectionHeader(
                        title: "\(game.title) Threads",
                        subtitle: "Mixed text, photo, and video threads with reactions and nested replies."
                    )

                    let clips = Array(store.videos(for: game).prefix(3))
                    if !clips.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trending Clips")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)

                                ForEach(clips) { clip in
                                    Button {
                                        selectedClip = clip
                                    } label: {
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(clip.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                Text("@\(clip.creator)")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.white.opacity(0.68))
                                            }
                                            Spacer()
                                            Image(systemName: "play.rectangle.fill")
                                                .font(.title3)
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if threads.isEmpty {
                    GlassCard {
                        Text("No threads yet for this game.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                } else {
                    ForEach(threads) { thread in
                        NavigationLink {
                            ThreadDetailView(thread: thread, gameTitle: selectedGame?.title ?? "Game")
                        } label: {
                            ThreadCard(thread: thread)
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionHeader(
                    title: "X Pulse",
                    subtitle: "Publisher and esports tweets pulled into the app for native discussion."
                )

                if isLoadingCachedTweets && !hasLoadedCachedTweets {
                    GlassCard {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Loading synced X posts...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                } else if let cachedTweetsErrorMessage {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Couldn’t load X Pulse.")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(cachedTweetsErrorMessage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                            Button {
                                Task { await loadCachedTweets(force: true) }
                            } label: {
                                Text("Retry")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.accentBlue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if filteredTweets.isEmpty {
                    GlassCard {
                        Text(hasLoadedCachedTweets ? "No synced tweets for this game yet." : "No synced tweets yet. Run syncTweets to populate the cache.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                } else {
                    ForEach(filteredTweets) { tweet in
                        NavigationLink {
                            XPulseDiscussionDestination(tweet: tweet)
                        } label: {
                            XTweetCard(tweet: tweet)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedGameID == nil {
                selectedGameID = store.socialGames.first?.id
            }
            if !hasLoadedCachedTweets && !isLoadingCachedTweets {
                Task { await loadCachedTweets() }
            }
        }
        .sheet(item: $selectedClip) { clip in
            if let url = clip.videoURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    @MainActor
    private func loadCachedTweets(force: Bool = false) async {
        if isLoadingCachedTweets { return }
        if hasLoadedCachedTweets && !force { return }

        isLoadingCachedTweets = true
        if force {
            cachedTweetsErrorMessage = nil
        }

        defer { isLoadingCachedTweets = false }

        do {
            let rows = try await feedService.fetchCachedTweets(limit: 50)
            cachedTweets = rows.map(makeXPulseTweet(from:))
            cachedTweetsErrorMessage = nil
            hasLoadedCachedTweets = true
        } catch {
            cachedTweetsErrorMessage = error.localizedDescription
            hasLoadedCachedTweets = true
            print("Failed to load cached tweets:", error)
        }
    }

    private func makeXPulseTweet(from row: FeedService.CachedTweetFeedRow) -> XPulseTweet {
        let authorHandle = (row.author_handle ?? row.source_handle).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthorName = row.author_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHandle = authorHandle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let displayName = (trimmedAuthorName?.isEmpty == false ? trimmedAuthorName : nil) ?? normalizedHandle

        return XPulseTweet(
            id: row.id,
            providerPostID: row.provider_post_id,
            authorName: displayName,
            handle: normalizedHandle,
            body: row.body,
            createdAt: row.published_at,
            relatedGameTitles: relatedGameTitles(for: row),
            reposts: row.metrics["repost_count", default: 0],
            likes: row.metrics["like_count", default: 0],
            sourceURL: row.canonical_url.flatMap(URL.init(string:))
        )
    }

    private func relatedGameTitles(for row: FeedService.CachedTweetFeedRow) -> [String] {
        let searchable = [
            row.body,
            row.author_name ?? "",
            row.author_handle ?? "",
            row.source_handle
        ]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return store.socialGames.compactMap { game in
            let normalizedTitle = game.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchable.contains(normalizedTitle) ? game.title : nil
        }
    }
}

private struct XPulseDiscussionDestination: View {
    @EnvironmentObject private var store: AppStore

    let tweet: XPulseTweet

    @State private var projectedPost: Post?
    @State private var routeResolved = false

    private let feedService = FeedService()

    var body: some View {
        Group {
            if let projectedPost {
                PostCommentsDetailView(post: projectedPost)
                    .environmentObject(store)
            } else if routeResolved {
                TweetDetailView(tweet: tweet)
            } else {
                ScrollView {
                    GlassCard {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Opening discussion")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Checking for a synced feed post...")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .navigationTitle("X Post")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: tweet.id) {
            await resolveRouteIfNeeded()
        }
    }

    @MainActor
    private func resolveRouteIfNeeded() async {
        guard !routeResolved, projectedPost == nil else { return }

        defer { routeResolved = true }

        do {
            projectedPost = try await feedService.fetchExternalSourcePost(
                provider: "twitterapi.io",
                externalID: tweet.providerPostID
            )
        } catch {
            print("Failed to resolve projected X Pulse post:", error)
        }
    }
}

private struct ThreadCard: View {
    let thread: ThreadPost

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("u/\(thread.author)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))

                    ThreadTypePill(type: thread.contentType)

                    if thread.isHot {
                        HotBadge()
                    }

                    Spacer()

                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(RelativeTimestampFormatter.hoursAndMinutes(from: thread.createdAt))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Text(thread.title)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(thread.body)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(3)

                if thread.contentType != .text {
                    ThreadCardMediaPreview(thread: thread)
                }

                HStack(spacing: 10) {
                    MetricPill(icon: "arrow.up.circle.fill", text: "\(thread.upvotes)")
                    MetricPill(icon: "bubble.left.and.bubble.right.fill", text: "\(thread.comments)")
                    Spacer()
                    Text("Tap to open")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue)
                }
            }
        }
    }
}

private struct ThreadTypePill: View {
    let type: ThreadContentType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.iconName)
            Text(type.label)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(type == .text ? Color.white.opacity(0.84) : .white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            type == .text ? Color.white.opacity(0.08) : AppTheme.accentBlue.opacity(0.30),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ThreadCardMediaPreview: View {
    let thread: ThreadPost

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(height: 180)

            switch thread.contentType {
            case .text:
                EmptyView()
            case .image:
                RemoteMediaImage(primaryURL: thread.mediaURL, fallbackURL: MediaFallback.gameScreenshot)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .video:
                RemoteMediaImage(primaryURL: thread.mediaThumbnailURL ?? thread.mediaURL, fallbackURL: MediaFallback.videoThumbnail)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 52, weight: .bold))
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

private struct ThreadDetailView: View {
    let thread: ThreadPost
    let gameTitle: String

    @State private var draftReply = ""
    @State private var replyTargetID: UUID?
    @State private var replyTree: [ReplyNode]
    @State private var reactionCounts: [String: Int]
    @State private var selectedReactions: Set<String> = []

    private let reactionOrder = ["🔥", "🎮", "😂", "🧠", "💯"]

    init(thread: ThreadPost, gameTitle: String) {
        self.thread = thread
        self.gameTitle = gameTitle
        _replyTree = State(initialValue: [
            ReplyNode(
                id: UUID(),
                author: "QuestPilot",
                body: "I tested this route and got way better loot drops.",
                createdAt: thread.createdAt.addingTimeInterval(3_900),
                children: [
                    ReplyNode(
                        id: UUID(),
                        author: "SlopeRunner",
                        body: "Same here. Also noticed better frame pacing in crowded zones.",
                        createdAt: thread.createdAt.addingTimeInterval(4_700)
                    )
                ]
            ),
            ReplyNode(
                id: UUID(),
                author: "FrameDoctor",
                body: "Try turning off motion blur first, then tune shadows.",
                createdAt: thread.createdAt.addingTimeInterval(5_400),
                children: [
                    ReplyNode(
                        id: UUID(),
                        author: "LorePilot",
                        body: "This fixed my stutter too. VRR + this setting combo helps a lot.",
                        createdAt: thread.createdAt.addingTimeInterval(6_100)
                    )
                ]
            )
        ])
        _reactionCounts = State(initialValue: ["🔥": 24, "🎮": 31, "😂": 9, "🧠": 13, "💯": 17])
    }

    private var replyingToAuthor: String? {
        guard let replyTargetID else { return nil }
        return findReplyNode(by: replyTargetID, in: replyTree)?.author
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(gameTitle.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.66))
                            Spacer()
                            ThreadTypePill(type: thread.contentType)
                        }

                        Text(thread.title)
                            .font(.title3.weight(.heavy))
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)

                        Text(thread.body)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.84))

                        if thread.contentType == .image {
                            RemoteMediaImage(primaryURL: thread.mediaURL, fallbackURL: MediaFallback.gameScreenshot)
                                .frame(height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                }
                        }

                        if thread.contentType == .video {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black.opacity(0.32))
                                    .frame(height: 230)

                                if let source = EmbeddedVideoSourceResolver.resolve(from: thread.mediaURL) {
                                    EmbeddedVideoPlayer(source: source)
                                        .frame(height: 230)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                } else {
                                    RemoteMediaImage(primaryURL: thread.mediaThumbnailURL ?? thread.mediaURL, fallbackURL: MediaFallback.videoThumbnail)
                                        .frame(height: 230)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            }
                        }

                        HStack {
                            Text("u/\(thread.author)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.74))
                            Spacer()
                            Text(RelativeTimestampFormatter.hoursAndMinutes(from: thread.createdAt))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.66))
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("React")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        ReactionBar(
                            order: reactionOrder,
                            counts: $reactionCounts,
                            selected: $selectedReactions
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Replies")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        if replyTree.isEmpty {
                            Text("No replies yet.")
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            ForEach(replyTree) { node in
                                ReplyNodeView(node: node, level: 0) { selectedNode in
                                    replyTargetID = selectedNode.id
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(replyingToAuthor == nil ? "Post a Reply" : "Replying to u/\(replyingToAuthor!)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        TextField("Share your take...", text: $draftReply, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)

                        HStack {
                            if replyTargetID != nil {
                                Button("Cancel") {
                                    replyTargetID = nil
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.82))
                            }

                            Spacer()

                            Button {
                                postReply()
                            } label: {
                                Text("Reply")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.accent.opacity(0.78), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(draftReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func postReply() {
        let cleaned = draftReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let newReply = ReplyNode(
            id: UUID(),
            author: "You",
            body: cleaned,
            createdAt: Date()
        )

        if let replyTargetID,
           insertChild(newReply, under: replyTargetID, in: &replyTree) {
            self.replyTargetID = nil
        } else {
            replyTree.insert(newReply, at: 0)
        }

        draftReply = ""
    }

    private func findReplyNode(by id: UUID, in nodes: [ReplyNode]) -> ReplyNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findReplyNode(by: id, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func insertChild(_ reply: ReplyNode, under targetID: UUID, in nodes: inout [ReplyNode]) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == targetID {
                nodes[index].children.insert(reply, at: 0)
                return true
            }
            if insertChild(reply, under: targetID, in: &nodes[index].children) {
                return true
            }
        }
        return false
    }
}

private struct ReplyNodeView: View {
    let node: ReplyNode
    let level: Int
    let onReplyTap: (ReplyNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if level > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 2)
                        .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("u/\(node.author)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text(RelativeTimestampFormatter.hoursAndMinutes(from: node.createdAt))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Text(node.body)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.86))

                    Button {
                        onReplyTap(node)
                    } label: {
                        Text("Reply")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accentBlue)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(node.children) { child in
                ReplyNodeView(node: child, level: level + 1, onReplyTap: onReplyTap)
                    .padding(.leading, 14)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct XTweetCard: View {
    let tweet: XPulseTweet

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tweet.authorName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(tweet.handle)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    Spacer()
                    Text(RelativeTimestampFormatter.hoursAndMinutes(from: tweet.createdAt))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.66))
                }

                Text(tweet.body)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))

                HStack(spacing: 10) {
                    MetricPill(icon: "arrow.triangle.2.circlepath", text: "\(tweet.reposts)")
                    MetricPill(icon: "heart.fill", text: "\(tweet.likes)")
                    Spacer()
                    Text("Tap to discuss")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue)
                }
            }
        }
    }
}

private struct TweetDetailView: View {
    let tweet: XPulseTweet

    @State private var draftComment = ""
    @State private var comments: [ReplyNode]
    @State private var reactionCounts: [String: Int]
    @State private var selectedReactions: Set<String> = []

    private let reactionOrder = ["🔥", "📰", "🎮", "👀", "💬"]

    init(tweet: XPulseTweet) {
        self.tweet = tweet
        _comments = State(initialValue: [
            ReplyNode(id: UUID(), author: "StudioWatcher", body: "This timing makes sense with the showcase schedule.", createdAt: tweet.createdAt.addingTimeInterval(2_500)),
            ReplyNode(id: UUID(), author: "PatchWizard", body: "Hoping we get more raw gameplay in the next post.", createdAt: tweet.createdAt.addingTimeInterval(4_100))
        ])
        _reactionCounts = State(initialValue: ["🔥": 12, "📰": 8, "🎮": 20, "👀": 17, "💬": 6])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tweet.authorName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("@\(tweet.handle)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            Spacer()
                            Text(RelativeTimestampFormatter.hoursAndMinutes(from: tweet.createdAt))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.66))
                        }

                        Text(tweet.body)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.86))

                        if let sourceURL = tweet.sourceURL {
                            Link(destination: sourceURL) {
                                Label("Open Original Tweet", systemImage: "link")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.accentBlue)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("React")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        ReactionBar(
                            order: reactionOrder,
                            counts: $reactionCounts,
                            selected: $selectedReactions
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Comments")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("u/\(comment.author)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.72))
                                    Spacer()
                                    Text(RelativeTimestampFormatter.hoursAndMinutes(from: comment.createdAt))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                                Text(comment.body)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.86))
                            }
                            .padding(.vertical, 4)
                        }

                        TextField("Add a comment...", text: $draftComment, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)

                        HStack {
                            Spacer()
                            Button {
                                postComment()
                            } label: {
                                Text("Comment")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.accent.opacity(0.78), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("X Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func postComment() {
        let cleaned = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        comments.insert(ReplyNode(id: UUID(), author: "You", body: cleaned, createdAt: Date()), at: 0)
        draftComment = ""
    }
}

private struct ReactionBar: View {
    let order: [String]
    @Binding var counts: [String: Int]
    @Binding var selected: Set<String>

    @State private var pulsingEmoji: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(order, id: \.self) { emoji in
                    let isSelected = selected.contains(emoji)

                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.58)) {
                            pulsingEmoji = emoji
                            toggleReaction(for: emoji)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            if pulsingEmoji == emoji {
                                pulsingEmoji = nil
                            }
                        }
                    } label: {
                        Text("\(emoji) \(counts[emoji, default: 0])")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.92))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? AppTheme.accent.opacity(0.82) : Color.white.opacity(0.12),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(isSelected ? AppTheme.accentBlue.opacity(0.85) : Color.white.opacity(0.12), lineWidth: 1)
                            }
                            .scaleEffect(pulsingEmoji == emoji ? 1.12 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("React with \(emoji)")
                }
            }
        }
    }

    private func toggleReaction(for emoji: String) {
        if selected.contains(emoji) {
            selected.remove(emoji)
            counts[emoji] = max((counts[emoji] ?? 1) - 1, 0)
        } else {
            selected.insert(emoji)
            counts[emoji, default: 0] += 1
        }
    }
}
