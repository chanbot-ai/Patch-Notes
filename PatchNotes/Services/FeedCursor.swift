import Foundation

struct FeedCursor {
    let hotScore: Double
    let createdAt: Date
    let id: UUID

    static func from(_ post: Post) -> FeedCursor {
        FeedCursor(
            hotScore: post.hot_score ?? 0,
            createdAt: post.created_at,
            id: post.id
        )
    }
}
