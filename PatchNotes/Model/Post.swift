import Foundation

struct Post: Identifiable, Decodable {
    let id: UUID
    let author_id: UUID?
    let game_id: UUID?
    let title: String?
    let body: String?
    let media_url: String?
    let thumbnail_url: String?
    let type: String
    let created_at: Date
    let reaction_count: Int?
    let comment_count: Int?
    let hot_score: Double?
    let primary_badge_key: String?
    let secondary_badge_key: String?
    let badge_confidence_tier: String?
    let badge_confidence_score: Double?
    let badge_assignment_source: String?
    let badge_assignment_status: String?
    let badge_assigned_at: Date?
    let author_username: String?
    let author_display_name: String?
    let author_avatar_url: String?
    let author_created_at: Date?
    let source_kind: String?
    let source_provider: String?
    let source_external_id: String?
    let source_handle: String?
    let source_url: String?
    let source_published_at: Date?

    var authorID: UUID? { author_id }
    var gameID: UUID? { game_id }

    var primaryBadgeKeyRaw: String? {
        normalizedBadgeKeyString(primary_badge_key)
    }

    var secondaryBadgeKeyRaw: String? {
        normalizedBadgeKeyString(secondary_badge_key)
    }

    var primaryBadgeGameID: UUID? {
        guard let raw = primaryBadgeKeyRaw?.lowercased(),
              raw.hasPrefix("game:") else { return nil }
        let idString = String(raw.dropFirst("game:".count))
        return UUID(uuidString: idString)
    }

    var sourceKindRaw: String? {
        normalizedOptionalString(source_kind)?.lowercased()
    }

    var sourceProviderRaw: String? {
        normalizedOptionalString(source_provider)?.lowercased()
    }

    var sourceHandleDisplay: String? {
        guard let raw = normalizedOptionalString(source_handle) else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !trimmed.isEmpty else { return nil }
        return "@\(trimmed)"
    }

    var sourceURL: URL? {
        guard let source_url,
              !source_url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: source_url)
    }

    var isExternalSource: Bool {
        sourceKindRaw == "external" || sourceProviderRaw != nil || sourceURL != nil
    }

    var sourceProviderDisplayName: String? {
        if let provider = sourceProviderRaw {
            switch provider {
            case "twitterapi.io":
                return "X"
            default:
                return provider
            }
        }
        if sourceURL?.isTwitterStatusURL == true {
            return "X"
        }
        return nil
    }

    var sourcePillLabel: String? {
        guard isExternalSource else { return nil }
        let provider = sourceProviderDisplayName
        let handle = sourceHandleDisplay
        if let provider, let handle {
            return "\(provider) \(handle)"
        }
        return provider ?? handle ?? "External"
    }

    var fallbackHeadlineText: String {
        if let provider = sourceProviderDisplayName {
            return provider == "X" ? "X Post" : "\(provider.capitalized) Post"
        }
        return type.capitalized
    }

    var authorProfile: PublicProfile? {
        guard let authorID,
              let author_username,
              let author_created_at else { return nil }
        return PublicProfile(
            id: authorID,
            username: author_username,
            display_name: author_display_name,
            avatar_url: author_avatar_url,
            created_at: author_created_at,
            is_bot: nil
        )
    }

    enum ContentType: String {
        case text
        case image
        case video
        case link
    }

    var contentType: ContentType {
        let normalized = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == ContentType.video.rawValue {
            return .video
        }
        if normalized == ContentType.link.rawValue {
            return .link
        }
        if normalized == ContentType.image.rawValue {
            return .image
        }
        if let mediaURL, mediaURL.isTwitterStatusURL {
            return .link
        }
        if sourceURL?.isTwitterStatusURL == true {
            return .link
        }
        return mediaURL == nil ? .text : .image
    }

    var mediaURL: URL? {
        guard let media_url,
              !media_url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: media_url)
    }

    var thumbnailURL: URL? {
        guard let thumbnail_url,
              !thumbnail_url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: thumbnail_url)
    }

    private func normalizedBadgeKeyString(_ raw: String?) -> String? {
        normalizedOptionalString(raw)
    }

    private func normalizedOptionalString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ReactionType: Identifiable, Decodable, Equatable {
    let id: UUID
    let slug: String
    let display_name: String?
    let emoji: String
    let category: String?
    let sort_order: Int?
}

