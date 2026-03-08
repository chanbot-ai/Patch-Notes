import Foundation

// MARK: - Config

enum PandaScoreConfig {
    static let apiKey = "BD81J2VWayLFEgbZGIdEiRLx-rThBQ19YdxMeYmXEFrkFydE4nU"
    static let baseURL = URL(string: "https://api.pandascore.co")!
}

// MARK: - Response Types

private struct PSMatch: Decodable {
    let id: Int
    let name: String?
    let status: String
    let scheduledAt: String?
    let numberOfGames: Int?
    let opponents: [PSOpponentSlot]
    let results: [PSResult]
    let streamsList: [PSStream]
    let league: PSLeague?
    let serie: PSSerie?
    let videogame: PSVideogame?
    let tournament: PSTournament?
}

private struct PSOpponentSlot: Decodable {
    let opponent: PSOpponent?
    let type: String?
}

private struct PSOpponent: Decodable {
    let id: Int
    let name: String
    let imageUrl: String?
}

private struct PSResult: Decodable {
    let teamId: Int?
    let score: Int
}

private struct PSStream: Decodable {
    let main: Bool
    let official: Bool?
    let rawUrl: String?
    let language: String?
}

private struct PSLeague: Decodable {
    let id: Int
    let name: String
    let slug: String
}

private struct PSSerie: Decodable {
    let id: Int
    let name: String?
    let fullName: String?
}

private struct PSVideogame: Decodable {
    let id: Int?
    let name: String?
    let slug: String?
}

private struct PSTournament: Decodable {
    let id: Int
    let name: String
}

private struct PSPlayer: Decodable {
    let id: Int
    let name: String
    let role: String?
    let imageUrl: String?
}

// MARK: - Service

struct PandaScoreService {
    private static let supportedGames: [String: String] = [
        "league-of-legends": "LoL",
        "valorant": "VCT",
        "cs-go": "CS2",
        "dota-2": "Dota 2"
    ]

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func fetchAllMatches() async throws -> [EsportsMatch] {
        // Generic endpoints for live/upcoming — these work fine across all games
        async let liveTask     = fetchRaw(endpoint: "matches/running",  sort: nil,            perPage: 50)
        async let upcomingTask = fetchRaw(endpoint: "matches/upcoming", sort: "scheduled_at", perPage: 50)

        // Game-specific past endpoints with finished-only filter.
        // The generic /matches/past returns mostly canceled matches; using per-game endpoints
        // with filter[status]=finished gives us actual completed results.
        async let lolPastTask   = fetchRaw(endpoint: "lol/matches/past",      sort: "-end_at", perPage: 10, statusFilter: "finished")
        async let csgoPastTask  = fetchRaw(endpoint: "csgo/matches/past",     sort: "-end_at", perPage: 10, statusFilter: "finished")
        async let valPastTask   = fetchRaw(endpoint: "valorant/matches/past", sort: "-end_at", perPage: 10, statusFilter: "finished")
        async let dota2PastTask = fetchRaw(endpoint: "dota2/matches/past",    sort: "-end_at", perPage: 10, statusFilter: "finished")

        let live      = (try? await liveTask)      ?? []
        let upcoming  = (try? await upcomingTask)  ?? []
        let lolPast   = (try? await lolPastTask)   ?? []
        let csgoPast  = (try? await csgoPastTask)  ?? []
        let valPast   = (try? await valPastTask)   ?? []
        let dota2Past = (try? await dota2PastTask) ?? []

        let all = live + upcoming + lolPast + csgoPast + valPast + dota2Past
        guard !all.isEmpty else { throw URLError(.badServerResponse) }

        return all
            .filter { ps in
                guard let slug = ps.videogame?.slug else { return false }
                return Self.supportedGames[slug] != nil
            }
            .compactMap(map(_:))
    }

