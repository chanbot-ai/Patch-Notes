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

    private var availableFilters: [EsportsLeagueFilter] {
        let leagues = Array(Set(store.esportsMatches.map(\.league))).sorted()
        return [.top] + leagues.map(EsportsLeagueFilter.league)
    }

    private var filteredMatches: [EsportsMatch] {
        let base: [EsportsMatch]
        switch selectedFilter {
        case .top:
            base = store.esportsMatches
        case .league(let league):
            base = store.esportsMatches.filter { $0.league == league }
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
                scoresBoard
                marketPulse
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Esports")
        .navigationBarTitleDisplayMode(.inline)
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
                    FeaturedMatchCard(match: featuredMatch)
                }
            }

            ForEach(groupedSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(section.league)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("SEE ALL")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent.opacity(0.95))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(section.matches) { match in
                                CompactMatchCard(match: match)
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

private struct TeamLogoBadge: View {
    let team: String

    private var initials: String {
        let letters = team.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "T" : letters
    }

    private var colors: [Color] {
        switch team {
        case "Sentinels":
            return [Color(red: 0.84, green: 0.20, blue: 0.28), Color(red: 0.40, green: 0.07, blue: 0.09)]
        case "Paper Rex":
            return [Color(red: 0.10, green: 0.64, blue: 0.95), Color(red: 0.08, green: 0.30, blue: 0.68)]
        case "T1", "G2":
            return [Color(red: 0.95, green: 0.15, blue: 0.15), Color(red: 0.50, green: 0.04, blue: 0.04)]
        case "Gen.G", "Liquid":
            return [Color(red: 0.24, green: 0.55, blue: 0.96), Color(red: 0.10, green: 0.20, blue: 0.55)]
        case "FaZe", "Fnatic":
            return [Color(red: 0.98, green: 0.57, blue: 0.14), Color(red: 0.61, green: 0.30, blue: 0.04)]
        default:
            return [AppTheme.accentBlue, AppTheme.accent]
        }
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 20, height: 20)
            .overlay {
                Text(initials)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
    }
}
