import SwiftUI
import UserNotifications

private enum EsportsLeagueFilter: Hashable, Identifiable {
    case top
    case league(String)

    var id: String {
        switch self {
        case .top: return "TOP"
        case .league(let name): return name
        }
    }

    var label: String {
        switch self {
        case .top: return "TOP"
        case .league(let name): return name
        }
    }
}

private struct LeagueScoreSection: Identifiable {
    let league: String
    let matches: [EsportsMatch]
    var id: String { league }
}

/// Substrings used to recognise the 20 most popular esports organisations.
/// A team name is included in the filter bar only if it contains one of these
/// keywords (case-insensitive). Each entry represents a distinct org.
private let popularOrgKeywords: [String] = [
    "T1", "Liquid", "FaZe", "Cloud9", "G2", "Fnatic",
    "Natus Vincere", "NAVI", "100 Thieves", "TSM", "Evil Geniuses",
    "NRG", "Sentinels", "Paper Rex", "Gen.G", "Loud",
    "Vitality", "MOUZ", "Heroic", "Virtus"
]

private func isPopularOrg(_ teamName: String) -> Bool {
    let lower = teamName.lowercased()
    return popularOrgKeywords.contains { lower.contains($0.lowercased()) }
}

private enum EsportsStateFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case live     = "Live"
    case upcoming = "Upcoming"
    case completed = "Final"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:       return "square.stack.fill"
        case .live:      return "antenna.radiowaves.left.and.right"
        case .upcoming:  return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all:       return .white
        case .live:      return .red
        case .upcoming:  return AppTheme.accentBlue
        case .completed: return .white.opacity(0.72)
        }
    }
}

private enum EsportsTab: Hashable {
    case scores
    case history

    var label: String {
        switch self {
        case .scores:  return "Scores"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .scores:  return "sportscourt.fill"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct EsportsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedFilter: EsportsLeagueFilter = .top
    @State private var selectedTeam: String? = nil
    @State private var showUpcomingSheet = false
    @State private var upcomingSheetLeague = ""
    @State private var selectedMatch: EsportsMatch? = nil
    @State private var showStandingsSheet = false
    @State private var standingsLeague = ""
    @State private var hasInitiallyLoaded = false
    @State private var selectedStateFilter: EsportsStateFilter? = nil
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    @State private var selectedTab: EsportsTab = .scores
    @State private var showFavoritesSheet = false
    @State private var selectedTeamInfo: SelectedTeamInfo? = nil
    @State private var selectedTournamentInfo: SelectedTournamentInfo? = nil

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

    // League + state filter combined — team filter and sorting are applied on top of this
    private var baseFilteredMatches: [EsportsMatch] {
        var base = leagueFilteredMatches
        switch selectedStateFilter {
        case .none, .all:
            break
        case .live:
            base = base.filter { $0.state == .live }
        case .upcoming:
            base = base.filter { $0.state == .upcoming }
        case .completed:
            base = base.filter { $0.state == .final }
        }
        return base
    }

    // Feature 4: favorites sorted to front; restricted to popular orgs only
    private var availableTeams: [String] {
        let teams = baseFilteredMatches.flatMap { [$0.homeTeam, $0.awayTeam] }
        let unique = Array(Set(teams)).filter(isPopularOrg)
        return unique.sorted { a, b in
            let aFav = store.isFavoriteTeam(a)
            let bFav = store.isFavoriteTeam(b)
            if aFav != bFav { return aFav }
            return a < b
        }
    }

    private var filteredMatches: [EsportsMatch] {
        var base = baseFilteredMatches
        if let team = selectedTeam {
            base = base.filter { $0.homeTeam == team || $0.awayTeam == team }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let q = trimmed.lowercased()
            base = base.filter {
                $0.homeTeam.lowercased().contains(q) || $0.awayTeam.lowercased().contains(q)
            }
        }
        return base.sorted { lhs, rhs in
            let lhsRank = statePriority(lhs.state)
            let rhsRank = statePriority(rhs.state)
            if lhsRank == rhsRank { return lhs.league < rhs.league }
            return lhsRank < rhsRank
        }
    }

    private var yourTeamsMatches: [EsportsMatch] {
        guard !store.favoriteTeams.isEmpty else { return [] }
        let calendar = Calendar.current
        let matches = store.esportsMatches.filter { match in
            guard store.isFavoriteTeam(match.homeTeam) || store.isFavoriteTeam(match.awayTeam)
            else { return false }
            switch match.state {
            case .live: return true
            case .upcoming, .final:
                guard let date = match.scheduledAt else { return false }
                return calendar.isDateInToday(date)
            }
        }
        return matches.sorted { a, b in
            func priority(_ m: EsportsMatch) -> Int {
                switch m.state {
                case .live:     return 0
                case .upcoming: return 1
                case .final:    return 2
                }
            }
            let ap = priority(a), bp = priority(b)
            if ap != bp { return ap < bp }
            return (a.scheduledAt ?? .distantPast) < (b.scheduledAt ?? .distantPast)
        }
    }

    private var groupedSections: [LeagueScoreSection] {
        let grouped = Dictionary(grouping: filteredMatches, by: \.league)
        return grouped.keys.sorted().map { league in
            LeagueScoreSection(league: league, matches: grouped[league] ?? [])
        }
    }

    private var historyMatches: [EsportsMatch] {
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        return leagueFilteredMatches
            .filter { match in
                guard match.state == .final else { return false }
                let date = match.endAt ?? match.scheduledAt
                guard let date else { return false }
                return date >= cutoff
            }
            .sorted { lhs, rhs in
                let lDate = lhs.endAt ?? lhs.scheduledAt ?? .distantPast
                let rDate = rhs.endAt ?? rhs.scheduledAt ?? .distantPast
                return lDate > rDate
            }
    }

    private var groupedHistory: [(label: String, matches: [EsportsMatch])] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"

        let grouped = Dictionary(grouping: historyMatches) { match -> Date in
            let date = match.endAt ?? match.scheduledAt ?? .distantPast
            return calendar.startOfDay(for: date)
        }

        return grouped.keys
            .sorted(by: >)
            .map { dayStart in
                let matches = grouped[dayStart] ?? []
                let label: String
                if dayStart == .distantPast              { label = "Earlier" }
                else if calendar.isDateInToday(dayStart)     { label = "Today" }
                else if calendar.isDateInYesterday(dayStart) { label = "Yesterday" }
                else                                         { label = df.string(from: dayStart) }
                return (label: label, matches: matches)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Esports", subtitle: "Scores, results, and match history.")
                filterBar
                // loading → error → empty → content
                if store.isLoadingEsports {
                    loadingIndicator
                } else if store.esportsLoadFailed {
                    errorState
                } else if store.esportsMatches.isEmpty {
                    emptyState
                } else {
                    scoresBoard
                    if selectedTab == .scores && !store.esportsMarkets.isEmpty {
                        marketPulse
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await store.refreshEsports() }
        .task {
            guard !hasInitiallyLoaded else { return }
            hasInitiallyLoaded = true
            await store.refreshEsports()
        }
        .onAppear { store.startLiveScorePolling() }
        .onDisappear { store.stopLiveScorePolling() }
        .navigationTitle("Esports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFavoritesSheet = true
                } label: {
                    Image(systemName: store.favoriteTeams.isEmpty ? "star" : "star.fill")
                        .foregroundStyle(store.favoriteTeams.isEmpty ? .white.opacity(0.72) : .yellow)
                }
            }
        }
        .sheet(isPresented: $showFavoritesSheet) {
            FavoriteTeamsSheet()
                .environmentObject(store)
        }
        .sheet(item: $selectedTeamInfo) { team in
            NavigationStack {
                TeamDetailView(team: team)
                    .environmentObject(store)
            }
            .preferredColorScheme(.dark)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedTournamentInfo) { tournament in
            NavigationStack {
                TournamentDetailView(tournament: tournament)
                    .environmentObject(store)
            }
            .preferredColorScheme(.dark)
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedFilter) { _, _ in
            withAnimation(.spring(duration: 0.25)) { selectedTeam = nil }
        }
        .onChange(of: selectedStateFilter) { _, _ in
            withAnimation(.spring(duration: 0.25)) { selectedTeam = nil }
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.spring(duration: 0.25)) {
                isSearching = false
                searchText = ""
            }
        }
        .sheet(isPresented: $showUpcomingSheet) {
            UpcomingMatchesSheet(league: upcomingSheetLeague, matches: store.esportsMatches)
        }
        .sheet(item: $selectedMatch) { match in
            MatchDetailView(match: match)
                .environmentObject(store)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStandingsSheet) {
            LeagueStandingsSheet(
                league: standingsLeague,
                standings: store.leagueStandings[standingsLeague] ?? []
            )
        }
    }

