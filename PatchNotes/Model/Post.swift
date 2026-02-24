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

    var authorID: UUID? { author_id }
    var gameID: UUID? { game_id }
}

struct ReactionType: Identifiable, Decodable, Equatable {
    let id: UUID
    let slug: String
    let display_name: String?
    let emoji: String
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

    var postID: UUID { post_id }
    var userID: UUID { user_id }
    var parentCommentID: UUID? { parent_comment_id }
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
