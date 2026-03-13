import SwiftUI
import UserNotifications

struct MatchDetailView: View {
    let match: EsportsMatch

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var homeRoster: [RosterPlayer] = []
    @State private var awayRoster: [RosterPlayer] = []
    @State private var rosterIsLoading = false
    @State private var h2hRecord: H2HRecord? = nil
    @State private var selectedPlayer: RosterPlayer? = nil
    @State private var selectedTeamInfo: SelectedTeamInfo? = nil
    @State private var selectedTournamentInfo: SelectedTournamentInfo? = nil

    private var matchMarkets: [EsportsMarket] {
        let teams: Set<String> = [match.homeTeam, match.awayTeam]
        return store.esportsMarkets.filter { market in
            market.league == match.league &&
            market.outcomes.contains { teams.contains($0.teamName) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        MatchHeaderSection(
                    match: match,
                    onTeamTap: { selectedTeamInfo = $0 },
                    onEventTap: { selectedTournamentInfo = $0 }
                )
                        if match.games.count > 1, match.state != .upcoming {
                            MapTimelineSection(match: match)
                        }
                        if let record = h2hRecord {
                            HeadToHeadSection(match: match, record: record)
                        }
                        if match.homeTeamPandaID != nil {
                            RosterSection(
                                match: match,
                                homeRoster: homeRoster,
                                awayRoster: awayRoster,
                                isLoading: rosterIsLoading,
                                onPlayerTap: { selectedPlayer = $0 }
                            )
                        }
                        MatchInfoSection(match: match)
                        if !matchMarkets.isEmpty {
                            MarketsSection(markets: matchMarkets)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .task {
                guard let homeID = match.homeTeamPandaID,
                      let awayID = match.awayTeamPandaID else { return }
                rosterIsLoading = true
                let service = PandaScoreService()
                async let homeFetch = service.fetchTeamPlayers(teamID: homeID)
                async let awayFetch = service.fetchTeamPlayers(teamID: awayID)
                async let h2hFetch = service.fetchHeadToHead(homeID: homeID, awayID: awayID)
                homeRoster = (try? await homeFetch) ?? []
                awayRoster = (try? await awayFetch) ?? []
                h2hRecord = try? await h2hFetch
                rosterIsLoading = false
            }
            .navigationDestination(item: $selectedPlayer) { player in
                PlayerDetailView(player: player, league: match.league)
            }
            .navigationDestination(item: $selectedTeamInfo) { team in
                TeamDetailView(team: team)
            }
            .navigationDestination(item: $selectedTournamentInfo) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            .navigationTitle(match.league)
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

// MARK: - Header

private struct MatchHeaderSection: View {
    let match: EsportsMatch
    var onTeamTap: ((SelectedTeamInfo) -> Void)? = nil
    var onEventTap: ((SelectedTournamentInfo) -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private func formattedSchedule(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = Self.timeFormatter.string(from: date)
        if match.state == .upcoming {
            if calendar.isDateInToday(date)     { return "Today · \(time)" }
            if calendar.isDateInTomorrow(date)  { return "Tomorrow · \(time)" }
        }
        return "\(Self.dayFormatter.string(from: date)) · \(time)"
    }

    var body: some View {
        VStack(spacing: 16) {
            if let event = match.eventName {
                Button {
                    if let tid = match.tournamentPandaID {
                        onEventTap?(SelectedTournamentInfo(id: tid, name: event, league: match.league))
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text(event)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        if match.tournamentPandaID != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .disabled(match.tournamentPandaID == nil)
            }

            if let date = match.scheduledAt {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(formattedSchedule(date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .center, spacing: 0) {
                Button {
                    onTeamTap?(SelectedTeamInfo(
                        name: match.awayTeam,
                        pandaID: match.awayTeamPandaID,
                        logoURL: match.awayLogoURL
                    ))
                } label: {
                    VStack(spacing: 8) {
                        TeamLogoBadge(team: match.awayTeam, size: 52, overrideURL: match.awayLogoURL)
                        Text(match.awayTeam)
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                VStack(spacing: 6) {
                    if match.state == .upcoming {
                        Text("VS")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(match.awayScore) – \(match.homeScore)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.5), value: match.awayScore + match.homeScore)
                    }
                    statePill
                }
                .frame(maxWidth: .infinity)

                Button {
                    onTeamTap?(SelectedTeamInfo(
                        name: match.homeTeam,
                        pandaID: match.homeTeamPandaID,
                        logoURL: match.homeLogoURL
                    ))
                } label: {
                    VStack(spacing: 8) {
                        TeamLogoBadge(team: match.homeTeam, size: 52, overrideURL: match.homeLogoURL)
                        Text(match.homeTeam)
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }

            if match.state == .live, let url = match.streamURL {
                let isTwitch = url.host?.contains("twitch.tv") == true
                Link(destination: url) {
                    HStack(spacing: 8) {
                        if isTwitch {
                            TwitchLogoMark(size: 18)
                            Text("Watch on Twitch")
                                .font(.subheadline.weight(.bold))
                        } else {
                            Image(systemName: "play.tv.fill")
                            Text("Watch Live")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isTwitch
                            ? Color(red: 0.569, green: 0.275, blue: 1.0)
                            : Color.red.opacity(0.85),
                        in: Capsule()
                    )
                }
            }

            if match.state == .upcoming, match.scheduledAt != nil {
                MatchRemindMeButton(match: match)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.20), AppTheme.surfaceBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var statePill: some View {
        Text(match.detailLine)
            .font(.caption2.weight(.bold))
            .foregroundStyle(stateColor)
            .padding(.horizontal, 10)
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

// MARK: - Team Form

// MARK: - Match Info

private struct MatchInfoSection: View {
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
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Match Info")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                InfoRow(label: "League", value: match.league)
                InfoRow(label: "Stage", value: match.subDetail)
                InfoRow(label: "Status", value: match.detailLine)

                if match.state == .upcoming, let date = match.scheduledAt {
                    InfoRow(label: "Scheduled", value: dateLabel(for: date))
                }
            }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
        }
    }
}

// MARK: - Markets

private struct MarketsSection: View {
    let markets: [EsportsMarket]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Betting Markets")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(Array(markets.enumerated()), id: \.element.id) { index, market in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(market.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                            Spacer()
                            Text("$\(market.volumeUSD / 1_000)K vol")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        ForEach(market.outcomes) { outcome in
                            OutcomeRow(outcome: outcome)
                        }
                    }
                }
            }
        }
    }
}

private struct OutcomeRow: View {
    let outcome: MarketOutcome

    var body: some View {
        HStack(spacing: 6) {
            Text(outcome.teamName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
            Spacer()
            Image(systemName: trendIcon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(trendColor)
            Text(String(format: "$%.2f", outcome.price))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var trendIcon: String {
        switch outcome.trend {
        case .up:   return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    private var trendColor: Color {
        switch outcome.trend {
        case .up:   return .green
        case .down: return .red
        case .flat: return .gray
        }
    }
}

// MARK: - Feature 7: Remind Me Button

private struct MatchRemindMeButton: View {
    let match: EsportsMatch

    @State private var reminderSet = false
    @State private var showPermissionAlert = false

    var body: some View {
        Button {
            scheduleReminder()
        } label: {
            Label(
                reminderSet ? "Reminder Set" : "Remind Me · 5 min before",
                systemImage: reminderSet ? "bell.fill" : "bell"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(reminderSet ? .yellow : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                reminderSet ? Color.yellow.opacity(0.18) : Color.white.opacity(0.12),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(reminderSet ? Color.yellow.opacity(0.40) : Color.white.opacity(0.20), lineWidth: 1)
            }
        }
        .disabled(reminderSet)
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

// MARK: - Map Timeline

private struct MapTimelineSection: View {
    let match: EsportsMatch

    // "Map" for CS2/Valorant, "Game" for LoL/Dota
    private func gameLabel(_ position: Int) -> String {
        switch match.league {
        case "CS2", "VCT": return "Map \(position)"
        default:           return "Game \(position)"
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Series Timeline")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    ForEach(match.games) { game in
                        GameRow(
                            game: game,
                            label: gameLabel(game.position),
                            homeID: match.homeTeamPandaID,
                            awayID: match.awayTeamPandaID
                        )
                        if game.id != match.games.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}

private struct GameRow: View {
    let game: MatchGame
    let label: String
    let homeID: Int?
    let awayID: Int?

    private var homeWon: Bool { homeID != nil && game.winnerID == homeID }
    private var awayWon: Bool { awayID != nil && game.winnerID == awayID }

    var body: some View {
        HStack(spacing: 10) {
            // Label
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.40))
                .frame(width: 48, alignment: .leading)

            // Away result dot (left = away, matches header layout)
            GameDot(isWinner: awayWon, status: game.status)

            // Connector
            Group {
                if game.status == .running {
                    HStack(spacing: 4) {
                        Spacer()
                        LivePulseDot().scaleEffect(0.65)
                        Text("LIVE")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                } else {
                    Rectangle()
                        .fill(game.status == .notStarted
                              ? Color.white.opacity(0.06)
                              : Color.white.opacity(0.14))
                        .frame(height: 1)
                }
            }

            // Home result dot (right = home, matches header layout)
            GameDot(isWinner: homeWon, status: game.status)

            // Duration / status
            Group {
                if let secs = game.lengthSeconds {
                    Text("\(secs / 60)m")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.35))
                } else {
                    Text(game.status == .notStarted ? "—" : "")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.18))
                }
            }
            .frame(width: 30, alignment: .trailing)
        }
    }
}

private struct GameDot: View {
    let isWinner: Bool
    let status: GameStatus

    private var fillColor: Color {
        switch status {
        case .finished:   return isWinner ? .white : .white.opacity(0.16)
        case .running:    return .white.opacity(0.35)
        case .notStarted: return .clear
        }
    }

    private var strokeColor: Color {
        status == .notStarted ? .white.opacity(0.18) : .clear
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 11, height: 11)
            .overlay {
                Circle().stroke(strokeColor, lineWidth: 1.5)
            }
    }
}

// MARK: - Head-to-Head

private struct HeadToHeadSection: View {
    let match: EsportsMatch
    let record: H2HRecord

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Head-to-Head")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                if record.totalMatches == 0 {
                    Text("No previous matchups on record.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.40))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    // Win counts — away on left, home on right (matches header layout)
                    HStack(alignment: .top) {
                        VStack(spacing: 3) {
                            Text("\(record.awayWins)")
                                .font(.system(size: 40, weight: .black))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text(match.awayTeam)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("\(record.totalMatches)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.35))
                            Text("played")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.28))
                        }
                        .padding(.top, 10)

                        VStack(spacing: 3) {
                            Text("\(record.homeWins)")
                                .font(.system(size: 40, weight: .black))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text(match.homeTeam)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Split bar
                    H2HBar(awayWins: record.awayWins, homeWins: record.homeWins, total: record.totalMatches)

                    // Recent results
                    if !record.recentResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent series")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.35))
                                .textCase(.uppercase)
                            HStack(spacing: 6) {
                                ForEach(record.recentResults.indices, id: \.self) { i in
                                    H2HResultChip(result: record.recentResults[i])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct H2HBar: View {
    let awayWins: Int
    let homeWins: Int
    let total: Int

    private var awayFraction: Double {
        total > 0 ? Double(awayWins) / Double(total) : 0.5
    }

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .red.opacity(0.65), location: max(0, awayFraction - 0.005)),
                .init(color: AppTheme.accent.opacity(0.70), location: min(1, awayFraction + 0.005))
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 7)
        .clipShape(Capsule())
    }
}

private struct H2HResultChip: View {
    let result: H2HResult

    // Displayed as away–home to match header score order
    private var homeWon: Bool { result.homeScore > result.awayScore }

    var body: some View {
        Text("\(result.awayScore)–\(result.homeScore)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                homeWon ? AppTheme.accent.opacity(0.20) : Color.red.opacity(0.18),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        homeWon ? AppTheme.accent.opacity(0.40) : Color.red.opacity(0.30),
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Rosters

private struct RosterSection: View {
    let match: EsportsMatch
    let homeRoster: [RosterPlayer]
    let awayRoster: [RosterPlayer]
    let isLoading: Bool
    let onPlayerTap: (RosterPlayer) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rosters")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        RosterColumn(
                            team: match.awayTeam,
                            players: awayRoster,
                            logoURL: match.awayLogoURL,
                            onPlayerTap: onPlayerTap
                        )
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1)
                            .padding(.vertical, 4)
                        RosterColumn(
                            team: match.homeTeam,
                            players: homeRoster,
                            logoURL: match.homeLogoURL,
                            onPlayerTap: onPlayerTap
                        )
                    }
                }
            }
        }
    }
}

private struct RosterColumn: View {
    let team: String
    let players: [RosterPlayer]
    var logoURL: URL? = nil
    let onPlayerTap: (RosterPlayer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TeamLogoBadge(team: team, size: 22, overrideURL: logoURL)
                Text(team)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if players.isEmpty {
                Text("No data available")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            } else {
                ForEach(players) { player in
                    PlayerRow(player: player, onTap: { onPlayerTap(player) })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

private struct PlayerRow: View {
    let player: RosterPlayer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                PlayerAvatar(player: player)
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let role = player.role {
                        Text(role.capitalized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct PlayerAvatar: View {
    let player: RosterPlayer

    var body: some View {
        Group {
            if let url = player.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsPlaceholder
                    }
                }
            } else {
                initialsPlaceholder
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var initialsPlaceholder: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.14))
            Text(String(player.name.prefix(1)).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.80))
        }
    }
}

// MARK: - Player Detail View

struct PlayerDetailView: View {
    let player: RosterPlayer
    let league: String

    @State private var details: PlayerDetails? = nil
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Loading player…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            } else if loadFailed {
                VStack(spacing: 14) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("Couldn't Load Player")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Player profile information is unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else if let details {
                ScrollView {
                    VStack(spacing: 20) {
                        heroSection(details: details)
                        infoSection(details: details)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
        .task {
            do {
                details = try await PandaScoreService().fetchPlayerDetails(playerID: player.id)
            } catch {
                loadFailed = true
            }
            isLoading = false
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(details: PlayerDetails) -> some View {
        VStack(spacing: 14) {
            Group {
                if let url = details.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            initialsView(name: details.name)
                        }
                    }
                } else {
                    initialsView(name: details.name)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.accent.opacity(0.55), lineWidth: 2))
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 12)

            VStack(spacing: 6) {
                Text(details.name)
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                if let first = details.firstName, let last = details.lastName,
                   !first.isEmpty, !last.isEmpty {
                    Text("\(first) \(last)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                if let role = details.role, !role.isEmpty {
                    Text(role.capitalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.35), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.20), AppTheme.surfaceBottom],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.30), lineWidth: 1)
        }
    }

    // MARK: - Info

    @ViewBuilder
    private func infoSection(details: PlayerDetails) -> some View {
        let rows: [(icon: String, label: String, value: String)] = [
            details.currentTeamName.map { ("shield.fill",       "Team",     $0) },
            details.nationality.map     { ("globe",             "Country",  $0) },
            details.age.map             { ("birthday.cake",     "Age",      "\($0)") },
            details.hometown.map        { ("location.fill",     "Hometown", $0) },
            (icon: "gamecontroller.fill", label: "Game", value: league) as (String, String, String)?,
        ].compactMap { $0 }

        if !rows.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)

                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        PlayerInfoRow(icon: row.icon, label: row.label, value: row.value)
                        if index < rows.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    private func initialsView(name: String) -> some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.22))
            Text(String(name.prefix(1)).uppercased())
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)
        }
    }
}

private struct PlayerInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent.opacity(0.80))
                .frame(width: 18)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Twitch Logo Mark

private struct TwitchLogoMark: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            // Bubble body + tail drawn in white
            Canvas { ctx, sz in
                let w = sz.width, h = sz.height
                let bodyH = h * 0.78
                let r = CGSize(width: w * 0.18, height: w * 0.18)

                // Rounded body
                let body = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: bodyH), cornerSize: r)
                ctx.fill(body, with: .foreground)

                // Bottom-left tail
                var tail = Path()
                tail.move(to:    CGPoint(x: w * 0.18, y: bodyH))
                tail.addLine(to: CGPoint(x: w * 0.18, y: h))
                tail.addLine(to: CGPoint(x: w * 0.40, y: bodyH))
                tail.closeSubpath()
                ctx.fill(tail, with: .foreground)
            }
            .foregroundStyle(.white)

            // Two vertical bar cutouts
            HStack(spacing: size * 0.11) {
                Capsule().frame(width: size * 0.10, height: size * 0.32)
                Capsule().frame(width: size * 0.10, height: size * 0.32)
            }
            .offset(y: -size * 0.07)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: size * 0.76, height: size)
    }
}