    // MARK: - Feature 2: League icon

    private func leagueSystemImage(_ league: String) -> String {
        switch league {
        case "VCT":    return "scope"
        case "LoL":    return "crown.fill"
        case "CS2":    return "dot.scope"
        case "Dota 2": return "shield.fill"
        default:       return "gamecontroller.fill"
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            if case .league(let name) = filter {
                                Image(systemName: leagueSystemImage(name))
                                    .font(.caption2.weight(.bold))
                            }
                            Text(filter.label)
                                .font(.caption.weight(.bold))
                        }
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

    // MARK: - State Filter Bar (Live / Upcoming / Final)

    private func matchCount(for filter: EsportsStateFilter) -> Int {
        switch filter {
        case .all:       return leagueFilteredMatches.count
        case .live:      return leagueFilteredMatches.filter { $0.state == .live }.count
        case .upcoming:  return leagueFilteredMatches.filter { $0.state == .upcoming }.count
        case .completed: return leagueFilteredMatches.filter { $0.state == .final }.count
        }
    }

    private var stateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([EsportsStateFilter.live, .upcoming, .completed]) { filter in
                    let count = matchCount(for: filter)
                    let isSelected = selectedStateFilter == filter
                    Button {
                        withAnimation(.spring(duration: 0.22)) {
                            selectedStateFilter = isSelected ? nil : filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if filter == .live {
                                LivePulseDot()
                                    .scaleEffect(0.72)
                            } else {
                                Image(systemName: filter.systemImage)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(isSelected ? filter.color : .white.opacity(0.60))
                            }
                            Text(filter.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(isSelected ? filter.color : .white.opacity(0.55))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        isSelected
                                            ? filter.color.opacity(0.25)
                                            : Color.white.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .animation(.spring(duration: 0.3), value: count)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? filter.color.opacity(0.22) : Color.white.opacity(0.07),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    isSelected ? filter.color.opacity(0.60) : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(isSelected ? "Deselect" : "Show") \(filter.rawValue) matches, \(count) total")
                }
            }
        }
    }

    // MARK: - Team Filter Bar (Feature 4: favorites)

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
                            if store.isFavoriteTeam(team) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
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
                    .contextMenu {
                        Button {
                            store.toggleFavoriteTeam(team)
                        } label: {
                            Label(
                                store.isFavoriteTeam(team) ? "Remove Favorite" : "Add to Favorites",
                                systemImage: store.isFavoriteTeam(team) ? "star.slash.fill" : "star.fill"
                            )
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: availableTeams)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach([EsportsTab.scores, EsportsTab.history], id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.caption2.weight(.bold))
                        Text(tab.label)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? AppTheme.accent.opacity(0.34)
                            : Color.white.opacity(0.08),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                selectedTab == tab
                                    ? AppTheme.accent.opacity(0.72)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.label) tab")
            }
            Spacer()
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if groupedHistory.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("No Recent Results")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Completed match results will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
            } else {
                ForEach(groupedHistory, id: \.label) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.label)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(group.matches.enumerated()), id: \.element.id) { index, match in
                                Button {
                                    selectedMatch = match
                                } label: {
                                    HistoryMatchRow(match: match)
                                }
                                .buttonStyle(PressableButtonStyle())

                                if index < group.matches.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Feature 9: Skeleton

    private var skeletonBoard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Scores", systemImage: "sportscourt.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in SkeletonMatchCard() }
                }
                .padding(.vertical, 4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in SkeletonMatchCard() }
                }
                .padding(.vertical, 4)
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

    // MARK: - Loading Indicator

    private var loadingIndicator: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)
            Text("Loading matches…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Feature 8: Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.25))
            Text("No Matches Right Now")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
            Text("There are no scheduled or live matches at the moment. Check back soon.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.70))
            Text("Couldn't Load Matches")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
            Text("There was a problem connecting to the scores service. Pull down to try again.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.40))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.orange.opacity(0.20), lineWidth: 1)
        }
    }

    // MARK: - Scores Board

    private var scoresBoard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isSearching {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.45))
                        TextField("Search teams…", text: $searchText)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .tint(AppTheme.accent)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.40))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Cancel") {
                        withAnimation(.spring(duration: 0.28)) {
                            isSearching = false
                            searchText = ""
                            searchFocused = false
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        ForEach([EsportsTab.scores, EsportsTab.history], id: \.self) { tab in
                            Button {
                                withAnimation(.spring(duration: 0.25)) { selectedTab = tab }
                            } label: {
                                Text(tab.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedTab == tab
                                            ? AppTheme.accent.opacity(0.34)
                                            : Color.white.opacity(0.08),
                                        in: Capsule()
                                    )
                                    .overlay {
                                        Capsule()
                                            .stroke(
                                                selectedTab == tab
                                                    ? AppTheme.accent.opacity(0.72)
                                                    : Color.white.opacity(0.10),
                                                lineWidth: 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.28)) {
                            isSearching = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            searchFocused = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .animation(.spring(duration: 0.28), value: isSearching)

            if selectedTab == .scores {
            stateFilterBar
            teamFilterBar

            if filteredMatches.isEmpty {
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                VStack(spacing: 10) {
                    Image(systemName: trimmed.isEmpty ? "sportscourt" : "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(trimmed.isEmpty
                         ? "No matches for \(selectedTeam ?? "this filter")"
                         : "No results for \"\(trimmed)\"")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            if !yourTeamsMatches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Teams")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                    if yourTeamsMatches.count == 1, let match = yourTeamsMatches.first {
                        Button { selectedMatch = match } label: {
                            FeaturedMatchCard(match: match,
                                             onTeamTap: { selectedTeamInfo = $0 },
                                             onEventTap: { selectedTournamentInfo = $0 })
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(yourTeamsMatches) { match in
                                    Button { selectedMatch = match } label: {
                                        FeaturedMatchCard(match: match,
                                                         onTeamTap: { selectedTeamInfo = $0 },
                                                         onEventTap: { selectedTournamentInfo = $0 })
                                            .containerRelativeFrame(.horizontal) { w, _ in w - 20 }
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                    }
                }
            }

            ForEach(groupedSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(section.league)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                        Spacer()
                        // Feature 6: standings button
                        if !(store.leagueStandings[section.league] ?? []).isEmpty {
                            Button {
                                standingsLeague = section.league
                                showStandingsSheet = true
                            } label: {
                                Image(systemName: "list.number")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.accentBlue.opacity(0.95))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            upcomingSheetLeague = section.league
                            showUpcomingSheet = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accent.opacity(0.95))
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            let liveMatches     = section.matches.filter { $0.state == .live }
                            let upcomingMatches = section.matches.filter { $0.state == .upcoming }
                            let finalMatches    = section.matches.filter { $0.state == .final }

                            if !liveMatches.isEmpty {
                                MatchStateGroupLabel(title: "LIVE", color: .red, isLive: true)
                                ForEach(liveMatches) { match in
                                    Button { selectedMatch = match } label: { CompactMatchCard(match: match) }
                                        .buttonStyle(PressableButtonStyle())
                                }
                            }
                            if !upcomingMatches.isEmpty {
                                MatchStateGroupLabel(title: "UPCOMING", color: AppTheme.accentBlue, isLive: false)
                                ForEach(upcomingMatches) { match in
                                    Button { selectedMatch = match } label: { CompactMatchCard(match: match) }
                                        .buttonStyle(PressableButtonStyle())
                                }
                            }
                            if !finalMatches.isEmpty {
                                MatchStateGroupLabel(title: "FINAL", color: .white.opacity(0.55), isLive: false)
                                ForEach(finalMatches) { match in
                                    Button { selectedMatch = match } label: { CompactMatchCard(match: match) }
                                        .buttonStyle(PressableButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            } else {
                historyContent
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
                Label("Market Pulse", systemImage: "chart.line.uptrend.xyaxis")
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
        case .live:     return 0
        case .upcoming: return 1
        case .final:    return 2
        }
    }
}

// MARK: - Feature 3: Series Pips

private struct SeriesPipsView: View {
    let format: Int   // 3 or 5
    let score: Int
    var color: Color = .white

    private var winsNeeded: Int { (format / 2) + 1 }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<winsNeeded, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < score ? color : color.opacity(0.22))
                    .frame(width: 7, height: 4)
            }
        }
    }
}

// MARK: - Feature 9: Skeleton Card

private struct SkeletonMatchCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("LIVE")
                    .font(.caption2.weight(.bold))
                Spacer()
            }
            HStack(spacing: 6) {
                Circle().frame(width: 20, height: 20)
                Text("Team Alpha")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("2")
                    .font(.caption.weight(.black))
            }
            HStack(spacing: 6) {
                Circle().frame(width: 20, height: 20)
                Text("Team Beta")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("1")
                    .font(.caption.weight(.black))
            }
            Text("Loading...")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(9)
        .frame(width: 148)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Featured Match Card (Feature 1 + 3)

private struct FeaturedMatchCard: View {
    let match: EsportsMatch
    var onTeamTap: ((SelectedTeamInfo) -> Void)? = nil
    var onEventTap: ((SelectedTournamentInfo) -> Void)? = nil

    private var awayWon: Bool? {
        guard match.state == .final else { return nil }
        return match.awayScore > match.homeScore
    }
    private var homeWon: Bool? {
        guard match.state == .final else { return nil }
        return match.homeScore > match.awayScore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            TeamScoreRow(
                team: match.awayTeam,
                record: match.awayRecord,
                score: match.awayScore,
                isWinner: awayWon,
                seriesFormat: match.seriesFormat,
                logoURL: match.awayLogoURL,
                onTap: onTeamTap.map { cb in {
                    cb(SelectedTeamInfo(name: match.awayTeam, pandaID: match.awayTeamPandaID, logoURL: match.awayLogoURL))
                }}
            )
            TeamScoreRow(
                team: match.homeTeam,
                record: match.homeRecord,
                score: match.homeScore,
                isWinner: homeWon,
                seriesFormat: match.seriesFormat,
                logoURL: match.homeLogoURL,
                onTap: onTeamTap.map { cb in {
                    cb(SelectedTeamInfo(name: match.homeTeam, pandaID: match.homeTeamPandaID, logoURL: match.homeLogoURL))
                }}
            )
            HStack {
                matchStatePill
                Spacer()
                if let tid = match.tournamentPandaID, let cb = onEventTap {
                    Button {
                        cb(SelectedTournamentInfo(id: tid, name: match.subDetail, league: match.league))
                    } label: {
                        HStack(spacing: 3) {
                            Text(match.subDetail)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.68))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(match.subDetail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
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
        HStack(spacing: 5) {
            if match.state == .live { LivePulseDot() }
            Text(match.detailLine)
                .font(.caption2.weight(.bold))
                .foregroundStyle(stateColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(stateColor.opacity(0.16), in: Capsule())
    }

    private var stateColor: Color {
        switch match.state {
        case .live:     return .red
        case .upcoming: return AppTheme.accentBlue
        case .final:    return .white.opacity(0.78)
        }
    }
}

// MARK: - Team Score Row (Feature 1: winner tint, Feature 3: pips)

private struct TeamScoreRow: View {
    let team: String
    let record: String
    let score: Int
    var isWinner: Bool? = nil
    var seriesFormat: Int? = nil
    var logoURL: URL? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let onTap {
                Button { onTap() } label: {
                    HStack(spacing: 6) {
                        TeamLogoBadge(team: team, overrideURL: logoURL)
                        Text(team)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(nameColor)
                    }
                }
                .buttonStyle(.plain)
            } else {
                TeamLogoBadge(team: team, overrideURL: logoURL)
                Text(team)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(nameColor)
            }
            Text(record)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            if let format = seriesFormat, format >= 3 {
                SeriesPipsView(format: format, score: score, color: scoreColor)
            }
            Text("\(score)")
                .font(.title3.weight(.black))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.5), value: score)
        }
    }

    private var nameColor: Color {
        isWinner == false ? .white.opacity(0.40) : .white
    }

    private var scoreColor: Color {
        switch isWinner {
        case .some(true):  return .green
        case .some(false): return .white.opacity(0.40)
        case .none:        return .white
        }
    }
}

// MARK: - Compact Match Card (Feature 1: winner tint)

private struct CompactMatchCard: View {
    let match: EsportsMatch

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private var awayWon: Bool? {
        guard match.state == .final else { return nil }
        return match.awayScore > match.homeScore
    }
    private var homeWon: Bool? {
        guard match.state == .final else { return nil }
        return match.homeScore > match.awayScore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if match.state == .live { LivePulseDot() }
                Text(match.detailLine)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stateColor)
                Spacer()
                if match.state == .upcoming, let date = match.scheduledAt {
                    Text(Self.timeFormatter.string(from: date))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue.opacity(0.90))
                    CompactReminderBell(match: match)
                }
            }
            CompactTeamRow(team: match.awayTeam, score: match.awayScore, isWinner: awayWon, logoURL: match.awayLogoURL)
            CompactTeamRow(team: match.homeTeam, score: match.homeScore, isWinner: homeWon, logoURL: match.homeLogoURL)
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
        case .live:     return .red
        case .upcoming: return AppTheme.accentBlue
        case .final:    return .white.opacity(0.72)
        }
    }
}

