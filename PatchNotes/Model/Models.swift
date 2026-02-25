import Foundation

enum AppTab: Hashable {
    case home
    case releaseCalendar
    case social
    case myGames
    case esports
}

struct Game: Identifiable, Hashable {
    let id: UUID
    let title: String
    let publisher: String
    let genre: String
    let releaseDate: Date
    let similarTitles: [String]
    let reviewScores: [ReviewScore]
    let isOwned: Bool
    let coverImageURL: URL?
    let screenshotURLs: [URL]

    init(
        id: UUID,
        title: String,
        publisher: String,
        genre: String,
        releaseDate: Date,
        similarTitles: [String],
        reviewScores: [ReviewScore],
        isOwned: Bool,
        coverImageURL: URL? = nil,
        screenshotURLs: [URL] = []
    ) {
        self.id = id
        self.title = title
        self.publisher = publisher
        self.genre = genre
        self.releaseDate = releaseDate
        self.similarTitles = similarTitles
        self.reviewScores = reviewScores
        self.isOwned = isOwned
        self.coverImageURL = coverImageURL
        self.screenshotURLs = screenshotURLs
    }
}

struct ReviewScore: Identifiable, Hashable {
    var id: String { source }
    let source: String
    let value: Int
}

struct NewsItem: Identifiable, Hashable {
    let id: UUID
    let headline: String
    let summary: String
    let publishedAt: Date
    let category: String
    let isHot: Bool
}

struct ShortVideo: Identifiable, Hashable {
    let id: UUID
    let title: String
    let creator: String
    let sourcePlatform: String
    let durationSeconds: Int
    let viewCount: Int
    let relatedGameTitles: [String]
    let videoURL: URL?
    let thumbnailURL: URL?

    init(
        id: UUID,
        title: String,
        creator: String,
        sourcePlatform: String,
        durationSeconds: Int,
        viewCount: Int,
        relatedGameTitles: [String],
        videoURL: URL? = nil,
        thumbnailURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.creator = creator
        self.sourcePlatform = sourcePlatform
        self.durationSeconds = durationSeconds
        self.viewCount = viewCount
        self.relatedGameTitles = relatedGameTitles
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
    }
}

enum ThreadContentType: String, Hashable {
    case text
    case image
    case video

    var label: String {
        switch self {
        case .text:
            return "Text"
        case .image:
            return "Photo"
        case .video:
            return "Video"
        }
    }

    var iconName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo.fill"
        case .video:
            return "play.rectangle.fill"
        }
    }
}

struct ThreadPost: Identifiable, Hashable {
    let id: UUID
    let gameID: UUID
    let title: String
    let body: String
    let author: String
    let createdAt: Date
    let upvotes: Int
    let comments: Int
    let contentType: ThreadContentType
    let mediaURL: URL?
    let mediaThumbnailURL: URL?

    init(
        id: UUID,
        gameID: UUID,
        title: String,
        body: String,
        author: String,
        createdAt: Date,
        upvotes: Int,
        comments: Int,
        contentType: ThreadContentType = .text,
        mediaURL: URL? = nil,
        mediaThumbnailURL: URL? = nil
    ) {
        self.id = id
        self.gameID = gameID
        self.title = title
        self.body = body
        self.author = author
        self.createdAt = createdAt
        self.upvotes = upvotes
        self.comments = comments
        self.contentType = contentType
        self.mediaURL = mediaURL
        self.mediaThumbnailURL = mediaThumbnailURL
    }

    var hotScore: Int {
        (upvotes * 2) + comments
    }

    var isHot: Bool {
        hotScore >= 250
    }
}

struct EsportsMarket: Identifiable, Hashable {
    let id: UUID
    let title: String
    let league: String
    let startsAt: Date
    let outcomes: [MarketOutcome]
    let volumeUSD: Int
    let isLive: Bool
}

enum MatchState: Hashable {
    case live
    case final
    case upcoming
}

struct EsportsMatch: Identifiable, Hashable {
    let id: UUID
    let league: String
    let homeTeam: String
    let awayTeam: String
    let homeRecord: String
    let awayRecord: String
    let homeScore: Int
    let awayScore: Int
    let state: MatchState
    let detailLine: String
    let subDetail: String
    let isFeatured: Bool
    let scheduledAt: Date?
    let streamURL: URL?

    init(
        id: UUID,
        league: String,
        homeTeam: String,
        awayTeam: String,
        homeRecord: String,
        awayRecord: String,
        homeScore: Int,
        awayScore: Int,
        state: MatchState,
        detailLine: String,
        subDetail: String,
        isFeatured: Bool,
        scheduledAt: Date? = nil,
        streamURL: URL? = nil
    ) {
        self.id = id
        self.league = league
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeRecord = homeRecord
        self.awayRecord = awayRecord
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.state = state
        self.detailLine = detailLine
        self.subDetail = subDetail
        self.isFeatured = isFeatured
        self.scheduledAt = scheduledAt
        self.streamURL = streamURL
    }
}

struct MarketOutcome: Identifiable, Hashable {
    var id: String { teamName }
    let teamName: String
    let price: Double
    let trend: OddsTrend
}

enum OddsTrend: String, Hashable {
    case up
    case down
    case flat
}
