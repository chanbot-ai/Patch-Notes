import SwiftUI

struct MyGamesView: View {
    @EnvironmentObject private var store: AppStore

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
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
