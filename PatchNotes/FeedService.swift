import Foundation
import Supabase

final class FeedService {
    private struct ReactionInsertPayload: Encodable {
        let post_id: UUID
        let user_id: UUID
        let reaction_type_id: UUID
    }

    private struct CommentInsertPayload: Encodable {
        let post_id: UUID
        let user_id: UUID
        let body: String
        let parent_comment_id: UUID?
    }

    private struct UserReactionRow: Decodable {
        let post_id: UUID
        let reaction_type_id: UUID
    }

    private struct UserCommentReactionRow: Decodable {
        let comment_id: UUID
        let reaction_type_id: UUID
    }

    private struct CommentReactionRow: Decodable {
        let comment_id: UUID
        let reaction_type_id: UUID
    }

    private struct CommentReactionInsertPayload: Encodable {
        let post_id: UUID? = nil
        let comment_id: UUID
        let user_id: UUID
        let reaction_type_id: UUID
    }

    private let client = SupabaseManager.shared.client
    private var postMetricsChannel: RealtimeChannelV2?
    private var postMetricsSubscription: RealtimeSubscription?
    private var commentMetricsChannel: RealtimeChannelV2?
    private var commentMetricsSubscription: RealtimeSubscription?
    var onPostMetricsChange: (@MainActor @Sendable (UUID?) -> Void)?
    var onCommentMetricsChange: (@MainActor @Sendable (UUID?) -> Void)?
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let postgresTimestampWithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    private static let postgresTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    func subscribeToPostMetrics(
        onChange: @escaping @MainActor @Sendable (UUID?) -> Void
    ) {
        onPostMetricsChange = onChange
        subscribeToPostMetrics()
    }

    func subscribeToPostMetrics() {
        guard postMetricsChannel == nil else { return }

        let channel = client.channel("public:post_metrics")
        let onPostMetricsChange = onPostMetricsChange
        let subscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "post_metrics"
        ) { payload in
            let updatedPostID = Self.postID(from: payload)
            print("Realtime update:", payload)
            Task { @MainActor in
                onPostMetricsChange?(updatedPostID)
            }
        }

        postMetricsChannel = channel
        postMetricsSubscription = subscription