    func fetchTeamPlayers(teamID: Int) async throws -> [RosterPlayer] {
        var components = URLComponents(
            url: PandaScoreConfig.baseURL.appendingPathComponent("players"),
            resolvingAgainstBaseURL: false
        )!
        // Use percent-encoded brackets — URLQueryItem would encode them again
        components.percentEncodedQuery = "per_page=10&filter%5Bteam_id%5D=\(teamID)"

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(PandaScoreConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let players = try Self.decoder.decode([PSPlayer].self, from: data)
        return players.map { p in
            RosterPlayer(
                id: p.id,
                name: p.name,
                role: p.role,
                imageURL: p.imageUrl.flatMap { URL(string: $0) }
            )
        }
    }

    // MARK: - Private

    private func fetchRaw(endpoint: String, sort: String?, perPage: Int, statusFilter: String? = nil) async throws -> [PSMatch] {
        var components = URLComponents(
            url: PandaScoreConfig.baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [URLQueryItem(name: "per_page", value: "\(perPage)")]
        if let sort { queryItems.append(URLQueryItem(name: "sort", value: sort)) }
        components.queryItems = queryItems

        // Append status filter with literal brackets — URLQueryItem would percent-encode them,
        // so we append directly to the percent-encoded query string.
        if let statusFilter {
            let existing = components.percentEncodedQuery ?? ""
            let separator = existing.isEmpty ? "" : "&"
            components.percentEncodedQuery = existing + separator + "filter%5Bstatus%5D=\(statusFilter)"
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(PandaScoreConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try Self.decoder.decode([PSMatch].self, from: data)
    }

    private func map(_ ps: PSMatch) -> EsportsMatch? {
        // Skip canceled matches — they have no meaningful result and would pollute upcoming/final lists
        guard ps.status != "canceled" else { return nil }
        guard ps.opponents.count >= 2,
              let home = ps.opponents[0].opponent,
              let away = ps.opponents[1].opponent else { return nil }

        let leagueLabel = Self.supportedGames[ps.videogame?.slug ?? ""] ?? (ps.videogame?.name ?? "Unknown")

        let homeScore = ps.results.first { $0.teamId == home.id }?.score ?? 0
        let awayScore = ps.results.first { $0.teamId == away.id }?.score ?? 0

        let state: MatchState
        switch ps.status {
        case "running":  state = .live
        case "finished": state = .final
        default:         state = .upcoming
        }

        let numberOfGames = ps.numberOfGames ?? 1
        let detailLine: String
        switch state {
        case .live:     detailLine = "LIVE"
        case .final:    detailLine = "FINAL"
        case .upcoming: detailLine = numberOfGames > 1 ? "BO\(numberOfGames)" : "BO1"
        }

        let seriesFormat: Int? = numberOfGames > 1 ? numberOfGames : nil
        let subDetail = ps.tournament?.name ?? leagueLabel
        let scheduledAt = ps.scheduledAt.flatMap(parseDate(_:))

        // Prefer main+official English stream, then any main, then first
        let stream = ps.streamsList.first { $0.main && $0.official == true && $0.language == "en" }
            ?? ps.streamsList.first(where: \.main)
            ?? ps.streamsList.first { $0.official == true }
            ?? ps.streamsList.first
        let streamURL = stream?.rawUrl.flatMap { URL(string: $0) }

        let homeLogoURL = home.imageUrl.flatMap { URL(string: $0) }
        let awayLogoURL = away.imageUrl.flatMap { URL(string: $0) }

        // Build a human-readable event name: prefer serie full_name, then name, then league name
        let serieName = ps.serie?.fullName ?? ps.serie?.name
        let leagueName = ps.league?.name
        let eventName: String? = {
            if let s = serieName, !s.isEmpty { return s }
            if let l = leagueName, !l.isEmpty { return l }
            return nil
        }()

        return EsportsMatch(
            id: UUID(),
            league: leagueLabel,
            homeTeam: home.name,
            awayTeam: away.name,
            homeRecord: "",
            awayRecord: "",
            homeScore: homeScore,
            awayScore: awayScore,
            state: state,
            detailLine: detailLine,
            subDetail: subDetail,
            isFeatured: state == .live,
            seriesFormat: seriesFormat,
            scheduledAt: scheduledAt,
            streamURL: streamURL,
            homeLogoURL: homeLogoURL,
            awayLogoURL: awayLogoURL,
            homeTeamPandaID: home.id,
            awayTeamPandaID: away.id,
            eventName: eventName
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        ]
        for format in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if let date = f.date(from: string) { return date }
        }
        return nil
    }
}
