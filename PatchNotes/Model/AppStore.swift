import Foundation

protocol AppDataProviding {
    func makeSeedData(referenceDate: Date) -> AppSeedData
}

struct MockAppDataProvider: AppDataProviding {
    func makeSeedData(referenceDate: Date) -> AppSeedData {
        AppSeedData(referenceDate: referenceDate)
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var ownedGames: [Game]
    @Published private(set) var upcomingReleases: [Game]
    @Published private(set) var favoriteReleaseIDs: Set<Game.ID>
    @Published private(set) var newsFeed: [NewsItem]
    @Published private(set) var shortVideos: [ShortVideo]
    @Published private(set) var esportsMatches: [EsportsMatch]
    @Published private(set) var esportsMarkets: [EsportsMarket]

    private var threadsByGame: [Game.ID: [ThreadPost]]
    private let calendar = Calendar.current
    private let dataProvider: AppDataProviding

    init(
        dataProvider: AppDataProviding = MockAppDataProvider(),
        referenceDate: Date = Date()
    ) {
        self.dataProvider = dataProvider
        self.ownedGames = []
        self.upcomingReleases = []
        self.favoriteReleaseIDs = []
        self.newsFeed = []
        self.shortVideos = []
        self.esportsMatches = []
        self.esportsMarkets = []
        self.threadsByGame = [:]
        refresh(referenceDate: referenceDate)
    }

    var favoritedReleases: [Game] {
        upcomingReleases
            .filter { favoriteReleaseIDs.contains($0.id) }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    var socialGames: [Game] {
        var seen = Set<Game.ID>()
        let candidates = ownedGames + favoritedReleases + Array(upcomingReleases.prefix(6))
        return candidates.filter { game in
            seen.insert(game.id).inserted
        }
    }

    func toggleFavorite(_ game: Game) {
        if favoriteReleaseIDs.contains(game.id) {
            favoriteReleaseIDs.remove(game.id)
        } else {
            favoriteReleaseIDs.insert(game.id)
        }
    }

    func isFavorite(_ game: Game) -> Bool {
        favoriteReleaseIDs.contains(game.id)
    }

    func releases(forMonthContaining date: Date) -> [Game] {
        upcomingReleases
            .filter {
                calendar.isDate($0.releaseDate, equalTo: date, toGranularity: .month) &&
                calendar.isDate($0.releaseDate, equalTo: date, toGranularity: .year)
            }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    func releases(onDay date: Date) -> [Game] {
        upcomingReleases
            .filter { calendar.isDate($0.releaseDate, inSameDayAs: date) }
            .sorted { $0.releaseDate < $1.releaseDate }
    }

    func socialThreads(for gameID: Game.ID?) -> [ThreadPost] {
        guard let gameID else { return [] }
        return (threadsByGame[gameID] ?? [])
            .sorted { lhs, rhs in
                if lhs.hotScore == rhs.hotScore {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.hotScore > rhs.hotScore
            }
    }

    func videos(for game: Game) -> [ShortVideo] {
        shortVideos
            .filter { clip in
                clip.relatedGameTitles.contains(where: { $0.caseInsensitiveCompare(game.title) == .orderedSame })
            }
            .prefix(6)
            .map { $0 }
    }

    func refresh(referenceDate: Date = Date()) {
        let seed = dataProvider.makeSeedData(referenceDate: referenceDate)
        ownedGames = seed.ownedGames
        upcomingReleases = seed.upcomingReleases
        newsFeed = seed.newsFeed
        shortVideos = seed.shortVideos
        esportsMatches = seed.esportsMatches
        esportsMarkets = seed.esportsMarkets
        threadsByGame = seed.threadsByGame

        let defaultFavorites = Set(seed.defaultFavoriteIDs)
        if favoriteReleaseIDs.isEmpty {
            favoriteReleaseIDs = defaultFavorites
        } else {
            favoriteReleaseIDs = favoriteReleaseIDs
                .intersection(Set(upcomingReleases.map(\.id)))
        }
    }
}

struct AppSeedData {
    let ownedGames: [Game]
    let upcomingReleases: [Game]
    let defaultFavoriteIDs: [Game.ID]
    let newsFeed: [NewsItem]
    let shortVideos: [ShortVideo]
    let esportsMatches: [EsportsMatch]
    let esportsMarkets: [EsportsMarket]
    let threadsByGame: [Game.ID: [ThreadPost]]

    init(referenceDate: Date) {
        let calendar = Calendar.current

        func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? referenceDate
        }

        func parseURL(_ value: String?) -> URL? {
            guard let value else { return nil }
            return URL(string: value)
        }

        func game(
            _ title: String,
            publisher: String,
            genre: String,
            releaseDate: Date,
            similar: [String],
            scores: [(String, Int)],
            isOwned: Bool = false,
            coverURL: String? = nil,
            screenshotURLs: [String] = []
        ) -> Game {
            Game(
                id: UUID(),
                title: title,
                publisher: publisher,
                genre: genre,
                releaseDate: releaseDate,
                similarTitles: similar,
                reviewScores: scores.map { ReviewScore(source: $0.0, value: $0.1) },
                isOwned: isOwned,
                coverImageURL: parseURL(coverURL),
                screenshotURLs: screenshotURLs.compactMap(parseURL)
            )
        }

        // Real release targets sourced from official publisher/platform announcements.
        let allUpcoming = [
            game(
                "Resident Evil Requiem",
                publisher: "Capcom",
                genre: "Survival Horror",
                releaseDate: makeDate(2026, 2, 27),
                similar: ["Resident Evil Village", "The Evil Within 2", "Dead Space"],
                scores: [("IGN", 90), ("GameSpot", 88), ("OpenCritic", 89)],
                coverURL: "https://i.ytimg.com/vi/W6bGrIvnTrU/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/0.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/1.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/2.jpg",
                    "https://i.ytimg.com/vi/W6bGrIvnTrU/3.jpg"
                ]
            ),
            game(
                "Marathon",
                publisher: "Bungie",
                genre: "Extraction Shooter",
                releaseDate: makeDate(2026, 3, 5),
                similar: ["Hunt: Showdown", "Escape from Tarkov", "The Finals"],
                scores: [("IGN", 84), ("GameSpot", 82), ("OpenCritic", 83)],
                coverURL: "https://i.ytimg.com/vi/t3ZO8tbmCvc/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/0.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/1.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/2.jpg",
                    "https://i.ytimg.com/vi/t3ZO8tbmCvc/3.jpg"
                ]
            ),
            game(
                "Monster Hunter Stories 3: Twisted Reflection",
                publisher: "Capcom",
                genre: "Turn-Based RPG",
                releaseDate: makeDate(2026, 3, 13),
                similar: ["Monster Hunter Stories 2", "Shin Megami Tensei V", "Persona 5 Royal"],
                scores: [("IGN", 86), ("GameSpot", 85), ("OpenCritic", 85)],
                coverURL: "https://i.ytimg.com/vi/YBkkrLe3WYE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/0.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/1.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/2.jpg",
                    "https://i.ytimg.com/vi/YBkkrLe3WYE/3.jpg"
                ]
            ),
            game(
                "Crimson Desert",
                publisher: "Pearl Abyss",
                genre: "Open World Action RPG",
                releaseDate: makeDate(2026, 3, 19),
                similar: ["Black Desert", "Dragon's Dogma 2", "The Witcher 3"],
                scores: [("IGN", 89), ("GameSpot", 87), ("OpenCritic", 88)],
                coverURL: "https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/0V8mt28YVwE/0.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/1.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/2.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/3.jpg"
                ]
            ),
            game(
                "Tomodachi Life: Living the Dream",
                publisher: "Nintendo",
                genre: "Life Sim",
                releaseDate: makeDate(2026, 4, 16),
                similar: ["Animal Crossing: New Horizons", "Miitopia", "The Sims 4"],
                scores: [("IGN", 82), ("GameSpot", 80), ("OpenCritic", 81)],
                coverURL: "https://i.ytimg.com/vi/K_0kl1WiSPg/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/0.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/1.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/2.jpg",
                    "https://i.ytimg.com/vi/K_0kl1WiSPg/3.jpg"
                ]
            ),
            game(
                "Pragmata",
                publisher: "Capcom",
                genre: "Sci-Fi Action Adventure",
                releaseDate: makeDate(2026, 4, 24),
                similar: ["Death Stranding", "Control", "Returnal"],
                scores: [("IGN", 85), ("GameSpot", 83), ("OpenCritic", 84)],
                coverURL: "https://i.ytimg.com/vi/jCA0S4yXSEE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/0.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/1.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/2.jpg",
                    "https://i.ytimg.com/vi/jCA0S4yXSEE/3.jpg"
                ]
            ),
            game(
                "Saros",
                publisher: "Housemarque",
                genre: "Sci-Fi Action",
                releaseDate: makeDate(2026, 4, 30),
                similar: ["Returnal", "Control", "Dead Space"],
                scores: [("IGN", 88), ("GameSpot", 86), ("OpenCritic", 87)],
                coverURL: "https://i.ytimg.com/vi/XtCS5tuvCKs/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/0.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/1.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/2.jpg",
                    "https://i.ytimg.com/vi/XtCS5tuvCKs/3.jpg"
                ]
            ),
            game(
                "Beast of Reincarnation",
                publisher: "Game Freak",
                genre: "Action Adventure",
                releaseDate: makeDate(2026, 8, 4),
                similar: ["NieR: Automata", "Scarlet Nexus", "Astral Chain"],
                scores: [("IGN", 84), ("GameSpot", 82), ("OpenCritic", 83)],
                coverURL: "https://i.ytimg.com/vi/zqxdVtJ24ms/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/0.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/1.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/2.jpg",
                    "https://i.ytimg.com/vi/zqxdVtJ24ms/3.jpg"
                ]
            )
        ]

        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .month, value: 6, to: start) ?? start
        upcomingReleases = allUpcoming
            .filter { $0.releaseDate >= start && $0.releaseDate <= end }
            .sorted { $0.releaseDate < $1.releaseDate }

        let libraryCandidates = [
            game(
                "Crimson Desert",
                publisher: "Pearl Abyss",
                genre: "Open World Action RPG",
                releaseDate: makeDate(2026, 3, 19),
                similar: ["Black Desert", "Dragon's Dogma 2"],
                scores: [("IGN", 89), ("GameSpot", 87), ("OpenCritic", 88)],
                isOwned: true,
                coverURL: "https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg",
                screenshotURLs: [
                    "https://i.ytimg.com/vi/0V8mt28YVwE/0.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/1.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/2.jpg",
                    "https://i.ytimg.com/vi/0V8mt28YVwE/3.jpg"
                ]
            ),
            game(
                "Helldivers 2",
                publisher: "Arrowhead Game Studios",
                genre: "Co-op Shooter",
                releaseDate: makeDate(2024, 2, 8),
                similar: ["Deep Rock Galactic", "Warframe"],
                scores: [("IGN", 90), ("GameSpot", 85), ("OpenCritic", 87)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/553850/library_hero.jpg"
                ]
            ),
            game(
                "Baldur's Gate 3",
                publisher: "Larian Studios",
                genre: "CRPG",
                releaseDate: makeDate(2023, 8, 3),
                similar: ["Divinity: Original Sin 2", "Dragon Age: Origins"],
                scores: [("IGN", 100), ("GameSpot", 90), ("OpenCritic", 96)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1086940/library_hero.jpg"
                ]
            ),
            game(
                "Cyberpunk 2077",
                publisher: "CD PROJEKT RED",
                genre: "Action RPG",
                releaseDate: makeDate(2020, 12, 10),
                similar: ["Deus Ex", "The Outer Worlds"],
                scores: [("IGN", 90), ("GameSpot", 70), ("OpenCritic", 86)],
                isOwned: true,
                coverURL: "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_600x900_2x.jpg",
                screenshotURLs: [
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/header.jpg",
                    "https://cdn.cloudflare.steamstatic.com/steam/apps/1091500/library_hero.jpg"
                ]
            )
        ]

        ownedGames = libraryCandidates.sorted { $0.title < $1.title }

        defaultFavoriteIDs = upcomingReleases
            .filter { ["Crimson Desert", "Resident Evil Requiem", "Pragmata"].contains($0.title) }
            .map(\.id)

        newsFeed = [
            NewsItem(
                id: UUID(),
                headline: "Crimson Desert launch set for March 19, 2026 with new gameplay reveal",
                summary: "Pearl Abyss confirmed the date and dropped a new trailer. Community interest is surging ahead of launch month.",
                publishedAt: referenceDate.addingTimeInterval(-2_800),
                category: "Hot",
                isHot: true
            ),
            NewsItem(
                id: UUID(),
                headline: "Bungie confirms Marathon release for March 5, 2026",
                summary: "New details highlighted faction contracts, progression systems, and an open preview weekend before launch.",
                publishedAt: referenceDate.addingTimeInterval(-7_800),
                category: "Studio",
                isHot: true
            ),
            NewsItem(
                id: UUID(),
                headline: "Capcom schedules Pragmata for April 24, 2026",
                summary: "The latest showcase included new footage and a clearer look at the game’s science-fiction world.",
                publishedAt: referenceDate.addingTimeInterval(-13_400),
                category: "Upcoming",
                isHot: false
            ),
            NewsItem(
                id: UUID(),
                headline: "Nintendo dates Tomodachi Life: Living the Dream for April 16, 2026",
                summary: "The social life-sim returns this spring, giving players another major release in April.",
                publishedAt: referenceDate.addingTimeInterval(-19_800),
                category: "Nintendo",
                isHot: false
            )
        ]

        shortVideos = [
            ShortVideo(
                id: UUID(),
                title: "Crimson Desert reveal trailer highlights open-world combat",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 58,
                viewCount: 1_280_000,
                relatedGameTitles: ["Crimson Desert"],
                videoURL: parseURL("https://www.youtube.com/watch?v=0V8mt28YVwE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/0V8mt28YVwE/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Resident Evil Requiem trailer breakdown in under a minute",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 54,
                viewCount: 942_000,
                relatedGameTitles: ["Resident Evil Requiem"],
                videoURL: parseURL("https://www.youtube.com/watch?v=W6bGrIvnTrU"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/W6bGrIvnTrU/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Marathon gameplay reveal recap",
                creator: "Marathon",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 49,
                viewCount: 761_000,
                relatedGameTitles: ["Marathon"],
                videoURL: parseURL("https://www.youtube.com/live/t3ZO8tbmCvc"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/t3ZO8tbmCvc/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Saros reveal clip and lore setup",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 43,
                viewCount: 504_000,
                relatedGameTitles: ["Saros"],
                videoURL: parseURL("https://www.youtube.com/watch?v=XtCS5tuvCKs"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/XtCS5tuvCKs/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Pragmata trailer cut: key moments",
                creator: "PlayStation",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 47,
                viewCount: 411_000,
                relatedGameTitles: ["Pragmata"],
                videoURL: parseURL("https://www.youtube.com/watch?v=jCA0S4yXSEE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/jCA0S4yXSEE/hqdefault.jpg")
            ),
            ShortVideo(
                id: UUID(),
                title: "Monster Hunter Stories 3 reveal clip",
                creator: "IGN",
                sourcePlatform: "YouTube Shorts",
                durationSeconds: 44,
                viewCount: 287_000,
                relatedGameTitles: ["Monster Hunter Stories 3: Twisted Reflection"],
                videoURL: parseURL("https://www.youtube.com/watch?v=YBkkrLe3WYE"),
                thumbnailURL: parseURL("https://i.ytimg.com/vi/YBkkrLe3WYE/hqdefault.jpg")
            )
        ]

        esportsMatches = [
            EsportsMatch(
                id: UUID(),
                league: "VCT",
                homeTeam: "Sentinels",
                awayTeam: "Paper Rex",
                homeRecord: "12-4",
                awayRecord: "11-5",
                homeScore: 2,
                awayScore: 1,
                state: .live,
                detailLine: "LIVE · MAP 4",
                subDetail: "Ascent · 7m",
                isFeatured: true
            ),
            EsportsMatch(
                id: UUID(),
                league: "CS2",
                homeTeam: "G2",
                awayTeam: "FaZe",
                homeRecord: "9-3",
                awayRecord: "8-4",
                homeScore: 16,
                awayScore: 13,
                state: .final,
                detailLine: "FINAL",
                subDetail: "Inferno",
                isFeatured: false
            ),
            EsportsMatch(
                id: UUID(),
                league: "CS2",
                homeTeam: "Team Spirit",
                awayTeam: "MOUZ",
                homeRecord: "7-5",
                awayRecord: "7-5",
                homeScore: 0,
                awayScore: 0,
                state: .upcoming,
                detailLine: "10:00 AM · BO3",
                subDetail: "Stage Match",
                isFeatured: false
            ),
            EsportsMatch(
                id: UUID(),
                league: "LoL",
                homeTeam: "T1",
                awayTeam: "Gen.G",
                homeRecord: "10-2",
                awayRecord: "11-1",
                homeScore: 1,
                awayScore: 1,
                state: .live,
                detailLine: "LIVE · GAME 3",
                subDetail: "Baron in 1m",
                isFeatured: false
            ),
            EsportsMatch(
                id: UUID(),
                league: "LoL",
                homeTeam: "G2",
                awayTeam: "Fnatic",
                homeRecord: "8-4",
                awayRecord: "8-4",
                homeScore: 2,
                awayScore: 0,
                state: .final,
                detailLine: "FINAL",
                subDetail: "Best of 3",
                isFeatured: false
            ),
            EsportsMatch(
                id: UUID(),
                league: "Dota 2",
                homeTeam: "Falcons",
                awayTeam: "Liquid",
                homeRecord: "6-3",
                awayRecord: "5-4",
                homeScore: 0,
                awayScore: 0,
                state: .upcoming,
                detailLine: "1:30 PM · BO3",
                subDetail: "Group Stage",
                isFeatured: false
            ),
            EsportsMatch(
                id: UUID(),
                league: "Dota 2",
                homeTeam: "Spirit",
                awayTeam: "BetBoom",
                homeRecord: "6-3",
                awayRecord: "6-3",
                homeScore: 1,
                awayScore: 2,
                state: .final,
                detailLine: "FINAL",
                subDetail: "Best of 3",
                isFeatured: false
            )
        ]

        esportsMarkets = [
            EsportsMarket(
                id: UUID(),
                title: "Valorant Champions: Who wins the upper-final?",
                league: "VCT",
                startsAt: referenceDate.addingTimeInterval(9_000),
                outcomes: [
                    MarketOutcome(teamName: "Sentinels", price: 0.57, trend: .up),
                    MarketOutcome(teamName: "Paper Rex", price: 0.43, trend: .down)
                ],
                volumeUSD: 1_420_000,
                isLive: false
            ),
            EsportsMarket(
                id: UUID(),
                title: "League MSI: Total maps over 3.5?",
                league: "LoL",
                startsAt: referenceDate.addingTimeInterval(24_000),
                outcomes: [
                    MarketOutcome(teamName: "Yes", price: 0.62, trend: .flat),
                    MarketOutcome(teamName: "No", price: 0.38, trend: .flat)
                ],
                volumeUSD: 860_000,
                isLive: false
            ),
            EsportsMarket(
                id: UUID(),
                title: "CS2 Major: Team Spirit vs G2 match winner",
                league: "CS2",
                startsAt: referenceDate.addingTimeInterval(1_200),
                outcomes: [
                    MarketOutcome(teamName: "Team Spirit", price: 0.49, trend: .down),
                    MarketOutcome(teamName: "G2", price: 0.51, trend: .up)
                ],
                volumeUSD: 2_210_000,
                isLive: true
            ),
            EsportsMarket(
                id: UUID(),
                title: "Dota Pro Circuit: Falcons top 2 finish",
                league: "Dota 2",
                startsAt: referenceDate.addingTimeInterval(172_800),
                outcomes: [
                    MarketOutcome(teamName: "Yes", price: 0.41, trend: .up),
                    MarketOutcome(teamName: "No", price: 0.59, trend: .down)
                ],
                volumeUSD: 610_000,
                isLive: false
            )
        ]

        var threadMap: [Game.ID: [ThreadPost]] = [:]
        let allGames = ownedGames + upcomingReleases

        let strategyOpeners = [
            "Best launch route for \(calendar.component(.year, from: referenceDate))",
            "What should be optimized first?",
            "Meta early-game strategy check",
            "First-week progression path thread"
        ]
        let discussionPrompts = [
            "Share your cleanest screenshot and where you captured it.",
            "Post your favorite environment shot from trailers or previews.",
            "Drop your best character/city/combat stills.",
            "Photo thread: visual details worth rewatching."
        ]
        let clipPrompts = [
            "Which moments in this clip should the community break down next?",
            "Video thread: best sequence and why?",
            "Trailer timing thread: strongest 10 seconds?",
            "Clip review: what detail did everyone miss?"
        ]
        let authors = ["PatchWizard", "LorePilot", "FrameDoctor", "QuestPilot", "MetaScout"]
        let defaultVideoURL = shortVideos.first?.videoURL
        let defaultVideoThumbnailURL = shortVideos.first?.thumbnailURL

        for (index, game) in allGames.enumerated() {
            let relatedClip = shortVideos.first { clip in
                clip.relatedGameTitles.contains(where: { $0.caseInsensitiveCompare(game.title) == .orderedSame })
            }
            let imageURL = game.coverImageURL ?? game.screenshotURLs.first
            let alternateImageURL = game.screenshotURLs.dropFirst().first ?? game.coverImageURL
            let nowOffset = TimeInterval(index * 280)

            threadMap[game.id] = [
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) \(strategyOpeners[index % strategyOpeners.count])",
                    body: "For \(game.genre), what are the first 2-3 things everyone should do? Build routes, quest order, and settings tips all welcome.",
                    author: authors[index % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-2_200 - nowOffset),
                    upvotes: 172 + (index * 3),
                    comments: 68 + (index * 2),
                    contentType: .text
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) visual thread",
                    body: discussionPrompts[index % discussionPrompts.count],
                    author: authors[(index + 1) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-5_900 - nowOffset),
                    upvotes: 136 + (index * 2),
                    comments: 42 + index,
                    contentType: .image,
                    mediaURL: imageURL ?? alternateImageURL
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "\(game.title) clip breakdown",
                    body: clipPrompts[index % clipPrompts.count],
                    author: authors[(index + 2) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-8_400 - nowOffset),
                    upvotes: 145 + (index * 2),
                    comments: 51 + index,
                    contentType: .video,
                    mediaURL: relatedClip?.videoURL ?? defaultVideoURL,
                    mediaThumbnailURL: relatedClip?.thumbnailURL ?? imageURL ?? defaultVideoThumbnailURL
                ),
                ThreadPost(
                    id: UUID(),
                    gameID: game.id,
                    title: "Performance settings thread",
                    body: "Share platform-specific settings that improve frame pacing and reduce stutter.",
                    author: authors[(index + 3) % authors.count],
                    createdAt: referenceDate.addingTimeInterval(-11_200 - nowOffset),
                    upvotes: 101 + index,
                    comments: 27 + (index % 4),
                    contentType: .text
                )
            ]
        }

        threadsByGame = threadMap
    }
}
