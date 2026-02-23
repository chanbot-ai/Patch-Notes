import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    static let projectURL = URL(string: "https://lvapccwqypcvhijmevbh.supabase.co")!
    static let anonKey = "sb_publishable_inRAHwLlG_tkMBM5yH0R7Q_LbpmOqJ-"

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.anonKey
        )
    }

    func authenticatedClient(accessToken: String) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    accessToken: { accessToken }
                )
            )
        )
    }
}
