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
    @State private var selectedStateFilter: EsportsStateFilter = .all
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    @State private var selectedTab: EsportsTab = .scores

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
        case .all:
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

    private var historyMatches: [EsportsMatch] {
        leagueFilteredMatches
            .filter { $0.state == .final }
            .sorted { lhs, rhs in
                (lhs.scheduledAt ?? .distantPast) > (rhs.scheduledAt ?? .distantPast)
            }
    }

    private var groupedHistory: [(label: String, matches: [EsportsMatch])] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"

        let grouped = Dictionary(grouping: historyMatches) { match -> Date in
            guard let date = match.scheduledAt else { return .distantPast }
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

    private var tickerMatches: [EsportsMatch] {
        filteredMatches.filter { $0.state == .live || $0.state == .upcoming }
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

    private var stateFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(EsportsStateFilter.allCases) { filter in
                Button {
                    withAnimation(.spring(duration: 0.22)) {
                        selectedStateFilter = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        if filter == .live {
                            LivePulseDot()
                                .scaleEffect(0.72)
                        } else {
                            Image(systemName: filter.systemImage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(
                                    selectedStateFilter == filter ? filter.color : .white.opacity(0.60)
                                )
                        }
                        Text(filter.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedStateFilter == filter
                            ? filter.color.opacity(0.22)
                            : Color.white.opacity(0.07),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                selectedStateFilter == filter
                                    ? filter.color.opacity(0.60)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(filter.rawValue) matches")
            }
            Spacer()
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
            LiveTickerView(matches: tickerMatches)

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
                    .buttonStyle(PressableButtonStyle())
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

// MARK: - Live Ticker

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
                if isReduced { tickerOffset = 0 }
            }
        }
        .frame(height: 24)
        .clipped()
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1) }
        .accessibilityLabel("Live ticker")
    }

    private var tickerTextView: some View {
        Text(tickerText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .lineLimit(1)
    }
}

// MARK: - Featured Match Card (Feature 1 + 3)

private struct FeaturedMatchCard: View {
    let match: EsportsMatch

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
                logoURL: match.awayLogoURL
            )
            TeamScoreRow(
                team: match.homeTeam,
                record: match.homeRecord,
                score: match.homeScore,
                isWinner: homeWon,
                seriesFormat: match.seriesFormat,
                logoURL: match.homeLogoURL
            )
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

    var body: some View {
        HStack(spacing: 8) {
            TeamLogoBadge(team: team, overrideURL: logoURL)
            Text(team)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(nameColor)
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
