import SwiftUI

struct MyGamesView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showingGameBrowser = false

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    private var followedGames: [Game] {
        store.followedGameIDs
            .compactMap { store.game(for: $0) }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    /// Split followed games into pages of 4
    private var followedGamePages: [[Game]] {
        stride(from: 0, to: followedGames.count, by: 4).map { start in
            Array(followedGames[start..<min(start + 4, followedGames.count)])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                followingSection
                librarySection
                favoritedSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle("My Games")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingGameBrowser) {
            NavigationStack {
                GameBrowserView()
                    .environmentObject(store)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            if store.followedGameIDs.isEmpty && !store.followedGamesIsLoading && store.followedGamesErrorMessage == nil {
                store.loadFollowedGames()
            }
        }
    }

    // MARK: - Following Section

    private var followingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Following",
                subtitle: "These games power your feed and game channel pills."
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        MetricPill(icon: "dot.radiowaves.left.and.right", text: "\(store.followedGameIDs.count) followed")
                        if store.followedGamesIsLoading {
                            ProgressView()
                                .scaleEffect(0.85)
                                .tint(.white.opacity(0.9))
                        }
                        Spacer()
                        Button {
                            showingGameBrowser = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                Text("Manage")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent.opacity(0.28), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage = store.followedGamesErrorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Couldn't refresh followed games.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red.opacity(0.95))
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                                .textSelection(.enabled)
                            Button("Retry") {
                                store.loadFollowedGames()
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                        }
                    } else if followedGames.isEmpty {
                        VStack(spacing: 10) {
                            Text(store.followedGamesIsLoading ? "Loading followed games..." : "No games followed yet.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.78))
                            if !store.followedGamesIsLoading {
                                Button {
                                    showingGameBrowser = true
                                } label: {
                                    Text("Browse Games")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.accent.opacity(0.28), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        followedGamesCarousel
                    }
                }
            }
        }
    }

    // MARK: - Followed Games Carousel

    private var followedGamesCarousel: some View {
        VStack(spacing: 8) {
            TabView {
                ForEach(Array(followedGamePages.enumerated()), id: \.offset) { _, page in
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(page) { game in
                            NavigationLink {
                                GameReleaseDetailView(game: game)
                            } label: {
                                FollowedGameCard(game: game)
                                    .overlay(alignment: .topTrailing) {
                                        FollowToggleButton(game: game)
                                            .padding(8)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: followedGamePages.count > 1 ? .automatic : .never))
            .frame(height: followedGamePages.count == 1 && followedGames.count <= 2 ? 180 : 360)

            if followedGamePages.count > 1 {
                Text("Swipe for more")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Your Library",
                subtitle: "Steam auth comes next. For now this is a realistic synced preview of your game shelf."
            )

            GlassCard {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.ownedGames) { game in
                        NavigationLink {
                            GameReleaseDetailView(game: game)
                        } label: {
                            OwnedGameTile(game: game, isFollowing: store.isFollowingGame(game))
                                .overlay(alignment: .topTrailing) {
                                    FollowToggleButton(game: game)
                                        .padding(10)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(game.title)")
                    }
                }
            }
        }
    }

    // MARK: - Favorited Section

    private var favoritedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Favorited Releases",
                subtitle: "Any title starred in Release Calendar appears here automatically."
            )

            GlassCard {
                if store.favoritedReleases.isEmpty {
                    Text("No favorited releases yet.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.favoritedReleases) { game in
                            NavigationLink {
                                GameReleaseDetailView(game: game)
                            } label: {
                                FavoritedGameRow(game: game)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open favorited release \(game.title)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Followed Game Card

private struct FollowedGameCard: View {
    let game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RemoteMediaImage(primaryURL: game.coverImageURL, fallbackURL: MediaFallback.gameCover)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .overlay {
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.black.opacity(0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(game.title)
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(game.genre)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Owned Game Tile

private struct OwnedGameTile: View {
    let game: Game
    let isFollowing: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RemoteMediaImage(primaryURL: game.coverImageURL, fallbackURL: MediaFallback.gameCover)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .overlay {
                    LinearGradient(
                        colors: [Color.black.opacity(0.06), Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    MetricPill(icon: "checkmark.circle.fill", text: "Owned")
                    if isFollowing {
                        MetricPill(icon: "bell.fill", text: "Following")
                    }
                }
                Spacer()
                Text(game.title)
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(game.genre)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Favorited Game Row

private struct FavoritedGameRow: View {
    let game: Game
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 10) {
            RemoteMediaImage(primaryURL: game.coverImageURL, fallbackURL: MediaFallback.gameCover)
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(game.releaseDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
            }
            Spacer()
            FollowToggleButton(game: game)
                .buttonStyle(.borderless)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.70))
        }
    }
}

// MARK: - Follow Toggle Button

private struct FollowToggleButton: View {
    @EnvironmentObject private var store: AppStore
    let game: Game

    private var isFollowing: Bool {
        store.isFollowingGame(game)
    }

    private var isBadgeGame: Bool {
        store.currentUserBadgeGameIDs.contains(game.id)
    }

    var body: some View {
        if isBadgeGame {
            HStack(spacing: 5) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                Text("Badge")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.yellow.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.yellow.opacity(0.30), lineWidth: 1)
            }
        } else {
            Button {
                store.toggleFollowedGame(game)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFollowing ? "bell.fill" : "bell")
                    Text(isFollowing ? "Following" : "Follow")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (isFollowing ? AppTheme.accent.opacity(0.28) : Color.white.opacity(0.12)),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isFollowing ? 0.45 : 0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFollowing ? "Unfollow \(game.title)" : "Follow \(game.title)")
        }
    }
}

// MARK: - Game Browser (Add/Remove Games)

struct GameBrowserView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [OnboardingCategory] = []
    @State private var isLoading = true
    @State private var loadError: String?

    private let feedService = FeedService()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let categoryOrder = [
        "Upcoming", "Award Winners", "Popular", "Classics",
        "Multiplatform", "PlayStation", "Xbox", "Nintendo", "PC"
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                    Text("Loading games…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.70))
                }
                .padding(.top, 60)
            } else if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Failed to load games")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button {
                        loadCatalog()
                    } label: {
                        Text("Retry")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 40)
                .padding(.horizontal, 16)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(category.games) { game in
                                    gameTile(game)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Browse Games")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task { loadCatalog() }
    }

    @ViewBuilder
    private func gameTile(_ game: OnboardingGame) -> some View {
        let isFollowed = store.followedGameIDs.contains(game.id)
        let isBadgeGame = store.currentUserBadgeGameIDs.contains(game.id)

        Button {
            guard !isBadgeGame else { return }
            if isFollowed {
                store.unfollowGameByID(game.id)
            } else {
                store.followGameByID(game.id, title: game.title, coverImageURL: game.coverImageURL)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    gameCover(game)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if isBadgeGame {
                                Color.black.opacity(0.35)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }

                    if isBadgeGame {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                            .padding(6)
                    } else if isFollowed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppTheme.accent)
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                            .padding(6)
                    }
                }

                Text(game.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isBadgeGame ? .white.opacity(0.55) : .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isBadgeGame ? Color.yellow.opacity(0.08) : (isFollowed ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.05)))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isBadgeGame ? Color.yellow.opacity(0.35) : (isFollowed ? AppTheme.accent.opacity(0.5) : Color.white.opacity(0.08)),
                        lineWidth: isBadgeGame || isFollowed ? 2 : 1
                    )
            }
            .scaleEffect(isFollowed ? 1.03 : 1.0)
            .animation(.spring(duration: 0.25), value: isFollowed)
        }
        .buttonStyle(.plain)
        .disabled(isBadgeGame)
    }

    @ViewBuilder
    private func gameCover(_ game: OnboardingGame) -> some View {
        if let url = game.coverImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    gamePlaceholder(game)
                default:
                    gamePlaceholder(game)
                        .overlay {
                            ProgressView()
                                .tint(.white.opacity(0.5))
                        }
                }
            }
        } else {
            gamePlaceholder(game)
        }
    }

    private func gamePlaceholder(_ game: OnboardingGame) -> some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.surfaceTop, AppTheme.surfaceBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.35))
                Text(game.genre)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.30))
                    .lineLimit(1)
            }
        }
    }

    private func loadCatalog() {
        Task {
            isLoading = true
            loadError = nil
            do {
                let rows = try await feedService.fetchOnboardingGameCatalog()
                let games = rows.map { row in
                    OnboardingGame(
                        id: row.id,
                        title: row.title,
                        coverImageURL: row.cover_image_url.flatMap(URL.init(string:)),
                        genre: row.genre ?? "Game",
                        category: row.category ?? "Other"
                    )
                }
                let grouped = Dictionary(grouping: games, by: \.category)

                var ordered: [OnboardingCategory] = []
                for name in Self.categoryOrder {
                    if let categoryGames = grouped[name], !categoryGames.isEmpty {
                        ordered.append(OnboardingCategory(name: name, games: categoryGames))
                    }
                }
                for (name, categoryGames) in grouped where !Self.categoryOrder.contains(name) {
                    ordered.append(OnboardingCategory(name: name, games: categoryGames))
                }

                categories = ordered
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }
}
