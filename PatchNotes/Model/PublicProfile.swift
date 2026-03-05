import Foundation

struct PublicProfile: Identifiable, Decodable, Equatable {
    let id: UUID
    let username: String
    let display_name: String?
    let avatar_url: String?
    let created_at: Date
    let is_bot: Bool?

    var isBot: Bool { is_bot ?? false }
}

struct FavoriteGameBadge: Identifiable, Equatable {
    let gameID: UUID
    let title: String
    let coverImageURL: URL?
    let ordinal: Int

    var id: UUID { gameID }
}
