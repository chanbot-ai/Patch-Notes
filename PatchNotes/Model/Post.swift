import Foundation

struct Post: Identifiable, Decodable {
    let id: UUID
    let title: String?
    let body: String?
    let media_url: String?
    let thumbnail_url: String?
    let type: String
    let created_at: Date
    let reaction_count: Int?
    let comment_count: Int?
    let hot_score: Double?
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