// MARK: - Compact Reminder Bell

private struct CompactReminderBell: View {
    let match: EsportsMatch

    @EnvironmentObject private var store: AppStore
    @State private var showPermissionAlert = false

    private var reminderSet: Bool { store.isReminderScheduled(for: match.notificationIdentifier) }

    var body: some View {
        Button {
            if reminderSet {
                cancelReminder()
            } else {
                scheduleReminder()
            }
        } label: {
            Image(systemName: reminderSet ? "bell.fill" : "bell")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(reminderSet ? .yellow : .white.opacity(0.45))
                .padding(4)
                .background(
                    reminderSet ? Color.yellow.opacity(0.15) : Color.clear,
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .onAppear {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let isScheduled = requests.contains { $0.identifier == match.notificationIdentifier }
                DispatchQueue.main.async {
                    if isScheduled {
                        store.markReminderScheduled(match.notificationIdentifier)
                    } else {
                        store.markReminderCancelled(match.notificationIdentifier)
                    }
                }
            }
        }
        .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to receive match reminders.")
        }
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [match.notificationIdentifier]
        )
        store.markReminderCancelled(match.notificationIdentifier)
    }

    private func scheduleReminder() {
        guard let scheduledAt = match.scheduledAt else { return }
        let fireDate = scheduledAt.addingTimeInterval(-5 * 60)
        guard fireDate > Date() else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                    showPermissionAlert = true
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        if granted { addNotification(fireDate: fireDate) }
                    }
                default:
                    addNotification(fireDate: fireDate)
                }
            }
        }
    }

    private func addNotification(fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(match.awayTeam) vs \(match.homeTeam)"
        content.body = "Match starts in 5 minutes · \(match.league)"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: match.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async { store.markReminderScheduled(match.notificationIdentifier) }
            }
        }
    }
}