enum ReactionCategory: String, CaseIterable, Identifiable {
    case core, hype, fail, watching, gaming, memes, social

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .core: return "Core"
        case .hype: return "Hype"
        case .fail: return "Fail / Salt"
        case .watching: return "Watching"
        case .gaming: return "Gaming"
        case .memes: return "Memes"
        case .social: return "Social"
        }
    }

    var icon: String {
        switch self {
        case .core: return "😂"
        case .hype: return "🚀"
        case .fail: return "💀"
        case .watching: return "👀"
        case .gaming: return "🎮"
        case .memes: return "🐸"
        case .social: return "❤️"
        }
    }
}

struct PostReactionCount: Identifiable, Decodable, Equatable {
    let post_id: UUID
    let reaction_type_id: UUID
    var count: Int

    var id: UUID { reaction_type_id }

    var postID: UUID { post_id }
    var reactionTypeID: UUID { reaction_type_id }
}

struct Comment: Identifiable, Decodable, Equatable {
    let id: UUID
    let post_id: UUID
    let user_id: UUID
    let body: String
    let parent_comment_id: UUID?
    let created_at: Date
    let reaction_count: Int?
    let hot_score: Double?
    let author_username: String?
    let author_display_name: String?
    let author_avatar_url: String?
    let author_created_at: Date?

    var postID: UUID { post_id }
    var userID: UUID { user_id }
    var parentCommentID: UUID? { parent_comment_id }

    var authorProfile: PublicProfile? {
        guard let author_username,
              let author_created_at else { return nil }
        return PublicProfile(
            id: user_id,
            username: author_username,
            display_name: author_display_name,
            avatar_url: author_avatar_url,
            created_at: author_created_at,
            is_bot: nil
        )
    }
}

enum CommentSortMode: String, CaseIterable, Identifiable {
    case top
    case new

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: return "Top"
        case .new: return "New"
        }
    }
}

struct CommentReactionCount: Identifiable, Decodable, Equatable {
    let comment_id: UUID
    let reaction_type_id: UUID
    var count: Int

    var id: UUID { reaction_type_id }

    var commentID: UUID { comment_id }
    var reactionTypeID: UUID { reaction_type_id }
}

// MARK: - Steam Models

struct SteamProfile: Decodable, Equatable {
    let user_id: UUID
    let steam_id: String
    let persona_name: String?
    let avatar_url: String?
    let profile_url: String?
    let last_synced_at: Date?

    var personaName: String { persona_name ?? steam_id }
}

struct SteamOwnedGame: Identifiable, Decodable, Equatable {
    let steam_app_id: Int
    let name: String
    let playtime_forever_minutes: Int
    let playtime_2weeks_minutes: Int?
    let last_played_at: Date?
    let cover_image_url: String?
    let game_id: UUID?
    let game_title: String?

    var id: Int { steam_app_id }

    var coverImageURL: URL? {
        if let cover_image_url, let url = URL(string: cover_image_url) {
            return url
        }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(steam_app_id)/library_600x900_2x.jpg")
    }

    var playtimeHours: Int { playtime_forever_minutes / 60 }
}

struct SteamSyncResult: Decodable {
    let success: Bool
    let steam_profile: SteamSyncProfile?
    let owned_games_total: Int?
    let matched_to_catalog: Int?
    let newly_followed: Int?

    struct SteamSyncProfile: Decodable {
        let name: String?
        let avatar: String?
        let profile_url: String?
    }
}

struct GameCommunityHealth: Decodable {
    let game_id: UUID
    let game_title: String?
    let total_posts: Int
    let recent_posts: Int
    let total_comments: Int
    let unique_authors: Int
    let is_quiet: Bool
    let quiet_message: String?
}

// MARK: - Notifications

struct AppNotification: Identifiable, Decodable, Equatable {
    let id: UUID
    let user_id: UUID
    let actor_user_id: UUID
    let post_id: UUID?
    let comment_id: UUID?
    let type: String
    let created_at: Date
    let read: Bool

    var userID: UUID { user_id }
    var actorUserID: UUID { actor_user_id }
    var postID: UUID? { post_id }
    var commentID: UUID? { comment_id }
    var createdAt: Date { created_at }
    var isRead: Bool { read }

    var titleText: String {
        switch type {
        case "comment_reply":
            return "New reply"
        case "post_comment":
            return "New comment"
        default:
            return "New activity"
        }
    }

    var bodyText: String {
        switch type {
        case "comment_reply":
            return "Someone replied to your comment."
        case "post_comment":
            return "Someone commented on your post."
        default:
            return "There’s new activity on your feed."
        }
    }
}
