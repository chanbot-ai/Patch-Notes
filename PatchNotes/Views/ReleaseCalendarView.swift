import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReleaseCalendarView: View {
    @EnvironmentObject private var store: AppStore

    @State private var monthOffset = 0

    private let calendar = Calendar.current

    private var anchorMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var minMonthOffset: Int {
        let currentMonth = calendar.component(.month, from: Date())
        return -(currentMonth - 1)
    }

    private var selectedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: anchorMonth) ?? anchorMonth
    }

    private var releasesForMonth: [Game] {
        store.releases(forMonthContaining: selectedMonth)
    }

    /// Releases grouped by day, sorted chronologically
    private var releasesByDay: [(date: Date, games: [Game])] {
        let grouped = Dictionary(grouping: releasesForMonth) { game in
            calendar.startOfDay(for: game.releaseDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, games: $0.value) }
    }

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthPager
                            .id("calendarTop")
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetKey.self,
                                        value: geo.frame(in: .named("calendarScroll")).minY
                                    )
                                }
                            )

                        timelineView
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "calendarScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }

                // Floating "Top" button — visible once user scrolls down past ~120pt
                if scrollOffset < -120 {
                    VStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("calendarTop", anchor: .top)
                            }
                        } label: {
                            Text("Top")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset < -120)
                }
            }
        }
        .navigationTitle("Release Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Month Pager

    private var monthPager: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset = max(monthOffset - 1, minMonthOffset)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(monthOffset > minMonthOffset ? 1.0 : 0.35))
            .disabled(monthOffset == minMonthOffset)

            Spacer()

            VStack(spacing: 6) {
                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.black))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("\(releasesForMonth.count) release\(releasesForMonth.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))

                if monthOffset != 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            monthOffset = 0
                        }
                    } label: {
                        Text("Today")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(AppTheme.accent.opacity(0.35), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppTheme.accent.opacity(0.6), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset = min(monthOffset + 1, 11)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(monthOffset < 11 ? 1.0 : 0.35))
            .disabled(monthOffset == 11)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Horizontal Timeline

    private var timelineView: some View {
        Group {
            if releasesByDay.isEmpty {
                emptyMonthView
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(releasesByDay, id: \.date) { dayGroup in
                        daySection(date: dayGroup.date, games: dayGroup.games)
                    }
                }
            }
        }
    }

    private func daySection(date: Date, games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day header
            HStack(spacing: 8) {
                Text(date.formatted(.dateTime.day()))
                    .font(.title.weight(.black))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                Text(date.formatted(.dateTime.month(.abbreviated).weekday(.abbreviated)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.50))
                    .textCase(.uppercase)

                if calendar.isDateInToday(date) {
                    Text("TODAY")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent, in: Capsule())
                }

                Spacer()
            }

            // Horizontal cover art strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        NavigationLink {
                            GameReleaseDetailView(game: game)
                        } label: {
                            TimelineCoverCard(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var emptyMonthView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.25))
            Text("No releases this month")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.50))
            Text("Try navigating to a different month.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Timeline Cover Card

private struct TimelineCoverCard: View {
    @EnvironmentObject private var store: AppStore
    let game: Game

    /// Fallback URLs: DB-stored header_image (with unique hash), then constructed patterns
    private var coverFallbackURLs: [URL] {
        var urls: [URL] = []
        // First priority: DB-stored fallback (Steam API's header_image with correct hash)
        if let fallback = game.coverImageFallbackURL {
            urls.append(fallback)
        }
        return urls
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                // No dummy fallback — if all URLs fail, show clean gradient
                RemoteMediaImage(primaryURL: game.coverImageURL, alternatePrimaryURLs: coverFallbackURLs)
                    .frame(width: 120, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
                    .overlay {
                        // Gradient for text legibility
                        LinearGradient(
                            colors: [Color.clear, Color.clear, Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                // Status badges
                HStack(spacing: 4) {
                    if store.isFollowingGame(game) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(AppTheme.accent.opacity(0.7), in: Circle())
                    }
                    if store.isFavorite(game) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.yellow)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                }
                .padding(6)
            }

            Text(game.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, alignment: .leading)

            Text(game.genre)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            // Action buttons
            HStack(spacing: 6) {
                if game.hasCommunity {
                    Button {
                        store.toggleFollowedGame(game)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: store.isFollowingGame(game) ? "dot.radiowaves.left.and.right" : "plus.circle")
                            Text(store.isFollowingGame(game) ? "Following" : "Follow")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            store.isFollowingGame(game) ? AppTheme.accent.opacity(0.25) : Color.white.opacity(0.10),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(store.isFollowingGame(game) ? 0.35 : 0.18), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.toggleFavorite(game)
                } label: {
                    Image(systemName: store.isFavorite(game) ? "star.fill" : "star")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(store.isFavorite(game) ? .yellow : .white.opacity(0.70))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - Game Release Detail View

struct GameReleaseDetailView: View {
    @EnvironmentObject private var store: AppStore

    let game: Game

    @State private var selectedClip: ShortVideo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenshotCarousel(title: game.title, coverURL: game.coverImageURL, screenshotURLs: game.screenshotURLs)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.title)
                                    .font(.title3.weight(.black))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.white)
                                Text("\(game.publisher) · \(game.genre)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.74))
                            }

                            Spacer()

                            HStack(spacing: 10) {
                                if game.hasCommunity {
                                    Button {
                                        store.toggleFollowedGame(game)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: store.isFollowingGame(game) ? "dot.radiowaves.left.and.right" : "plus.circle")
                                            Text(store.isFollowingGame(game) ? "Following" : "Follow")
                                        }
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            store.isFollowingGame(game) ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.10),
                                            in: Capsule()
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(store.isFollowingGame(game) ? "Unfollow game" : "Follow game")
                                }

                                Button {
                                    store.toggleFavorite(game)
                                } label: {
                                    Image(systemName: store.isFavorite(game) ? "star.fill" : "star")
                                        .font(.headline.bold())
                                        .foregroundStyle(store.isFavorite(game) ? .yellow : .white.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(store.isFavorite(game) ? "Remove favorite" : "Favorite game")
                            }
                        }

                        HStack(spacing: 8) {
                            MetricPill(icon: "calendar", text: game.releaseDate.formatted(date: .abbreviated, time: .omitted))
                            MetricPill(icon: "shippingbox.fill", text: game.publisher)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Review Aggregate")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        ForEach(game.reviewScores.sorted(by: { $0.value > $1.value })) { score in
                            HStack {
                                Text(score.source)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Text("\(score.value)")
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Similar Games")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(game.similarTitles, id: \.self) { title in
                                HStack(spacing: 8) {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.accentBlue)

                                    Text(title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.90))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trending Videos")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        let relatedClips = store.videos(for: game)
                        if relatedClips.isEmpty {
                            Text("No clips indexed yet. This section will auto-populate from short-form platforms.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            ForEach(relatedClips) { clip in
                                Button {
                                    selectedClip = clip
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(clip.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text("@\(clip.creator) · \(clip.sourcePlatform)")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.white.opacity(0.72))
                                        }
                                        Spacer()
                                        Image(systemName: "play.rectangle.fill")
                                            .foregroundStyle(AppTheme.accent)
                                            .font(.title3.weight(.semibold))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedClip) { clip in
            if let url = clip.videoURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Screenshot Carousel

private struct ScreenshotCarousel: View {
    let title: String
    let coverURL: URL?
    let screenshotURLs: [URL]

    private var baseURLs: [URL] {
        var ordered: [URL] = []
        if let coverURL {
            ordered.append(coverURL)
        }
        for url in screenshotURLs where !ordered.contains(url) {
            ordered.append(url)
        }
        return ordered
    }

    private var galleryPages: [[URL]] {
        var pages = baseURLs.map(candidatesForGalleryPage)
        pages = Array(pages.prefix(8))
        if pages.isEmpty {
            pages = [[MediaFallback.gameScreenshot]]
        }
        return pages
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) Gallery")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            TabView {
                ForEach(Array(galleryPages.enumerated()), id: \.offset) { _, candidates in
                    RemoteMediaImage(
                        primaryURL: candidates.first,
                        fallbackURL: MediaFallback.gameScreenshot,
                        alternatePrimaryURLs: Array(candidates.dropFirst())
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.28)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        }
                        .padding(.horizontal, 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 210)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppTheme.surfaceTop.opacity(0.97), AppTheme.surfaceBottom.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }

    private func candidatesForGalleryPage(seedURL: URL) -> [URL] {
        var ordered = [seedURL]
        appendYouTubeThumbnailVariants(for: seedURL, into: &ordered)
        return ordered
    }

    private func appendYouTubeThumbnailVariants(for seedURL: URL, into ordered: inout [URL]) {
        guard let id = YouTubeIDParser.videoID(from: seedURL) else { return }

        for variant in preferredYouTubeVariants(for: seedURL) {
            let candidateStrings = [
                "https://i.ytimg.com/vi_webp/\(id)/\(variant).webp",
                "https://i.ytimg.com/vi/\(id)/\(variant).jpg",
                "https://img.youtube.com/vi/\(id)/\(variant).jpg"
            ]

            for candidate in candidateStrings {
                guard let url = URL(string: candidate), !ordered.contains(url) else { continue }
                ordered.append(url)
            }
        }
    }

    private func preferredYouTubeVariants(for seedURL: URL) -> [String] {
        let numericVariants = ["0", "1", "2", "3"]
        let namedVariants = ["maxresdefault", "sddefault", "hq720", "hqdefault", "mqdefault", "default"]

        guard let seedVariant = youtubeThumbnailVariant(from: seedURL) else {
            return namedVariants + numericVariants
        }

        if numericVariants.contains(seedVariant) {
            return [seedVariant] + numericVariants.filter { $0 != seedVariant } + namedVariants
        }

        if namedVariants.contains(seedVariant) {
            return [seedVariant] + namedVariants.filter { $0 != seedVariant } + numericVariants
        }

        return namedVariants + numericVariants
    }

    private func youtubeThumbnailVariant(from url: URL) -> String? {
        let raw = url.deletingPathExtension().lastPathComponent
        return raw.isEmpty ? nil : raw
    }
}