// MARK: - Compact Team Row (Feature 1: winner tint)

private struct CompactTeamRow: View {
    let team: String
    let score: Int
    var isWinner: Bool? = nil
    var logoURL: URL? = nil

    var body: some View {
        HStack(spacing: 6) {
            TeamLogoBadge(team: team, overrideURL: logoURL)
            Text(team)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isWinner == false ? .white.opacity(0.40) : .white.opacity(0.90))
                .lineLimit(1)
            Spacer()
            Text("\(score)")
                .font(.caption.weight(.black))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.5), value: score)
        }
    }

    private var scoreColor: Color {
        switch isWinner {
        case .some(true):  return .green
        case .some(false): return .white.opacity(0.40)
        case .none:        return .white
        }
    }
}

// MARK: - Feature 6: League Standings Sheet

private struct LeagueStandingsSheet: View {
    let league: String
    let standings: [LeagueStanding]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()
                if standings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.40))
                        Text("No standings available")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(standings) { standing in
                                StandingRow(standing: standing)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Standings · \(league)")
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

private struct StandingRow: View {
    let standing: LeagueStanding

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(standing.rank)")
                .font(.caption.weight(.black))
                .foregroundStyle(rankColor)
                .frame(width: 28, alignment: .leading)
            TeamLogoBadge(team: standing.teamName, size: 28)
            Text(standing.teamName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(winRateColor)
                        .frame(width: geo.size.width * standing.winRate)
                }
            }
            .frame(width: 56, height: 6)
            Text(standing.record)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var rankColor: Color {
        switch standing.rank {
        case 1:  return .yellow
        case 2:  return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3:  return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .white.opacity(0.55)
        }
    }

    private var winRateColor: Color {
        if standing.winRate >= 0.7 { return .green }
        if standing.winRate >= 0.5 { return AppTheme.accentBlue }
        return .red.opacity(0.75)
    }
}

