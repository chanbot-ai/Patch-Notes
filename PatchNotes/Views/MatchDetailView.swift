import SwiftUI

struct MatchDetailView: View {
    let match: EsportsMatch

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var matchMarkets: [EsportsMarket] {
        store.esportsMarkets.filter { $0.league == match.league }
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
