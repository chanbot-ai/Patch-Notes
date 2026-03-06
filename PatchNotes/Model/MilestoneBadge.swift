import Foundation

// MARK: - Milestone Requirements

struct UserMilestones: Decodable, Equatable {
    let comments_posted: Int
    let replies_posted: Int
    let reactions_given: Int
}

// MARK: - Badge Definition

struct MilestoneBadgeDef: Identifiable, Equatable {
    let slug: String
    let emoji: String
    let label: String
    let description: String
    let category: String
    let threshold: Int
    let milestoneKey: MilestoneKey

    var id: String { slug }

    func isEarned(by milestones: UserMilestones) -> Bool {
        switch milestoneKey {
        case .comments: return milestones.comments_posted >= threshold
        case .replies: return milestones.replies_posted >= threshold
        case .reactions: return milestones.reactions_given >= threshold
        case .total:
            let total = milestones.comments_posted + milestones.replies_posted + milestones.reactions_given
            return total >= threshold
        }
    }
}

enum MilestoneKey: String, Equatable {
    case comments
    case replies
    case reactions
    case total
}

// MARK: - Display Badge (what a user has chosen to show)

struct DisplayBadge: Identifiable, Equatable {
    let slug: String
    let ordinal: Int

    var id: String { slug }

    var emoji: String {
        MilestoneBadgeCatalog.emoji(for: slug)
    }

    var label: String {
        MilestoneBadgeCatalog.badge(for: slug)?.label ?? slug
    }
}

// MARK: - Badge Catalog

enum MilestoneBadgeCatalog {
    static let all: [MilestoneBadgeDef] = [
        // Comments
        MilestoneBadgeDef(slug: "first_comment", emoji: "💬", label: "First Comment", description: "Post your first comment", category: "Comments", threshold: 1, milestoneKey: .comments),
        MilestoneBadgeDef(slug: "commentator", emoji: "🗣️", label: "Commentator", description: "Post 5 comments", category: "Comments", threshold: 5, milestoneKey: .comments),
        MilestoneBadgeDef(slug: "community_voice", emoji: "📣", label: "Community Voice", description: "Post 25 comments", category: "Comments", threshold: 25, milestoneKey: .comments),
        MilestoneBadgeDef(slug: "comment_legend", emoji: "🏛️", label: "Comment Legend", description: "Post 100 comments", category: "Comments", threshold: 100, milestoneKey: .comments),

        // Replies
        MilestoneBadgeDef(slug: "first_reply", emoji: "↩️", label: "First Reply", description: "Post your first reply", category: "Replies", threshold: 1, milestoneKey: .replies),
        MilestoneBadgeDef(slug: "conversationalist", emoji: "🤝", label: "Conversationalist", description: "Post 5 replies", category: "Replies", threshold: 5, milestoneKey: .replies),
        MilestoneBadgeDef(slug: "reply_king", emoji: "👑", label: "Reply King", description: "Post 25 replies", category: "Replies", threshold: 25, milestoneKey: .replies),
        MilestoneBadgeDef(slug: "thread_master", emoji: "🧵", label: "Thread Master", description: "Post 100 replies", category: "Replies", threshold: 100, milestoneKey: .replies),

        // Reactions
        MilestoneBadgeDef(slug: "first_reaction", emoji: "❤️", label: "First Reaction", description: "React to a post or comment", category: "Reactions", threshold: 1, milestoneKey: .reactions),
        MilestoneBadgeDef(slug: "hype_fan", emoji: "🔥", label: "Hype Fan", description: "Give 10 reactions", category: "Reactions", threshold: 10, milestoneKey: .reactions),
        MilestoneBadgeDef(slug: "hype_machine", emoji: "⚡", label: "Hype Machine", description: "Give 50 reactions", category: "Reactions", threshold: 50, milestoneKey: .reactions),
        MilestoneBadgeDef(slug: "reaction_god", emoji: "🌟", label: "Reaction God", description: "Give 200 reactions", category: "Reactions", threshold: 200, milestoneKey: .reactions),

        // Total engagement
        MilestoneBadgeDef(slug: "getting_started", emoji: "🌱", label: "Getting Started", description: "5 total interactions", category: "Engagement", threshold: 5, milestoneKey: .total),
        MilestoneBadgeDef(slug: "active_member", emoji: "⭐", label: "Active Member", description: "25 total interactions", category: "Engagement", threshold: 25, milestoneKey: .total),
        MilestoneBadgeDef(slug: "power_user", emoji: "💎", label: "Power User", description: "100 total interactions", category: "Engagement", threshold: 100, milestoneKey: .total),
        MilestoneBadgeDef(slug: "veteran", emoji: "🏆", label: "Veteran", description: "500 total interactions", category: "Engagement", threshold: 500, milestoneKey: .total),
    ]

    static let categories: [String] = ["Comments", "Replies", "Reactions", "Engagement"]

    static func badge(for slug: String) -> MilestoneBadgeDef? {
        all.first { $0.slug == slug }
    }

    static func emoji(for slug: String) -> String {
        badge(for: slug)?.emoji ?? "🏅"
    }

    static func earnedBadges(for milestones: UserMilestones) -> [MilestoneBadgeDef] {
        all.filter { $0.isEarned(by: milestones) }
    }
}