// MARK: - Match State Group Label

private struct MatchStateGroupLabel: View {
    let title: String
    let color: Color
    let isLive: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLive { LivePulseDot() }
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 0.5)
        }
    }
}

// MARK: - Feature 7: Upcoming Match Row with Remind Me

private struct UpcomingMatchRow: View {
    let match: EsportsMatch

    @State private var reminderSet = false
    @State private var showPermissionAlert = false

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
                    TeamLogoBadge(team: match.awayTeam, overrideURL: match.awayLogoURL)
                    Text(match.awayTeam)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 6) {
                    TeamLogoBadge(team: match.homeTeam, overrideURL: match.homeLogoURL)
                    Text(match.homeTeam)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let date = match.scheduledAt {
                    Text(dateLabel(for: date))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accentBlue)
                        .multilineTextAlignment(.trailing)
                }
                Text(match.subDetail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                Button {
                    scheduleReminder()
                } label: {
                    Image(systemName: reminderSet ? "bell.fill" : "bell")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(reminderSet ? .yellow : .white.opacity(0.65))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(reminderSet ? 0.14 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(reminderSet)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .onAppear {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let isScheduled = requests.contains { $0.identifier == match.notificationIdentifier }
                if isScheduled { DispatchQueue.main.async { reminderSet = true } }
            }
        }
        .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to receive match reminders.")
        }
    }

    private func scheduleReminder() {
        guard let scheduledAt = match.scheduledAt else { return }
        let fireDate = scheduledAt.addingTimeInterval(-5 * 60)
        guard fireDate > Date() else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                    showPermissionAlert = true
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        if granted { addNotification(fireDate: fireDate) }
                    }
                default:
                    addNotification(fireDate: fireDate)
                }
            }
        }
    }

    private func addNotification(fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(match.awayTeam) vs \(match.homeTeam)"
        content.body = "Match starts in 5 minutes · \(match.league)"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: match.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async { reminderSet = true }
            }
        }
    }
}

// MARK: - History Match Row

private struct HistoryMatchRow: View {
    let match: EsportsMatch

    private var awayWon: Bool { match.awayScore > match.homeScore }
    private var homeWon: Bool { match.homeScore > match.awayScore }

