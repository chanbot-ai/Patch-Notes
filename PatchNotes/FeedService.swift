import Foundation
import Supabase

final class FeedService {

    private let client = SupabaseManager.shared.client
    private var postMetricsChannel: RealtimeChannelV2?
    private var postMetricsSubscription: RealtimeSubscription?
    var onPostMetricsChange: (@MainActor @Sendable (UUID?) -> Void)?
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

    func fetchHotFeed() async throws -> [Post] {
        let response = try await client
            .from("hot_feed_view")
            .select()
            .limit(50)
            .execute()

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

        return try decoder.decode([Post].self, from: response.data)
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
}
