import Foundation

struct PublicProfile: Identifiable, Decodable, Equatable {
    let id: UUID
    let username: String
    let display_name: String?
    let avatar_url: String?
    let created_at: Date
    let is_bot: Bool?
    let avatar_slug: String?

    var isBot: Bool { is_bot ?? false }

    var avatarEmoji: String {
        AvatarCatalog.emoji(for: avatar_slug)
    }
}

struct FavoriteGameBadge: Identifiable, Equatable {
    let gameID: UUID
    let title: String
    let coverImageURL: URL?
    let ordinal: Int

    var id: UUID { gameID }
}
