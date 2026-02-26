import SwiftUI
import UserNotifications

struct MatchDetailView: View {
    let match: EsportsMatch

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

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
                        MatchHeaderSection(match: match)
                        TeamFormSection(match: match)
                        MatchInfoSection(match: match)
                        if !matchMarkets.isEmpty {
                            MarketsSection(markets: matchMarkets)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
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

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 8) {
                    TeamLogoBadge(team: match.awayTeam, size: 52)
                    Text(match.awayTeam)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

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

                VStack(spacing: 8) {
                    TeamLogoBadge(team: match.homeTeam, size: 52)
                    Text(match.homeTeam)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            if let url = match.streamURL {
                Link(destination: url) {
                    Label("Watch Live", systemImage: "play.tv.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.85), in: Capsule())
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

private struct TeamFormSection: View {
    let match: EsportsMatch

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Team Form")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 0) {
                    TeamFormColumn(team: match.awayTeam, record: match.awayRecord)
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                    TeamFormColumn(team: match.homeTeam, record: match.homeRecord)
                }
            }
        }
    }
}

private struct TeamFormColumn: View {
    let team: String
    let record: String

    private var form: [Bool] { recentForm(team: team, record: record) }

    var body: some View {
        VStack(spacing: 6) {
            TeamLogoBadge(team: team, size: 32)
            Text(team)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(record)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.60))
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(form[i] ? Color.green : Color.red.opacity(0.65))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private func recentForm(team: String, record: String) -> [Bool] {
    let parts = record.split(separator: "-").compactMap { Int($0) }
    let wins = parts.first ?? 0
    let losses = parts.dropFirst().first ?? 0
    let total = wins + losses
    let winRate = total > 0 ? Double(wins) / Double(total) : 0.5

    var seed = UInt64(bitPattern: Int64(truncatingIfNeeded: team.hashValue))
    func nextRand() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 33) / Double(1 << 31)
    }

    return (0..<5).map { _ in nextRand() < winRate }
}

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
                InfoRow(label: "Format", value: match.subDetail)
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
