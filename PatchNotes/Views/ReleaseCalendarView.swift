import SwiftUI

struct ReleaseCalendarView: View {
    @EnvironmentObject private var store: AppStore

    @State private var monthOffset = 0
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    private var anchorMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var selectedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: anchorMonth) ?? anchorMonth
    }

    private var releasesForMonth: [Game] {
        store.releases(forMonthContaining: selectedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = max(0, calendar.firstWeekday - 1)
        return Array(symbols[shift...]) + Array(symbols[..<shift])
    }

    private var monthDays: [Date] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: selectedMonth) else { return [] }
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth

        return monthRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var leadingPaddingCount: Int {
        guard let firstDay = monthDays.first else { return 0 }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    private var releasesByDay: [Date: [Game]] {
        Dictionary(grouping: releasesForMonth) { game in
            calendar.startOfDay(for: game.releaseDate)
        }
    }

    private var selectedDayReleases: [Game] {
        guard let selectedDay else { return [] }
        return store.releases(onDay: selectedDay)
    }

    private var selectedDayTitle: String {
        guard let selectedDay else {
            return selectedMonth.formatted(.dateTime.month(.wide).year())
        }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthPager
                monthCalendar
                monthReleaseList

                SectionHeader(
                    title: selectedDayTitle,
                    subtitle: "Tap any date to drill into full release details."
                )

                if selectedDayReleases.isEmpty {
                    emptyState
                } else {
                    ForEach(selectedDayReleases) { game in
                        ReleaseCard(game: game)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Release Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateSelectedDay()
        }
        .onChange(of: monthOffset) { _, _ in
            updateSelectedDay()
        }
    }

    private var monthPager: some View {
        GlassCard {
            HStack {
                VStack(spacing: 6) {
                    Button {
                        monthOffset = max(monthOffset - 1, 0)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.bold())
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(monthOffset > 0 ? 1.0 : 0.35))
                    .disabled(monthOffset == 0)
                    .accessibilityLabel("Previous month")

                    Text("Previous")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                VStack(spacing: 8) {
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)

                    Button {
                        jumpToToday()
                    } label: {
                        Text("Today")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.accent.opacity(0.80), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jump to current month")
                }

                Spacer()

                VStack(spacing: 6) {
                    Button {
                        monthOffset = min(monthOffset + 1, 11)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline.bold())
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(monthOffset < 11 ? 1.0 : 0.35))
                    .disabled(monthOffset == 11)
                    .accessibilityLabel("Next month")

                    Text("Next")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
    }

    private var monthCalendar: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.56))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 4) {
                ForEach(0..<leadingPaddingCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.clear)
                        .frame(height: 56)
                }

                ForEach(monthDays, id: \.self) { day in
                    let dayKey = calendar.startOfDay(for: day)
                    CalendarDayCell(
                        day: day,
                        games: releasesByDay[dayKey] ?? [],
                        isToday: calendar.isDateInToday(day),
                        isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    ) {
                        selectedDay = day
                    }
                }
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [AppTheme.surfaceTop.opacity(0.96), AppTheme.surfaceBottom.opacity(0.98)],
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

    private var monthReleaseList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Month Releases")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                if releasesForMonth.isEmpty {
                    Text("No launches in this month.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                } else {
                    ForEach(releasesForMonth) { game in
                        HStack(alignment: .top, spacing: 8) {
                            Text(game.releaseDate.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accentBlue)
                                .frame(width: 62, alignment: .leading)
                            Text(game.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No launches on this day")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Pick another date in the month grid or browse the month release agenda above.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func updateSelectedDay() {
        if let firstRelease = releasesForMonth.first {
            selectedDay = firstRelease.releaseDate
            return
        }
        selectedDay = monthDays.first
    }

    private func jumpToToday() {
        monthOffset = 0
        selectedDay = Date()
    }
}

private struct CalendarDayCell: View {
    let day: Date
    let games: [Game]
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    private var firstGameTitle: String? {
        games.first?.title
    }

    private var shouldBoostLongTitleFont: Bool {
        guard let firstGameTitle else { return false }
        return firstGameTitle.count > 14
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center) {
                    Text(day.formatted(.dateTime.day()))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.84))
                    Spacer()
                    if isToday {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 5, height: 5)
                    }
                }

                Spacer(minLength: 0)

                if let firstGame = games.first {
                    Text(firstGame.title)
                        .font(
                            .system(
                                size: shouldBoostLongTitleFont ? 10.2 : 9.0,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(2)
                        .minimumScaleFactor(shouldBoostLongTitleFont ? 0.74 : 0.88)
                        .lineSpacing(0)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .topLeading)
            .padding(5)
            .background(
                LinearGradient(
                    colors: isSelected
                    ? [AppTheme.accent.opacity(0.32), AppTheme.surfaceBottom.opacity(0.98)]
                    : [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.accent.opacity(0.70) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.month(.wide).day())): \(games.isEmpty ? "No releases" : games.map(\.title).joined(separator: ", "))")
    }
}

private struct ReleaseCard: View {
    @EnvironmentObject private var store: AppStore
    let game: Game

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    RemoteMediaImage(primaryURL: game.coverImageURL, fallbackURL: MediaFallback.gameCover)
                        .frame(width: 62, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(.headline.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                        Text("\(game.publisher) · \(game.genre)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    Spacer()
                    Text(game.releaseDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                HStack {
                    NavigationLink {
                        GameReleaseDetailView(game: game)
                    } label: {
                        HStack(spacing: 6) {
                            Text("View Details")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    }

                    Spacer()

                    Button {
                        store.toggleFavorite(game)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: store.isFavorite(game) ? "star.fill" : "star")
                            Text(store.isFavorite(game) ? "Favorited" : "Favorite")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isFavorite(game) ? "Remove favorite" : "Favorite game")
                }
            }
        }
    }
}

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

    private var galleryURLs: [URL] {
        var ordered = baseURLs

        appendYouTubeThumbnailVariants(from: baseURLs, into: &ordered)

        // Keep gallery compact while ensuring later pages still have likely-valid media.
        ordered = Array(ordered.prefix(8))

        if ordered.isEmpty {
            ordered = [MediaFallback.gameScreenshot]
        }
        return ordered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) Gallery")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            TabView {
                ForEach(galleryURLs, id: \.self) { url in
                    RemoteMediaImage(primaryURL: url, fallbackURL: MediaFallback.gameScreenshot)
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

    private func appendYouTubeThumbnailVariants(from seedURLs: [URL], into ordered: inout [URL]) {
        let variants = ["0", "1", "2", "3", "hqdefault", "mqdefault"]

        for seed in seedURLs {
            guard let id = YouTubeIDParser.videoID(from: seed) else { continue }

            for variant in variants {
                guard let variantURL = URL(string: "https://i.ytimg.com/vi/\(id)/\(variant).jpg"),
                      !ordered.contains(variantURL) else { continue }
                ordered.append(variantURL)
            }
        }
    }
}
