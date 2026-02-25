import SwiftUI

private enum EsportsLeagueFilter: Hashable, Identifiable {
    case top
    case league(String)

    var id: String {
        switch self {
        case .top:
            return "TOP"
        case .league(let name):
            return name
        }
    }

    var label: String {
        switch self {
        case .top:
            return "TOP"
        case .league(let name):
            return name
        }
    }
}

private struct LeagueScoreSection: Identifiable {
    let league: String
    let matches: [EsportsMatch]

    var id: String { league }
}

struct EsportsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedFilter: EsportsLeagueFilter = .top
    @State private var selectedTeam: String? = nil
    @State private var showUpcomingSheet = false
    @State private var upcomingSheetLeague = ""
    @State private var selectedMatch: EsportsMatch? = nil

    private var availableFilters: [EsportsLeagueFilter] {
        let leagues = Array(Set(store.esportsMatches.map(\.league))).sorted()
        return [.top] + leagues.map(EsportsLeagueFilter.league)
    }

    private var leagueFilteredMatches: [EsportsMatch] {
        switch selectedFilter {
        case .top:
            return store.esportsMatches
        case .league(let league):
            return store.esportsMatches.filter { $0.league == league }
        }
    }

    private var availableTeams: [String] {
        let teams = leagueFilteredMatches.flatMap { [$0.homeTeam, $0.awayTeam] }
        return Array(Set(teams)).sorted()
    }

    private var filteredMatches: [EsportsMatch] {
        var base = leagueFilteredMatches
        if let team = selectedTeam {
            base = base.filter { $0.homeTeam == team || $0.awayTeam == team }
        }
        return base.sorted { lhs, rhs in
            let lhsRank = statePriority(lhs.state)
            let rhsRank = statePriority(rhs.state)
            if lhsRank == rhsRank {
                return lhs.league < rhs.league
            }
            return lhsRank < rhsRank
        }
    }

    private var featuredMatch: EsportsMatch? {
        filteredMatches.first(where: \.isFeatured) ??
            filteredMatches.first(where: { $0.state == .live }) ??
            filteredMatches.first
    }

    private var groupedSections: [LeagueScoreSection] {
        let grouped = Dictionary(grouping: filteredMatches, by: \.league)
        return grouped.keys.sorted().map { league in
            LeagueScoreSection(league: league, matches: grouped[league] ?? [])
        }
    }

    private var tickerMatches: [EsportsMatch] {
        filteredMatches.filter { $0.state == .live || $0.state == .upcoming }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Scores",
                    subtitle: "Live game and score updates."
                )

                filterBar
                teamFilterBar
                scoresBoard
                marketPulse
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.refreshEsports()
        }
        .navigationTitle("Esports")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedFilter) { _, _ in
            selectedTeam = nil
        }
        .sheet(isPresented: $showUpcomingSheet) {
            UpcomingMatchesSheet(league: upcomingSheetLeague, matches: store.esportsMatches)
        }
        .sheet(item: $selectedMatch) { match in
            MatchDetailView(match: match)
                .environmentObject(store)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter
                                    ? AppTheme.accent.opacity(0.34)
                                    : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        selectedFilter == filter
                                            ? AppTheme.accent.opacity(0.72)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(filter.label) scores")
                }
            }
        }
    }

    private var teamFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedTeam = nil
                } label: {
                    Text("All Teams")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedTeam == nil
                                ? AppTheme.accentBlue.opacity(0.34)
                                : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    selectedTeam == nil
                                        ? AppTheme.accentBlue.opacity(0.72)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show all teams")

                ForEach(availableTeams, id: \.self) { team in
                    Button {
                        selectedTeam = team
                    } label: {
                        HStack(spacing: 5) {
                            TeamLogoBadge(team: team)
                            Text(team)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedTeam == team
                                ? AppTheme.accentBlue.opacity(0.34)
                                : Color.white.opacity(0.08),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    selectedTeam == team
                                        ? AppTheme.accentBlue.opacity(0.72)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(team) matches")
                }
            }
        }
    }

    private var scoresBoard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Scores", systemImage: "sportscourt.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.72))
                Image(systemName: "ellipsis")
                    .foregroundStyle(.white.opacity(0.72))
            }

            LiveTickerView(matches: tickerMatches)

            if let featuredMatch {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Featured Today")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                    Button {
                        selectedMatch = featuredMatch
                    } label: {
                        FeaturedMatchCard(match: featuredMatch)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(groupedSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(section.league)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            upcomingSheetLeague = section.league
                            showUpcomingSheet = true
                        } label: {
                            Text("SEE ALL")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.accent.opacity(0.95))
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(section.matches) { match in
                                Button {
                                    selectedMatch = match
                                } label: {
                                    CompactMatchCard(match: match)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.17), Color(red: 0.04, green: 0.05, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1.2)
        }
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, y: 5)
    }

    private var marketPulse: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Market Pulse")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(store.esportsMarkets.prefix(3)) { market in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(market.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                            Text("\(market.league) · $\(market.volumeUSD / 1_000)K vol")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Spacer()
                        Text(market.isLive ? "LIVE" : "OPEN")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(market.isLive ? .green : .white.opacity(0.75))
                    }
                }
            }
        }
    }

    private func statePriority(_ state: MatchState) -> Int {
        switch state {
        case .live:
            return 0
        case .upcoming:
            return 1
        case .final:
            return 2
        }
    }
}

