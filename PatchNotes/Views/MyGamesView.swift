import SwiftUI

struct MyGamesView: View {
    @EnvironmentObject private var store: AppStore

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    private var followedGames: [Game] {
        store.followedGameIDs
            .compactMap { store.game(for: $0) }
            .sorted { lhs, rhs in
                if lhs.releaseDate != rhs.releaseDate {
                    return lhs.releaseDate < rhs.releaseDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var unresolvedFollowedGameCount: Int {
        max(store.followedGameIDs.count - followedGames.count, 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(
                        title: "Following Feed Sources",
                        subtitle: "These games power your Following tab in the social feed."
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                MetricPill(icon: "dot.radiowaves.left.and.right", text: "\(store.followedGameIDs.count) followed")
                                if store.followedGamesIsLoading {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                        .tint(.white.opacity(0.9))
                                }
                            }

                            if let errorMessage = store.followedGamesErrorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Couldn’t refresh followed games.")
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
                                Text(store.followedGamesIsLoading ? "Loading followed games..." : "Follow games in Release Calendar to personalize your Following feed.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.78))
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(followedGames) { game in
                                        NavigationLink {
                                            GameReleaseDetailView(game: game)
                                        } label: {
                                            FavoritedGameRow(game: game)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Open followed game \(game.title)")
                                    }
                                }
                            }

                            if unresolvedFollowedGameCount > 0 {
                                Text("\(unresolvedFollowedGameCount) followed \(unresolvedFollowedGameCount == 1 ? "game is" : "games are") not in the local catalog yet and will appear after feed/calendar sync.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                }

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
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle("My Games")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.followedGameIDs.isEmpty && !store.followedGamesIsLoading && store.followedGamesErrorMessage == nil {
                store.loadFollowedGames()
            }
        }
    }
}

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

private struct FollowToggleButton: View {
    @EnvironmentObject private var store: AppStore
    let game: Game

    private var isFollowing: Bool {
        store.isFollowingGame(game)
    }

    var body: some View {
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
