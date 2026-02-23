import Foundation
import Supabase

final class PublicProfileService {
    private let client = SupabaseManager.shared.client

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

    func fetchPublicProfile(id: UUID) async throws -> PublicProfile? {
        let response = try await client
            .from("public_profiles")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()

        return try decodeProfiles(from: response.data).first
    }

    func fetchPublicProfile(username: String) async throws -> PublicProfile? {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedUsername.isEmpty else { return nil }

        let response = try await client
            .from("public_profiles")
            .select()
            .eq("username", value: normalizedUsername)
            .limit(1)
            .execute()

        return try decodeProfiles(from: response.data).first
    }

    func fetchPublicProfiles(limit: Int = 25) async throws -> [PublicProfile] {
        let response = try await client
            .from("public_profiles")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        return try decodeProfiles(from: response.data)
    }

    private func decodeProfiles(from data: Data) throws -> [PublicProfile] {
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

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid profile date: \(raw)"
            )
        }

        return try decoder.decode([PublicProfile].self, from: data)
    }
}