    var body: some View {
        HStack(spacing: 10) {
            // Game badge
            Text(match.league)
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 38, alignment: .leading)

            // Away team (right-aligned)
            HStack(spacing: 5) {
                Text(match.awayTeam)
                    .font(.caption.weight(awayWon ? .bold : .regular))
                    .foregroundStyle(awayWon ? .white : .white.opacity(0.45))
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                TeamLogoBadge(team: match.awayTeam, size: 22, overrideURL: match.awayLogoURL)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Score
            HStack(spacing: 4) {
                Text("\(match.awayScore)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(awayWon ? .green : .white.opacity(0.45))
                Text("–")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.28))
                Text("\(match.homeScore)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(homeWon ? .green : .white.opacity(0.45))
            }
            .frame(width: 56, alignment: .center)

            // Home team (left-aligned)
            HStack(spacing: 5) {
                TeamLogoBadge(team: match.homeTeam, size: 22, overrideURL: match.homeLogoURL)
                Text(match.homeTeam)
                    .font(.caption.weight(homeWon ? .bold : .regular))
                    .foregroundStyle(homeWon ? .white : .white.opacity(0.45))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Favorite Teams Sheet

private struct FavoriteTeamsSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private struct KnownTeam: Identifiable {
        let name: String
        let logoURL: URL?
        var id: String { name }
    }

    // Well-known orgs always available regardless of live match data
    private static let wellKnownOrgs: [KnownTeam] = [
        KnownTeam(name: "100 Thieves",   logoURL: nil),
        KnownTeam(name: "Astralis",      logoURL: nil),
        KnownTeam(name: "BetBoom",       logoURL: nil),
        KnownTeam(name: "Cloud9",        logoURL: nil),
        KnownTeam(name: "Complexity",    logoURL: nil),
        KnownTeam(name: "Dignitas",      logoURL: nil),
        KnownTeam(name: "DRX",           logoURL: nil),
        KnownTeam(name: "Evil Geniuses", logoURL: nil),
        KnownTeam(name: "FaZe",          logoURL: nil),
        KnownTeam(name: "Fnatic",        logoURL: nil),
        KnownTeam(name: "FURIA",         logoURL: nil),
        KnownTeam(name: "G2",            logoURL: nil),
        KnownTeam(name: "Gen.G",         logoURL: nil),
        KnownTeam(name: "Heroic",        logoURL: nil),
        KnownTeam(name: "Immortals",     logoURL: nil),
        KnownTeam(name: "KT Rolster",    logoURL: nil),
        KnownTeam(name: "Liquid",        logoURL: nil),
        KnownTeam(name: "Loud",          logoURL: nil),
        KnownTeam(name: "MIBR",          logoURL: nil),
        KnownTeam(name: "MOUZ",          logoURL: nil),
        KnownTeam(name: "Natus Vincere", logoURL: nil),
        KnownTeam(name: "NRG",           logoURL: nil),
        KnownTeam(name: "OG",            logoURL: nil),
        KnownTeam(name: "OpTic",         logoURL: nil),
        KnownTeam(name: "paiN Gaming",   logoURL: nil),
        KnownTeam(name: "Paper Rex",     logoURL: nil),
        KnownTeam(name: "Sentinels",     logoURL: nil),
        KnownTeam(name: "SK Gaming",     logoURL: nil),
        KnownTeam(name: "T1",            logoURL: nil),
        KnownTeam(name: "Team Falcons",  logoURL: nil),
        KnownTeam(name: "Team Secret",   logoURL: nil),
        KnownTeam(name: "Team Spirit",   logoURL: nil),
        KnownTeam(name: "TSM",           logoURL: nil),
        KnownTeam(name: "Virtus.pro",    logoURL: nil),
        KnownTeam(name: "Vitality",      logoURL: nil),
    ]

    private var allTeams: [KnownTeam] {
        var seen = Set<String>()
        var teams: [KnownTeam] = []
        // Live match teams first — they carry PandaScore logo URLs
        for match in store.esportsMatches {
            if seen.insert(match.homeTeam).inserted {
                teams.append(KnownTeam(name: match.homeTeam, logoURL: match.homeLogoURL))
            }
            if seen.insert(match.awayTeam).inserted {
                teams.append(KnownTeam(name: match.awayTeam, logoURL: match.awayLogoURL))
            }
        }
        // Merge in well-known orgs not already present
        for org in Self.wellKnownOrgs where seen.insert(org.name).inserted {
            teams.append(org)
        }
        return teams.sorted { a, b in
            let aFav = store.isFavoriteTeam(a.name)
            let bFav = store.isFavoriteTeam(b.name)
            if aFav != bFav { return aFav }
            return a.name < b.name
        }
    }

    private var filteredTeams: [KnownTeam] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allTeams }
        let q = trimmed.lowercased()
        return allTeams.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()

                ScrollView {
                        LazyVStack(spacing: 0) {
                            // Search bar
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white.opacity(0.40))
                                TextField("Search teams…", text: $searchText)
                                    .foregroundStyle(.white)
                                    .tint(AppTheme.accent)
                                    .focused($searchFocused)
                                    .autocorrectionDisabled()
                                if !searchText.isEmpty {
                                    Button { searchText = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white.opacity(0.35))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                            if filteredTeams.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white.opacity(0.25))
                                    Text("No results for \"\(searchText)\"")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredTeams.enumerated()), id: \.element.id) { index, team in
                                        FavoriteTeamRow(team: team.name, logoURL: team.logoURL)
                                        if index < filteredTeams.count - 1 {
                                            Divider()
                                                .background(Color.white.opacity(0.07))
                                                .padding(.leading, 58)
                                        }
                                    }
                                }
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        }
                        .animation(.spring(duration: 0.28), value: filteredTeams.map(\.id))
                    }
            }
            .navigationTitle("Favorite Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { searchFocused = false }
    }
}

private struct FavoriteTeamRow: View {
    @EnvironmentObject private var store: AppStore
    let team: String
    let logoURL: URL?

