import SwiftUI

private struct VideoReplyNode: Identifiable, Hashable {
    let id: UUID
    let author: String
    let body: String
    let createdAt: Date
    var children: [VideoReplyNode] = []
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var settings: AppSettings

    @State private var playingClipID: ShortVideo.ID?
    @State private var discussionClip: ShortVideo?

    private var pulseTitle: String {
        let trimmed = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Your Daily Pulse" }
        return trimmed.hasSuffix("s") ? "\(trimmed)' Daily Pulse" : "\(trimmed)'s Daily Pulse"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: pulseTitle,
                    subtitle: "Curated gaming news, studio updates, and creator clips."
                )

                HomePulseOverviewCard(
                    newsCount: store.newsFeed.count,
                    clipCount: store.shortVideos.count,
                    followedGameCount: store.followedGameIDs.count,
                    unreadNotificationsCount: store.unreadNotificationsCount
                )

                HomeFeedSectionContainer(
                    title: "News Wire",
                    subtitle: "Fast headlines with a cleaner thread-like stack treatment."
                ) {
                    VStack(spacing: 10) {
                        ForEach(store.newsFeed) { item in
                            NewsCard(item: item)
                        }
                    }
                }

                HomeFeedSectionContainer(
                    title: "Vertical Video Feed",
                    subtitle: "Play in-app and open each video thread with reactions and nested replies."
                ) {
                    LazyVStack(spacing: 14) {
                        ForEach(store.shortVideos) { clip in
                            VideoReelCard(
                                clip: clip,
                                isPlaying: playingClipID == clip.id,
                                onPlayToggle: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        if playingClipID == clip.id {
                                            playingClipID = nil
                                        } else {
                                            playingClipID = clip.id
                                        }
                                    }
                                },
                                onDiscuss: {
                                    discussionClip = clip
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.bgTop, AppTheme.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [AppTheme.accentBlue.opacity(0.14), Color.clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 380
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [AppTheme.accent.opacity(0.12), Color.clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 460
                )
                .ignoresSafeArea()
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $discussionClip) { clip in
            NavigationStack {
                VideoDiscussionView(clip: clip)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct NewsCard: View {
    let item: NewsItem

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.isHot ? AppTheme.accent : AppTheme.accentBlue)
                            .frame(width: 10, height: 10)
                        Text(item.category.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if item.isHot {
                        HotBadge()
                    }
                    Spacer()

                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(RelativeTimestampFormatter.hoursAndMinutes(from: item.publishedAt))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }

                Text(item.headline)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text(item.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))

                HStack(spacing: 8) {
                    Label(item.isHot ? "Trending" : "Fresh", systemImage: item.isHot ? "flame.fill" : "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                    Spacer()
                    Text("Story")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.12), in: Capsule())
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.category) news: \(item.headline)")
    }
}

private struct VideoReelCard: View {
    let clip: ShortVideo
    let isPlaying: Bool
    let onPlayToggle: () -> Void
    let onDiscuss: () -> Void

    private var viewCountLabel: String {
        if clip.viewCount >= 1_000_000 {
            return String(format: "%.1fM", Double(clip.viewCount) / 1_000_000)
        }
        return "\(clip.viewCount / 1_000)K"
    }

    private var durationLabel: String {
        let minutes = max(Int(round(Double(clip.durationSeconds) / 60.0)), 1)
        return "\(minutes)m"
    }

    private var playerSource: EmbeddedVideoSource? {
        EmbeddedVideoSourceResolver.resolve(from: clip.videoURL)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.cardA, AppTheme.cardB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    if isPlaying, let source = playerSource {
                        EmbeddedVideoPlayer(source: source)
                    } else {
                        RemoteMediaImage(primaryURL: clip.thumbnailURL, fallbackURL: MediaFallback.videoThumbnail)
                    }
                }
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [Color.black.opacity(isPlaying ? 0.12 : 0.26), Color.black.opacity(0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles.tv.fill")
                        Text("CLIP")
                    }
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .padding(12)
                }

            Button {
                onPlayToggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel(isPlaying ? "Pause video" : "Play video")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MetricPill(icon: "play.rectangle.fill", text: clip.sourcePlatform)
                    Spacer()
                    MetricPill(icon: "clock.fill", text: durationLabel)
                }

                Spacer()

                Text(clip.title)
                    .font(.title3.weight(.heavy))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(clip.relatedGameTitles, id: \.self) { title in
                            Text(title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.30), in: Capsule())
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("@\(clip.creator)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.90))

                    MetricPill(icon: "eye.fill", text: viewCountLabel)

                    Spacer()

                    Button {
                        onDiscuss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Thread")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.accent.opacity(0.78), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open video discussion")
                }
            }
            .padding(16)
        }
        .frame(height: 270)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video clip: \(clip.title)")
        .accessibilityHint("Plays in-app with a discussion thread")
    }
}

