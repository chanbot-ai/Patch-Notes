#if DEBUG
import Foundation

enum PreviewHelpers {

    // MARK: - Post

    static func makePost(
        id: UUID = UUID(),
        authorID: UUID? = UUID(uuidString: "11111111-0000-0000-0000-000000000001"),
        gameID: UUID? = nil,
        title: String? = "Elden Ring DLC drops next month",
        body: String? = "Shadow of the Erdtree is looking incredible. Can't wait for launch day.",
        type: String = "text",
        mediaURL: String? = nil,
        thumbnailURL: String? = nil,
        reactionCount: Int = 12,
        commentCount: Int = 4,
        hotScore: Double = 42.5,
        authorUsername: String? = "chanbot",
        authorDisplayName: String? = "Chan",
        createdAt: Date = Date().addingTimeInterval(-3600)
    ) -> Post {
        Post(
            id: id,
            author_id: authorID,
            game_id: gameID,
            title: title,
            body: body,
            media_url: mediaURL,
            thumbnail_url: thumbnailURL,
            type: type,
            created_at: createdAt,
            reaction_count: reactionCount,
            comment_count: commentCount,
            hot_score: hotScore,
            primary_badge_key: nil,
            secondary_badge_key: nil,
            badge_confidence_tier: nil,
            badge_confidence_score: nil,
            badge_assignment_source: nil,
            badge_assignment_status: nil,
            badge_assigned_at: nil,
            author_username: authorUsername,
            author_display_name: authorDisplayName,
            author_avatar_url: nil,
            author_created_at: Date(timeIntervalSinceReferenceDate: 750_000_000),
            source_kind: nil,
            source_provider: nil,
            source_external_id: nil,
            source_handle: nil,
            source_url: nil,
            source_published_at: nil
        )
    }

    static func makeImagePost(imageURL: String = "https://picsum.photos/1280/720") -> Post {
        makePost(title: "Check out this screenshot", type: "image", mediaURL: imageURL)
    }

    static func makeVideoPost() -> Post {
        makePost(
            title: "Check out this highlight",
            type: "video",
            mediaURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            thumbnailURL: "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
        )
    }

    static func makeLinkPost() -> Post {
        makePost(
            title: nil,
            body: "Big announcement from the devs",
            type: "link",
            mediaURL: "https://x.com/ign/status/123456789"
        )
    }

    // MARK: - ReactionType

    static let reactionTypeIDs = (
        fire: UUID(uuidString: "AAAA0001-0000-0000-0000-000000000001")!,
        hype: UUID(uuidString: "AAAA0001-0000-0000-0000-000000000002")!,
        mindBlown: UUID(uuidString: "AAAA0001-0000-0000-0000-000000000003")!
    )

    static func makeReactionTypes() -> [ReactionType] {
        [
            ReactionType(id: reactionTypeIDs.fire, slug: "fire", display_name: "Fire", emoji: "\u{1F525}", category: "core", sort_order: 5),
            ReactionType(id: reactionTypeIDs.hype, slug: "lightning", display_name: "Lightning", emoji: "\u{26A1}", category: "hype", sort_order: 7),
            ReactionType(id: reactionTypeIDs.mindBlown, slug: "mind_blown", display_name: "Mind Blown", emoji: "\u{1F92F}", category: "core", sort_order: 10)
        ]
    }

    // MARK: - PostReactionCount

    static func makeReactionCounts(postID: UUID, fireCount: Int = 8, hypeCount: Int = 3) -> [PostReactionCount] {
        [
            PostReactionCount(post_id: postID, reaction_type_id: reactionTypeIDs.fire, count: fireCount),
            PostReactionCount(post_id: postID, reaction_type_id: reactionTypeIDs.hype, count: hypeCount)
        ]
    }

    // MARK: - PublicProfile

    static func makeProfile(
        id: UUID = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
        username: String = "chanbot",
        displayName: String? = "Chan"
    ) -> PublicProfile {
        PublicProfile(
            id: id,
            username: username,
            display_name: displayName,
            avatar_url: nil,
            created_at: Date(timeIntervalSinceReferenceDate: 750_000_000),
            is_bot: false,
            avatar_slug: "gamer_1"
        )
    }

    // MARK: - Comment

    static func makeComment(
        postID: UUID,
        body: String = "This looks amazing, can't wait!",
        parentCommentID: UUID? = nil
    ) -> Comment {
        Comment(
            id: UUID(),
            post_id: postID,
            user_id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            body: body,
            parent_comment_id: parentCommentID,
            created_at: Date().addingTimeInterval(-600),
            reaction_count: 2,
            hot_score: 1.5,
            author_username: "chanbot",
            author_display_name: "Chan",
            author_avatar_url: nil,
            author_created_at: Date(timeIntervalSinceReferenceDate: 750_000_000),
            author_avatar_slug: "gamer_1"
        )
    }

    // MARK: - AppNotification

    static func makeNotification(
        type: String = "post_comment",
        read: Bool = false,
        postID: UUID? = UUID(),
        createdAt: Date = Date().addingTimeInterval(-3600)
    ) -> AppNotification {
        AppNotification(
            id: UUID(),
            user_id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            actor_user_id: UUID(uuidString: "22222222-0000-0000-0000-000000000002")!,
            post_id: postID,
            comment_id: nil,
            type: type,
            created_at: createdAt,
            read: read
        )
    }

    // MARK: - Game

    static func makeGame(title: String = "Elden Ring") -> Game {
        Game(
            id: UUID(),
            title: title,
            publisher: "FromSoftware",
            genre: "Action RPG",
            releaseDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            similarTitles: ["Dark Souls III", "Sekiro"],
            reviewScores: [ReviewScore(source: "IGN", value: 96)],
            isOwned: true
        )
    }
}
#endif
