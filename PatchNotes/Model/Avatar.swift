import SwiftUI

enum AvatarUnlockRequirement: Hashable {
    case milestone(MilestoneKey, threshold: Int)
    case premium
}

struct AvatarOption: Identifiable, Hashable {
    let slug: String
    let emoji: String
    let label: String
    let category: String
    var isLocked: Bool = false
    var unlockRequirement: AvatarUnlockRequirement? = nil

    var id: String { slug }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        // Gaming
        AvatarOption(slug: "gamer_1", emoji: "🎮", label: "Gamer", category: "Gaming"),
        AvatarOption(slug: "joystick", emoji: "🕹️", label: "Joystick", category: "Gaming"),
        AvatarOption(slug: "controller", emoji: "🎯", label: "Bullseye", category: "Gaming"),
        AvatarOption(slug: "trophy", emoji: "🏆", label: "Trophy", category: "Gaming"),
        AvatarOption(slug: "crown", emoji: "👑", label: "Crown", category: "Gaming"),
        AvatarOption(slug: "sword", emoji: "⚔️", label: "Swords", category: "Gaming"),
        AvatarOption(slug: "shield", emoji: "🛡️", label: "Shield", category: "Gaming"),
        AvatarOption(slug: "bow", emoji: "🏹", label: "Bow", category: "Gaming"),
        AvatarOption(slug: "crystal_ball", emoji: "🔮", label: "Crystal Ball", category: "Gaming"),
        AvatarOption(slug: "gem", emoji: "💎", label: "Gem", category: "Gaming"),

        // Animals
        AvatarOption(slug: "dragon", emoji: "🐉", label: "Dragon", category: "Animals"),
        AvatarOption(slug: "wolf", emoji: "🐺", label: "Wolf", category: "Animals"),
        AvatarOption(slug: "eagle", emoji: "🦅", label: "Eagle", category: "Animals"),
        AvatarOption(slug: "lion", emoji: "🦁", label: "Lion", category: "Animals"),
        AvatarOption(slug: "fox", emoji: "🦊", label: "Fox", category: "Animals"),
        AvatarOption(slug: "cat", emoji: "🐱", label: "Cat", category: "Animals"),
        AvatarOption(slug: "octopus", emoji: "🐙", label: "Octopus", category: "Animals"),
        AvatarOption(slug: "butterfly", emoji: "🦋", label: "Butterfly", category: "Animals"),
        AvatarOption(slug: "phoenix", emoji: "🐦‍🔥", label: "Phoenix", category: "Animals"),
        AvatarOption(slug: "bear", emoji: "🐻", label: "Bear", category: "Animals"),

        // Space
        AvatarOption(slug: "rocket", emoji: "🚀", label: "Rocket", category: "Space"),
        AvatarOption(slug: "alien", emoji: "👾", label: "Alien", category: "Space"),
        AvatarOption(slug: "astronaut", emoji: "🧑‍🚀", label: "Astronaut", category: "Space"),
        AvatarOption(slug: "ufo", emoji: "🛸", label: "UFO", category: "Space"),
        AvatarOption(slug: "star", emoji: "⭐", label: "Star", category: "Space"),
        AvatarOption(slug: "comet", emoji: "☄️", label: "Comet", category: "Space"),
        AvatarOption(slug: "moon", emoji: "🌙", label: "Moon", category: "Space"),
        AvatarOption(slug: "sun", emoji: "☀️", label: "Sun", category: "Space"),
        AvatarOption(slug: "globe", emoji: "🌍", label: "Globe", category: "Space"),
        AvatarOption(slug: "satellite", emoji: "🛰️", label: "Satellite", category: "Space"),

        // Characters
        AvatarOption(slug: "ninja", emoji: "🥷", label: "Ninja", category: "Characters"),
        AvatarOption(slug: "robot", emoji: "🤖", label: "Robot", category: "Characters"),
        AvatarOption(slug: "ghost", emoji: "👻", label: "Ghost", category: "Characters"),
        AvatarOption(slug: "skull", emoji: "💀", label: "Skull", category: "Characters"),
        AvatarOption(slug: "wizard", emoji: "🧙", label: "Wizard", category: "Characters"),
        AvatarOption(slug: "zombie", emoji: "🧟", label: "Zombie", category: "Characters"),
        AvatarOption(slug: "vampire", emoji: "🧛", label: "Vampire", category: "Characters"),
        AvatarOption(slug: "pirate", emoji: "🏴‍☠️", label: "Pirate", category: "Characters"),
        AvatarOption(slug: "superhero", emoji: "🦸", label: "Superhero", category: "Characters"),
        AvatarOption(slug: "detective", emoji: "🕵️", label: "Detective", category: "Characters"),

