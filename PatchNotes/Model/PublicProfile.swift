import Foundation

struct PublicProfile: Identifiable, Decodable, Equatable {
    let id: UUID
    let username: String
    let display_name: String?
    let avatar_url: String?
    let created_at: Date
}
