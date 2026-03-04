import SwiftUI

struct GameSelectionOnboardingView: View {
    let onComplete: @MainActor (_ selectedGameIDs: [UUID]) async -> Void
    let isSaving: Bool
    let errorMessage: String?

    @State private var categories: [OnboardingCategory] = []
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var selectedGameOrder: [UUID] = []
    @State private var isLoadingCatalog = true
    @State private var catalogError: String?

    private let feedService = FeedService()
    private let minimumSelections = 3

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
        ZStack {
            DarkAuthBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    if isLoadingCatalog {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.1)
                            Text("Loading games…")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.70))
                        }
                        .padding(.top, 60)
                    } else if let catalogError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text("Failed to load games")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(catalogError)
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
                                categorySection(category)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }
                }

                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .task { loadCatalog() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick Your Games")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)

            Text("Select at least \(minimumSelections) games to personalize your feed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.70))

            Text("Your first 3 picks become badges on your profile!")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.accent.opacity(0.85))

            HStack(spacing: 6) {
                Image(systemName: selectionMet ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectionMet ? .green : .white.opacity(0.5))
                Text("\(selectedGameIDs.count) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.90))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: Capsule())
            .padding(.top, 4)
            .animation(.easeOut(duration: 0.2), value: selectedGameIDs.count)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(_ category: OnboardingCategory) -> some View {
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

    // MARK: - Game Tile

    @ViewBuilder
    private func gameTile(_ game: OnboardingGame) -> some View {
        let isSelected = selectedGameIDs.contains(game.id)

        Button {
            withAnimation(.spring(duration: 0.25)) {
                if isSelected {
                    selectedGameIDs.remove(game.id)
                    selectedGameOrder.removeAll { $0 == game.id }
                } else {
                    selectedGameIDs.insert(game.id)
                    selectedGameOrder.append(game.id)
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    // Cover image or placeholder
                    gameCover(game)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if isSelected {
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
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.accent.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 16)
            }

            Button {
                Task {
                    await onComplete(selectedGameOrder)
                }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(isSaving ? "Saving…" : "Continue")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!selectionMet || isSaving)
            .opacity(selectionMet && !isSaving ? 1.0 : 0.5)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private var selectionMet: Bool {
        selectedGameIDs.count >= minimumSelections
    }

    private func loadCatalog() {
        Task {
            isLoadingCatalog = true
            catalogError = nil
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
                catalogError = error.localizedDescription
            }
            isLoadingCatalog = false
        }
    }
}
