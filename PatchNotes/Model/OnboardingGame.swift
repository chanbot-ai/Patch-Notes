import Foundation

struct OnboardingGame: Identifiable, Hashable {
    let id: UUID
    let title: String
    let coverImageURL: URL?
    let genre: String
    let category: String
}

struct OnboardingCategory: Identifiable, Hashable {
    let name: String
    let games: [OnboardingGame]
    var id: String { name }
}