        // Elements
        AvatarOption(slug: "fire", emoji: "🔥", label: "Fire", category: "Elements"),
        AvatarOption(slug: "lightning", emoji: "⚡", label: "Lightning", category: "Elements"),
        AvatarOption(slug: "tornado", emoji: "🌪️", label: "Tornado", category: "Elements"),
        AvatarOption(slug: "snowflake", emoji: "❄️", label: "Snowflake", category: "Elements"),
        AvatarOption(slug: "rainbow", emoji: "🌈", label: "Rainbow", category: "Elements"),
        AvatarOption(slug: "wave", emoji: "🌊", label: "Wave", category: "Elements"),
        AvatarOption(slug: "volcano", emoji: "🌋", label: "Volcano", category: "Elements"),
        AvatarOption(slug: "sparkle", emoji: "✨", label: "Sparkle", category: "Elements"),
        AvatarOption(slug: "dice", emoji: "🎲", label: "Dice", category: "Elements"),
        AvatarOption(slug: "bomb", emoji: "💣", label: "Bomb", category: "Elements"),

        // Exclusive (Locked — earn via milestones or PN Pro)
        AvatarOption(slug: "galaxy", emoji: "🌌", label: "Galaxy", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.total, threshold: 25)),
        AvatarOption(slug: "gold_medal", emoji: "🥇", label: "Gold Medal", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.comments, threshold: 25)),
        AvatarOption(slug: "trident", emoji: "🔱", label: "Trident", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.replies, threshold: 25)),
        AvatarOption(slug: "flaming_heart", emoji: "❤️‍🔥", label: "Flaming Heart", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.reactions, threshold: 50)),
        AvatarOption(slug: "infinity", emoji: "♾️", label: "Infinity", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.total, threshold: 100)),
        AvatarOption(slug: "black_heart", emoji: "🖤", label: "Black Heart", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.total, threshold: 250)),
        AvatarOption(slug: "unicorn", emoji: "🦄", label: "Unicorn", category: "Exclusive",
                     isLocked: true, unlockRequirement: .milestone(.total, threshold: 500)),
        AvatarOption(slug: "diamond_pro", emoji: "💠", label: "Diamond Pro", category: "Exclusive",
                     isLocked: true, unlockRequirement: .premium),
        AvatarOption(slug: "glowing_star", emoji: "🌟", label: "Glowing Star", category: "Exclusive",
                     isLocked: true, unlockRequirement: .premium),
        AvatarOption(slug: "crystal_pro", emoji: "🪩", label: "Crystal Pro", category: "Exclusive",
                     isLocked: true, unlockRequirement: .premium),
    ]

    static let categories: [String] = ["Gaming", "Animals", "Space", "Characters", "Elements", "Exclusive"]

    static func avatar(for slug: String) -> AvatarOption? {
        all.first { $0.slug == slug }
    }

    static func emoji(for slug: String?) -> String {
        guard let slug else { return "🎮" }
        return avatar(for: slug)?.emoji ?? "🎮"
    }

    static func isUnlocked(_ avatar: AvatarOption, milestones: UserMilestones?, isPremium: Bool = false) -> Bool {
        guard avatar.isLocked, let req = avatar.unlockRequirement else { return true }
        switch req {
        case .milestone(let key, let threshold):
            guard let m = milestones else { return false }
            switch key {
            case .comments: return m.comments_posted >= threshold
            case .replies: return m.replies_posted >= threshold
            case .reactions: return m.reactions_given >= threshold
            case .total:
                return (m.comments_posted + m.replies_posted + m.reactions_given) >= threshold
            }
        case .premium:
            return isPremium
        }
    }

    static func unlockDescription(for requirement: AvatarUnlockRequirement) -> String {
        switch requirement {
        case .milestone(let key, let threshold):
            switch key {
            case .comments: return "\(threshold) comments"
            case .replies: return "\(threshold) replies"
            case .reactions: return "\(threshold) reactions"
            case .total: return "\(threshold) interactions"
            }
        case .premium:
            return "PN Pro"
        }
    }
}