    private var isFavorite: Bool { store.isFavoriteTeam(team) }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.22)) {
                store.toggleFavoriteTeam(team)
            }
        } label: {
            HStack(spacing: 12) {
                TeamLogoBadge(team: team, size: 36, overrideURL: logoURL)

                Text(team)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.30))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Matches Sheet

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
                AppBackground().ignoresSafeArea()
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

// MARK: - Team Detail View

struct TeamDetailView: View {
    let team: SelectedTeamInfo

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var teamInfo: TeamInfo? = nil
    @State private var roster: [RosterPlayer] = []
    @State private var recentMatches: [EsportsMatch] = []
    @State private var upcomingMatches: [EsportsMatch] = []
    @State private var isLoading = true

    private var isFavorite: Bool { store.isFavoriteTeam(team.name) }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        if !recentMatches.isEmpty  { recentFormCard }
                        if !roster.isEmpty          { rosterCard }
                        if !upcomingMatches.isEmpty { upcomingCard }
                        if !recentMatches.isEmpty  { resultsCard }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        guard let pandaID = team.pandaID else { isLoading = false; return }
        let service = PandaScoreService()
        async let infoTask     = service.fetchTeamInfo(teamID: pandaID)
        async let rosterTask   = service.fetchTeamPlayers(teamID: pandaID)
        async let recentTask   = service.fetchTeamRecentMatches(teamID: pandaID)
        async let upcomingTask = service.fetchTeamUpcomingMatches(teamID: pandaID)
        teamInfo        = try? await infoTask
        roster          = (try? await rosterTask)   ?? []
        recentMatches   = (try? await recentTask)   ?? []
        upcomingMatches = (try? await upcomingTask) ?? []
        isLoading = false
    }

    private var heroCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    TeamLogoBadge(team: team.name, size: 72, overrideURL: team.logoURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                        if let acronym = teamInfo?.acronym, !acronym.isEmpty {
                            Text(acronym)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                        if let loc = teamInfo?.location, !loc.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                                Text(loc)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                    Spacer()
                }
                Button {
                    withAnimation(.spring(duration: 0.22)) { store.toggleFavoriteTeam(team.name) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .contentTransition(.symbolEffect(.replace))
                        Text(isFavorite ? "Favorited" : "Add to Favorites")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isFavorite ? Color.yellow.opacity(0.15) : Color.white.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isFavorite ? Color.yellow.opacity(0.30) : Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentFormCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT FORM")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(1)
                HStack(spacing: 6) {
                    ForEach(Array(recentMatches.prefix(5).enumerated()), id: \.offset) { _, match in
                        let teamIsHome = match.homeTeam == team.name
                        let won = teamIsHome ? match.homeScore > match.awayScore
                                             : match.awayScore > match.homeScore
                        Text(won ? "W" : "L")
                            .font(.caption.weight(.black))
                            .foregroundStyle(won ? .green : .red)
                            .frame(width: 28, height: 28)
                            .background(
                                won ? Color.green.opacity(0.18) : Color.red.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    Spacer()
                    let last10 = recentMatches.prefix(10)
                    let wins = last10.filter { m in
                        m.homeTeam == team.name ? m.homeScore > m.awayScore : m.awayScore > m.homeScore
                    }.count
                    let total = last10.count
                    Text("\(wins)–\(total - wins) last \(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var rosterCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("ROSTER")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(1)
                VStack(spacing: 10) {
                    ForEach(roster) { player in
                        HStack(spacing: 12) {
                            Group {
                                if let url = player.imageURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img): img.resizable().scaledToFill()
                                        default: Text(String(player.name.prefix(1)))
                                                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                                        }
                                    }
                                } else {
                                    Text(String(player.name.prefix(1)))
                                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.10), in: Circle())
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                if let role = player.role {
                                    Text(role.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.50))
                                }
                            }
                            Spacer()
                        }
                        if player.id != roster.last?.id {
                            Divider().background(Color.white.opacity(0.07))
                        }
                    }
                }
            }
        }
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1)
                .padding(.horizontal, 2)
            VStack(spacing: 0) {
                ForEach(Array(upcomingMatches.enumerated()), id: \.element.id) { i, match in
                    TeamScheduleRow(match: match, teamName: team.name)
                    if i < upcomingMatches.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                    }
                }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 1) }
        }
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT RESULTS")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1)
                .padding(.horizontal, 2)
            VStack(spacing: 0) {
                ForEach(Array(recentMatches.enumerated()), id: \.element.id) { i, match in
                    TeamResultRow(match: match, teamName: team.name)
                    if i < recentMatches.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                    }
                }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 1) }
        }
    }
}

private struct TeamScheduleRow: View {
    let match: EsportsMatch
    let teamName: String

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()

    private var opponent:       String { match.homeTeam == teamName ? match.awayTeam   : match.homeTeam }
    private var opponentLogoURL: URL?  { match.homeTeam == teamName ? match.awayLogoURL : match.homeLogoURL }

