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