private struct HomePulseOverviewCard: View {
    let newsCount: Int
    let clipCount: Int
    let followedGameCount: Int
    let unreadNotificationsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Pulse Board")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("A quick scan of what is loaded in your current session.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                if unreadNotificationsCount > 0 {
                    Text("\(unreadNotificationsCount) new")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.78), in: Capsule())
                }
            }

            HStack(spacing: 8) {
                HomePulseStatPill(icon: "newspaper.fill", label: "News", value: "\(newsCount)")
                HomePulseStatPill(icon: "play.rectangle.fill", label: "Clips", value: "\(clipCount)")
                HomePulseStatPill(icon: "dot.radiowaves.left.and.right", label: "Following", value: "\(followedGameCount)")
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [AppTheme.surfaceTop.opacity(0.98), AppTheme.surfaceBottom.opacity(0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct HomePulseStatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accentBlue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.64))
                Text(value)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct HomeFeedSectionContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
            }

            content
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct VideoDiscussionView: View {
    let clip: ShortVideo

    @State private var draftReply = ""
    @State private var replyTargetID: UUID?
    @State private var reactionCounts: [String: Int]
    @State private var selectedReactions: Set<String> = []
    @State private var replyTree: [VideoReplyNode]

    private let reactionOrder = ["🔥", "🎮", "😂", "💯", "🙌"]

    init(clip: ShortVideo) {
        self.clip = clip
        _reactionCounts = State(initialValue: ["🔥": 18, "🎮": 27, "😂": 8, "💯": 14, "🙌": 12])
        _replyTree = State(initialValue: [
            VideoReplyNode(
                id: UUID(),
                author: "LorePilot",
                body: "That transition at 0:18 is so clean.",
                createdAt: Date().addingTimeInterval(-5_200),
                children: [
                    VideoReplyNode(
                        id: UUID(),
                        author: "PatchWizard",
                        body: "Agreed. This is the style I want from the final launch trailer.",
                        createdAt: Date().addingTimeInterval(-4_500)
                    )
                ]
            ),
            VideoReplyNode(
                id: UUID(),
                author: "QuestPilot",
                body: "Combat looks way more fluid than the last showcase.",
                createdAt: Date().addingTimeInterval(-3_000)
            )
        ])
    }

    private var playerSource: EmbeddedVideoSource? {
        EmbeddedVideoSourceResolver.resolve(from: clip.videoURL)
    }

    private var replyingToAuthor: String? {
        guard let replyTargetID else { return nil }
        return findNode(by: replyTargetID, in: replyTree)?.author
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(0.40))
                                .frame(height: 240)

                            if let source = playerSource {
                                EmbeddedVideoPlayer(source: source)
                                    .frame(height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            } else {
                                RemoteMediaImage(primaryURL: clip.thumbnailURL, fallbackURL: MediaFallback.videoThumbnail)
                                    .frame(height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }

                        Text(clip.title)
                            .font(.title3.weight(.heavy))
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)

                        Text("@\(clip.creator) · \(clip.sourcePlatform)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(clip.relatedGameTitles, id: \.self) { title in
                                    TagChip(text: title)
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("React")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        VideoReactionBar(
                            order: reactionOrder,
                            counts: $reactionCounts,
                            selected: $selectedReactions
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reply Chain")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        if replyTree.isEmpty {
                            Text("No replies yet.")
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            ForEach(replyTree) { node in
                                VideoReplyNodeView(node: node, level: 0) { selectedNode in
                                    replyTargetID = selectedNode.id
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(replyingToAuthor == nil ? "Add Reply" : "Replying to u/\(replyingToAuthor!)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        TextField("Add your take...", text: $draftReply, axis: .vertical)
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
        .navigationTitle("Video Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func postReply() {
        let cleaned = draftReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let newReply = VideoReplyNode(
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

    private func findNode(by id: UUID, in nodes: [VideoReplyNode]) -> VideoReplyNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findNode(by: id, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func insertChild(_ reply: VideoReplyNode, under targetID: UUID, in nodes: inout [VideoReplyNode]) -> Bool {
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

private struct VideoReplyNodeView: View {
    let node: VideoReplyNode
    let level: Int
    let onReplyTap: (VideoReplyNode) -> Void

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
                VideoReplyNodeView(node: child, level: level + 1, onReplyTap: onReplyTap)
                    .padding(.leading, 14)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VideoReactionBar: View {
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