private struct LiveTickerView: View {
    let matches: [EsportsMatch]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tickerOffset: CGFloat = 0

    private var tickerText: String {
        let rows = matches.prefix(6).map { match in
            "\(match.awayTeam) \(match.awayScore) - \(match.homeScore) \(match.homeTeam) · \(match.detailLine)"
        }
        return rows.isEmpty ? "No live matches right now" : rows.joined(separator: "     •     ")
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 36) {
                tickerTextView
                tickerTextView
            }
            .offset(x: tickerOffset)
            .onAppear {
                guard !reduceMotion else { return }
                tickerOffset = 0
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    tickerOffset = -width
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    tickerOffset = 0
                }
            }
        }
        .frame(height: 24)
        .clipped()
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .accessibilityLabel("Live ticker")
    }

    private var tickerTextView: some View {
        Text(tickerText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
    }
}

private struct FeaturedMatchCard: View {
    let match: EsportsMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            TeamScoreRow(team: match.awayTeam, record: match.awayRecord, score: match.awayScore)
            TeamScoreRow(team: match.homeTeam, record: match.homeRecord, score: match.homeScore)

            HStack {
                matchStatePill
                Spacer()
                Text(match.subDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(11)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.30), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var matchStatePill: some View {
        Text(match.detailLine)
            .font(.caption2.weight(.bold))
            .foregroundStyle(stateColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(stateColor.opacity(0.16), in: Capsule())
    }

    private var stateColor: Color {
        switch match.state {
        case .live:
            return .red
        case .upcoming:
            return AppTheme.accentBlue
        case .final:
            return .white.opacity(0.78)
        }
    }
}

private struct CompactMatchCard: View {
    let match: EsportsMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(match.detailLine)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stateColor)
                Spacer()
            }

            CompactTeamRow(team: match.awayTeam, score: match.awayScore)
            CompactTeamRow(team: match.homeTeam, score: match.homeScore)

            Text(match.subDetail)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(9)
        .frame(width: 148)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var stateColor: Color {
        switch match.state {
        case .live:
            return .red
        case .upcoming:
            return AppTheme.accentBlue
        case .final:
            return .white.opacity(0.72)
        }
    }
}

private struct TeamScoreRow: View {
    let team: String
    let record: String
    let score: Int

    var body: some View {
        HStack(spacing: 8) {
            TeamLogoBadge(team: team)
            Text(team)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(record)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text("\(score)")
                .font(.title3.weight(.black))
                .foregroundStyle(.white)
        }
    }
}

private struct CompactTeamRow: View {
    let team: String
    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            TeamLogoBadge(team: team)
            Text(team)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(1)
            Spacer()
            Text("\(score)")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        }
    }
}

private struct UpcomingMatchesSheet: View {
    let league: String
    let matches: [EsportsMatch]

    @Environment(\.dismiss) private var dismiss

    private var upcomingMatches: [EsportsMatch] {
        matches
            .filter { $0.league == league && $0.state == .upcoming && $0.scheduledAt != nil }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                    .ignoresSafeArea()

                if upcomingMatches.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.40))
                        Text("No upcoming matches scheduled")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(upcomingMatches) { match in
                                UpcomingMatchRow(match: match)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Upcoming · \(league)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct UpcomingMatchRow: View {
    let match: EsportsMatch

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today · \(Self.timeFormatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow · \(Self.timeFormatter.string(from: date))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE, MMM d"
            return "\(dayFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date))"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TeamLogoBadge(team: match.awayTeam)
                    Text(match.awayTeam)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 6) {
                    TeamLogoBadge(team: match.homeTeam)
                    Text(match.homeTeam)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let date = match.scheduledAt {
                    Text(dateLabel(for: date))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue)
                        .multilineTextAlignment(.trailing)
                }
                Text(match.subDetail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