        Task {
            do {
                try await channel.subscribeWithError()
                print("Subscribed to post_metrics realtime updates")
            } catch {
                print("Realtime subscription error:", error)
            }
        }
    }

    func subscribeToCommentMetrics(
        onChange: @escaping @MainActor @Sendable (UUID?) -> Void
    ) {
        onCommentMetricsChange = onChange
        subscribeToCommentMetrics()
    }

    func subscribeToCommentMetrics() {
        guard commentMetricsChannel == nil else { return }

        let channel = client.channel("public:comment_metrics")
        let onCommentMetricsChange = onCommentMetricsChange
        let subscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "comment_metrics"
        ) { payload in
            let updatedCommentID = Self.commentID(from: payload)
            Task { @MainActor in
                onCommentMetricsChange?(updatedCommentID)
            }
        }

        commentMetricsChannel = channel
        commentMetricsSubscription = subscription

        Task {
            do {
                try await channel.subscribeWithError()
                print("Subscribed to comment_metrics realtime updates")
            } catch {
                print("Comment metrics realtime subscription error:", error)
            }
        }
    }

    func fetchHotFeed() async throws -> [Post] {
        let response = try await client
            .from("hot_feed_view")
            .select()
            .limit(50)
            .execute()

        return try makeDatabaseDecoder().decode([Post].self, from: response.data)
    }

    func fetchFollowingFeed(accessToken: String) async throws -> [Post] {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        let response = try await client
            .from("following_feed_view")
            .select()
            .limit(50)
            .execute()

        return try makeDatabaseDecoder().decode([Post].self, from: response.data)
    }

    func fetchPost(postID: UUID) async throws -> Post? {
        let response = try await client
            .from("hot_feed_view")
            .select()
            .eq("id", value: postID.uuidString)
            .limit(1)
            .execute()

        let posts = try makeDatabaseDecoder().decode([Post].self, from: response.data)
        return posts.first
    }

    func fetchComments(
        postID: UUID,
        sort: CommentSortMode,
        limit: Int,
        offset: Int
    ) async throws -> [Comment] {
        let rangeEnd = max(offset + limit - 1, offset)
        switch sort {
        case .top:
            let response = try await client
                .from("post_comments_ranked")
                .select("id,post_id,user_id,body,parent_comment_id,created_at,reaction_count,hot_score")
                .eq("post_id", value: postID.uuidString)
                .range(from: offset, to: rangeEnd)
                .execute()
            return try makeDatabaseDecoder().decode([Comment].self, from: response.data)
        case .new:
            let response = try await client
                .from("comments")
                .select("id,post_id,user_id,body,parent_comment_id,created_at")
                .eq("post_id", value: postID.uuidString)
                .order("created_at", ascending: false)
                .range(from: offset, to: rangeEnd)
                .execute()
            return try makeDatabaseDecoder().decode([Comment].self, from: response.data)
        }
    }

    func insertComment(
        postId: UUID,
        body: String,
        parentCommentId: UUID?,
        userId: UUID,
        accessToken: String
    ) async throws {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        try await client
            .from("comments")
            .insert(
                CommentInsertPayload(
                    post_id: postId,
                    user_id: userId,
                    body: body,
                    parent_comment_id: parentCommentId
                )
            )
            .execute()
    }

    func fetchReactionTypes() async throws -> [ReactionType] {
        let response = try await client
            .from("reaction_types")
            .select("id,slug,display_name,emoji")
            .order("slug", ascending: true)
            .execute()

        return try JSONDecoder().decode([ReactionType].self, from: response.data)
    }

    func fetchReactionCounts(postID: UUID) async throws -> [PostReactionCount] {
        let response = try await client
            .from("post_reaction_counts")
            .select("post_id,reaction_type_id,count")
            .eq("post_id", value: postID.uuidString)
            .execute()

        return try JSONDecoder().decode([PostReactionCount].self, from: response.data)
    }

    func fetchCommentReactionCounts(
        commentIDs: [UUID]
    ) async throws -> [UUID: [CommentReactionCount]] {
        guard !commentIDs.isEmpty else { return [:] }

        let response = try await client
            .from("reactions")
            .select("comment_id,reaction_type_id")
            .in("comment_id", values: commentIDs.map(\.uuidString))
            .execute()

        let rows = try JSONDecoder().decode([CommentReactionRow].self, from: response.data)
        var countsByCommentAndType: [UUID: [UUID: Int]] = [:]

        for row in rows {
            countsByCommentAndType[row.comment_id, default: [:]][row.reaction_type_id, default: 0] += 1
        }

        var result: [UUID: [CommentReactionCount]] = [:]
        for (commentID, countsByType) in countsByCommentAndType {
            result[commentID] = countsByType.map { reactionTypeID, count in
                CommentReactionCount(comment_id: commentID, reaction_type_id: reactionTypeID, count: count)
            }
        }
        return result
    }

    func fetchReactionCounts(postIDs: [UUID]) async throws -> [UUID: [PostReactionCount]] {
        guard !postIDs.isEmpty else { return [:] }

        let response = try await client
            .from("post_reaction_counts")
            .select("post_id,reaction_type_id,count")
            .in("post_id", values: postIDs.map(\.uuidString))
            .execute()

        let rows = try JSONDecoder().decode([PostReactionCount].self, from: response.data)
        return Dictionary(grouping: rows, by: \.post_id)
    }

    func fetchViewerReactionsByPost(
        userID: UUID,
        postIDs: [UUID]
    ) async throws -> [UUID: Set<UUID>] {
        guard !postIDs.isEmpty else { return [:] }

        let response = try await client
            .from("reactions")
            .select("post_id,reaction_type_id")
            .eq("user_id", value: userID.uuidString)
            .in("post_id", values: postIDs.map(\.uuidString))
            .execute()

        let rows = try JSONDecoder().decode([UserReactionRow].self, from: response.data)
        var result: [UUID: Set<UUID>] = [:]
        for row in rows {
            result[row.post_id, default: []].insert(row.reaction_type_id)
        }
        return result
    }

    func fetchViewerReactionsByComment(
        userID: UUID,
        commentIDs: [UUID]
    ) async throws -> [UUID: Set<UUID>] {
        guard !commentIDs.isEmpty else { return [:] }

        let response = try await client
            .from("reactions")
            .select("comment_id,reaction_type_id")
            .eq("user_id", value: userID.uuidString)
            .in("comment_id", values: commentIDs.map(\.uuidString))
            .execute()

        let rows = try JSONDecoder().decode([UserCommentReactionRow].self, from: response.data)
        var result: [UUID: Set<UUID>] = [:]
        for row in rows {
            result[row.comment_id, default: []].insert(row.reaction_type_id)
        }
        return result
    }

    func addReaction(
        postId: UUID,
        reactionTypeId: UUID,
        userId: UUID,
        accessToken: String
    ) async throws {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        try await client
            .from("reactions")
            .insert(
                ReactionInsertPayload(
                    post_id: postId,
                    user_id: userId,
                    reaction_type_id: reactionTypeId
                )
            )
            .execute()
    }

    func removeReaction(
        postId: UUID,
        reactionTypeId: UUID,
        userId: UUID,
        accessToken: String
    ) async throws {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        try await client
            .from("reactions")
            .delete()
            .eq("post_id", value: postId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("reaction_type_id", value: reactionTypeId.uuidString)
            .execute()
    }

    func addCommentReaction(
        commentId: UUID,
        reactionTypeId: UUID,
        userId: UUID,
        accessToken: String
    ) async throws {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        try await client
            .from("reactions")
            .insert(
                CommentReactionInsertPayload(
                    comment_id: commentId,
                    user_id: userId,
                    reaction_type_id: reactionTypeId
                )
            )
            .execute()
    }

    func removeCommentReaction(
        commentId: UUID,
        reactionTypeId: UUID,
        userId: UUID,
        accessToken: String
    ) async throws {
        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)
        try await client
            .from("reactions")
            .delete()
            .eq("comment_id", value: commentId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("reaction_type_id", value: reactionTypeId.uuidString)
            .execute()
    }

    private static func postID(from action: AnyAction) -> UUID? {
        switch action {
        case .insert(let insertAction):
            return uuid(from: insertAction.record)
        case .update(let updateAction):
            return uuid(from: updateAction.record) ?? uuid(from: updateAction.oldRecord)
        case .delete(let deleteAction):
            return uuid(from: deleteAction.oldRecord)
        }
    }

    private static func uuid(from record: [String: AnyJSON]) -> UUID? {
        guard let postID = record["post_id"]?.stringValue else { return nil }
        return UUID(uuidString: postID)
    }

    private static func commentID(from action: AnyAction) -> UUID? {
        switch action {
        case .insert(let insertAction):
            return commentUUID(from: insertAction.record)
        case .update(let updateAction):
            return commentUUID(from: updateAction.record) ?? commentUUID(from: updateAction.oldRecord)
        case .delete(let deleteAction):
            return commentUUID(from: deleteAction.oldRecord)
        }
    }

    private static func commentUUID(from record: [String: AnyJSON]) -> UUID? {
        guard let commentID = record["comment_id"]?.stringValue else { return nil }
        return UUID(uuidString: commentID)
    }

    private func makeDatabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            if let date = Self.iso8601WithFractionalSeconds.date(from: raw)
                ?? Self.iso8601.date(from: raw)
                ?? Self.postgresTimestampWithFractionalSeconds.date(from: raw)
                ?? Self.postgresTimestamp.date(from: raw) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(raw)")
        }
        return decoder
    }
}
