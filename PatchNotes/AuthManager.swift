import Supabase
import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {

    @Published var session: Session?

    private let client = SupabaseManager.shared.client

    init() {
        session = client.auth.currentSession

        Task {
            for await state in client.auth.authStateChanges {
                session = state.session
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
        // Optimistic local clear so root routing updates immediately even if the auth event stream lags.
        session = nil
    }

    func resendSignUpConfirmation(email: String) async throws {
        try await client.auth.resend(
            email: email,
            type: .signup
        )
    }
}