    var body: some View {
        HStack(spacing: 12) {
            TeamLogoBadge(team: opponent, size: 28, overrideURL: opponentLogoURL)
            VStack(alignment: .leading, spacing: 2) {
                Text("vs \(opponent)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let date = match.scheduledAt {
                    let cal  = Calendar.current
                    let time = Self.timeFormatter.string(from: date)
                    let day  = cal.isDateInToday(date)     ? "Today"
                             : cal.isDateInTomorrow(date)  ? "Tomorrow"
                             : Self.dayFormatter.string(from: date)
                    Text("\(day) · \(time)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            Spacer()
            Text(match.league)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.50))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// MARK: - Tournament Detail View

struct TournamentDetailView: View {
    let tournament: SelectedTournamentInfo

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var info: TournamentInfo? = nil
    @State private var rounds: [BracketRound] = []
    @State private var isLoading = true
    @State private var selectedMatch: EsportsMatch? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        if rounds.isEmpty {
                            emptyBracket
                        } else {
                            ForEach(rounds) { round in
                                roundSection(round)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.foregroundStyle(AppTheme.accent)
            }
        }
        .task { await loadData() }
        .sheet(item: $selectedMatch) { match in
            MatchDetailView(match: match)
                .environmentObject(store)
                .presentationDragIndicator(.visible)
        }
    }

    private func loadData() async {
        let service = PandaScoreService()
        async let infoTask   = service.fetchTournamentInfo(tournamentID: tournament.id)
        async let roundsTask = service.fetchTournamentBracket(tournamentID: tournament.id)
        info   = try? await infoTask
        rounds = (try? await roundsTask) ?? []
        isLoading = false
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tournament.name)
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                        Text(tournament.league)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                    Text(tournament.league)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                if info?.beginAt != nil || info?.prizepool != nil {
                    Divider().background(Color.white.opacity(0.08))
                    HStack(spacing: 16) {
                        if let begin = info?.beginAt, let end = info?.endAt {
                            Label(
                                "\(Self.dateFormatter.string(from: begin)) – \(Self.dateFormatter.string(from: end))",
                                systemImage: "calendar"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        } else if let begin = info?.beginAt {
                            Label(Self.dateFormatter.string(from: begin), systemImage: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        if let prize = info?.prizepool, !prize.isEmpty {
                            Label(prize, systemImage: "trophy.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accent.opacity(0.90))
                        }
                    }
                }
            }
        }
    }

    private func roundSection(_ round: BracketRound) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(round.name.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(round.isFinal ? AppTheme.accent : .white.opacity(0.50))
                    .tracking(1)
                if round.isFinal {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(round.matches.enumerated()), id: \.element.id) { i, match in
                    Button { selectedMatch = match } label: {
                        BracketMatchRow(match: match)
                    }
                    .buttonStyle(PressableButtonStyle())
                    if i < round.matches.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 12)
                    }
                }
            }
            .background(
                round.isFinal
                    ? AppTheme.accent.opacity(0.08)
                    : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        round.isFinal ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.09),
                        lineWidth: 1
                    )
            }
        }
    }

    private var emptyBracket: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.20))
            Text("Bracket not yet available")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text("Check back once the tournament begins.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.30))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Bracket Match Row

private struct BracketMatchRow: View {
    let match: EsportsMatch

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()

    private var awayWon: Bool? {
        guard match.state == .final else { return nil }
        return match.awayScore > match.homeScore
    }
    private var homeWon: Bool? {
        guard match.state == .final else { return nil }
        return match.homeScore > match.awayScore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if match.state == .live { LivePulseDot() }
                Text(match.state == .upcoming
                     ? (match.scheduledAt.map { Self.timeFormatter.string(from: $0) } ?? "TBD")
                     : match.detailLine)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stateColor)
                Spacer()
                if let fmt = match.seriesFormat {
                    Text("BO\(fmt)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            BracketTeamRow(
                team: match.awayTeam, score: match.awayScore,
                logoURL: match.awayLogoURL, isWinner: awayWon,
                isUpcoming: match.state == .upcoming
            )
            BracketTeamRow(
                team: match.homeTeam, score: match.homeScore,
                logoURL: match.homeLogoURL, isWinner: homeWon,
                isUpcoming: match.state == .upcoming
            )
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var stateColor: Color {
        switch match.state {
        case .live:     return .red
        case .upcoming: return AppTheme.accentBlue
        case .final:    return .white.opacity(0.55)
        }
    }
}

private struct BracketTeamRow: View {
    let team: String
    let score: Int
    let logoURL: URL?
    let isWinner: Bool?
    let isUpcoming: Bool

    private var nameColor: Color { isWinner == false ? .white.opacity(0.38) : .white }
    private var scoreColor: Color {
        switch isWinner {
        case .some(true):  return .green
        case .some(false): return .white.opacity(0.38)
        case .none:        return .white
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            TeamLogoBadge(team: team, size: 22, overrideURL: logoURL)
            Text(team)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(nameColor)
                .lineLimit(1)
            Spacer()
            if isUpcoming {
                Text("–")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                Text("\(score)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(scoreColor)
                    .contentTransition(.numericText())
            }
        }
    }
}

private struct TeamResultRow: View {
    let match: EsportsMatch
    let teamName: String

    private var teamIsHome:      Bool   { match.homeTeam == teamName }
    private var teamScore:       Int    { teamIsHome ? match.homeScore    : match.awayScore }
    private var opponentScore:   Int    { teamIsHome ? match.awayScore    : match.homeScore }
    private var won:             Bool   { teamScore > opponentScore }
    private var opponent:        String { teamIsHome ? match.awayTeam     : match.homeTeam }
    private var opponentLogoURL: URL?   { teamIsHome ? match.awayLogoURL  : match.homeLogoURL }

    var body: some View {
        HStack(spacing: 10) {
            Text(won ? "W" : "L")
                .font(.caption2.weight(.black))
                .foregroundStyle(won ? .green : .red)
                .frame(width: 22, height: 22)
                .background(
                    won ? Color.green.opacity(0.18) : Color.red.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 5)
                )
            TeamLogoBadge(team: opponent, size: 26, overrideURL: opponentLogoURL)
            Text(opponent)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(teamScore)–\(opponentScore)")
                .font(.caption.weight(.black))
                .foregroundStyle(won ? .green : .white.opacity(0.55))
            Text(match.league)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.50))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}
