import SwiftUI
import Foundation
import Supabase

struct AppUserProfileRecord: Identifiable, Decodable, Equatable {
    let id: UUID
    let email: String?
    let display_name: String?
    let username: String?
    let onboarding_complete: Bool?

    var isComplete: Bool {
        if let onboardingComplete = onboarding_complete {
            return onboardingComplete
        }
        // Backward-compatible fallback for rows that predate onboarding_complete.
        return hasText(display_name) || hasText(username)
    }

    var preferredDisplayName: String {
        if let displayName = display_name?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }
        if let username = username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return username
        }
        return ""
    }

    private func hasText(_ value: String?) -> Bool {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !trimmed.isEmpty
    }
}

private enum UsernameRules {
    static let minLength = 3
    static let maxLength = 32

    static func normalizedCandidate(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.lowercaseLetters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
                return Character(scalar)
            }
            if scalar == "_" || scalar == "-" || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return "_"
            }
            return "_"
        }

        let collapsed = String(mapped)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    static func isPlaceholderUsername(_ value: String) -> Bool {
        value.range(of: #"^user_[0-9a-f]{32}$"#, options: .regularExpression) != nil
    }

    static func isValidAppUsername(_ value: String) -> Bool {
        guard (minLength...maxLength).contains(value.count) else { return false }
        guard value.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil else { return false }
        return !value.hasPrefix("user_")
    }

    static func onboardingCandidate(displayName: String, username: String?) -> String? {
        let explicitUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = (explicitUsername?.isEmpty == false) ? explicitUsername : displayName
        return normalizedCandidate(from: source)
    }

    static func onboardingValidationMessage(displayName: String, username: String?) -> String? {
        let explicitUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usingExplicitUsername = explicitUsername?.isEmpty == false
        let source = usingExplicitUsername ? explicitUsername : displayName
        let candidate = normalizedCandidate(from: source)

        guard let candidate else {
            return usingExplicitUsername
                ? "Username can only use letters, numbers, and underscores."
                : "Add a username. We couldn't generate a valid one from your display name."
        }

        if candidate.hasPrefix("user_") {
            return "Usernames starting with user_ are reserved. Choose a different username."
        }

        if candidate.count < minLength {
            return usingExplicitUsername
                ? "Username must be 3-32 characters."
                : "Add a username (3-32 characters). Your display name generates a username that is too short."
        }

        if !isValidAppUsername(candidate) {
            return "Username must be 3-32 lowercase letters, numbers, or underscores."
        }

        return nil
    }
}

@MainActor
final class ProfileGateViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        case needsCompletion(AppUserProfileRecord?)
        case ready(AppUserProfileRecord?)
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var currentProfile: AppUserProfileRecord?
    @Published var isSaving = false
    @Published var saveErrorMessage: String?
    @Published var saveSuccessMessage: String?

    private let service = UserProfileService()
    private var lastLoadedUserID: UUID?

    func refresh(session: Session?) async {
        guard let session else {
            currentProfile = nil
            phase = .idle
            lastLoadedUserID = nil
            saveSuccessMessage = nil
            return
        }

        let userID = session.user.id
        if lastLoadedUserID != userID {
            phase = .loading
            currentProfile = nil
            saveErrorMessage = nil
            saveSuccessMessage = nil
            lastLoadedUserID = userID
        }

        do {
            let profile = try await service.fetchProfile(
                userID: userID,
                accessToken: session.accessToken
            )
            currentProfile = profile
            if let profile, profile.isComplete {
                phase = .ready(profile)
            } else {
                phase = .needsCompletion(profile)
            }
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func completeProfile(session: Session?, displayName: String, username: String?) async {
        guard let session else { return }

        isSaving = true
        saveErrorMessage = nil
        saveSuccessMessage = nil

        do {
            try await service.upsertProfile(
                userID: session.user.id,
                displayName: displayName,
                username: username,
                accessToken: session.accessToken
            )
            saveSuccessMessage = "Profile saved"
            isSaving = false
            try? await Task.sleep(nanoseconds: 650_000_000)
            await refresh(session: session)
        } catch {
            isSaving = false
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct UserProfileService {
    func fetchProfile(userID: UUID, accessToken: String) async throws -> AppUserProfileRecord? {
        let rows: [AppUserProfileRecord] = try await authedClient(accessToken: accessToken)
            .from("users")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func upsertProfile(
        userID: UUID,
        displayName: String,
        username: String?,
        accessToken: String
    ) async throws {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty else {
            throw NSError(
                domain: "PatchNotes.Profile",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Display name is required."]
            )
        }

        if let validationMessage = UsernameRules.onboardingValidationMessage(
            displayName: trimmedDisplayName,
            username: username
        ) {
            throw NSError(
                domain: "PatchNotes.Profile",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: validationMessage]
            )
        }

        guard let resolvedUsername = UsernameRules.onboardingCandidate(
            displayName: trimmedDisplayName,
            username: username
        ) else {
            throw NSError(
                domain: "PatchNotes.Profile",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Please choose a valid username before continuing."]
            )
        }

        var capturedError: Error?
        let client = try authedClient(accessToken: accessToken)

        do {
            try await client
                .from("users")
                .upsert(
                    FullProfileUpsert(
                        id: userID,
                        display_name: trimmedDisplayName,
                        username: resolvedUsername,
                        onboarding_complete: true
                    ),
                    onConflict: "id"
                )
                .execute()
            return
        } catch {
            capturedError = error
        }

        do {
            try await client
                .from("users")
                .upsert(
                    DisplayNameOnlyUpsert(
                        id: userID,
                        display_name: trimmedDisplayName,
                        onboarding_complete: true
                    ),
                    onConflict: "id"
                )
                .execute()
            return
        } catch {
            capturedError = error
        }

        if !resolvedUsername.isEmpty {
            do {
                try await client
                    .from("users")
                    .upsert(
                        UsernameOnlyUpsert(
                            id: userID,
                            username: resolvedUsername,
                            onboarding_complete: true
                        ),
                        onConflict: "id"
                    )
                    .execute()
                return
            } catch {
                capturedError = error
            }
        }

        throw capturedError ?? NSError(
            domain: "PatchNotes.Profile",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unable to save profile."]
        )
    }

    private func authedClient(accessToken: String) throws -> SupabaseClient {
        let trimmedToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw NSError(
                domain: "PatchNotes.Profile",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Your session is missing an access token. Please sign out and sign in again."]
            )
        }

        return SupabaseManager.shared.authenticatedClient(accessToken: trimmedToken)
    }

    private struct FullProfileUpsert: Encodable {
        let id: UUID
        let display_name: String
        let username: String?
        let onboarding_complete: Bool
    }

    private struct DisplayNameOnlyUpsert: Encodable {
        let id: UUID
        let display_name: String
        let onboarding_complete: Bool
    }

    private struct UsernameOnlyUpsert: Encodable {
        let id: UUID
        let username: String
        let onboarding_complete: Bool
    }
}

struct ProfileOnboardingView: View {
    let profile: AppUserProfileRecord?
    let fallbackEmail: String?
    let isSaving: Bool
    let errorMessage: String?
    let successMessage: String?
    let onSave: @MainActor (_ displayName: String, _ username: String?) async -> Void

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var settings: AppSettings

    @State private var displayName = ""
    @State private var username = ""
    @State private var hasSeeded = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Complete Profile")
                                    .font(.title2.weight(.bold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.white)

                                Text("Add a display name before entering the app. Your `public.users` row is used as the source of truth.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.70))
                            }

                            if let emailLabel, !emailLabel.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundStyle(AppTheme.accentBlue)
                                    Text(emailLabel)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                                }
                            }

                            formField(
                                title: "Display Name",
                                icon: "person.fill",
                                text: $displayName,
                                prompt: "How your name appears in-app"
                            )

                            formField(
                                title: "Username (optional)",
                                icon: "at",
                                text: $username,
                                prompt: "Used for mentions and URLs"
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            if let usernameValidationMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.orange)
                                    Text(usernameValidationMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                .padding(.horizontal, 2)
                            } else if let generatedUsernamePreview {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.triangle.swap")
                                        .foregroundStyle(AppTheme.accentBlue.opacity(0.95))
                                    Text(trimmedUsername.isEmpty ? "Username will be set to @\(generatedUsernamePreview)." : "Will save as @\(generatedUsernamePreview).")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.70))
                                }
                                .padding(.horizontal, 2)
                            } else {
                                Text("Username must be 3-32 lowercase letters, numbers, or underscores. Prefix user_ is reserved.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.56))
                                    .padding(.horizontal, 2)
                            }

                            if let errorMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.88))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.red.opacity(0.24), lineWidth: 1)
                                }
                            }

                            if let successMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(successMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.88))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.green.opacity(0.24), lineWidth: 1)
                                }
                            }

                            Button {
                                save()
                            } label: {
                                HStack(spacing: 10) {
                                    if isSaving {
                                        ProgressView().tint(.white)
                                    } else if successMessage != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline.weight(.semibold))
                                    }
                                    Text(
                                        isSaving
                                            ? "Saving..."
                                            : (successMessage != nil ? "Profile Saved" : "Continue to Patch Notes")
                                    )
                                        .font(.headline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accentBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isSaving || successMessage != nil || trimmedDisplayName.isEmpty || usernameValidationMessage != nil)
                            .opacity((isSaving || successMessage != nil || trimmedDisplayName.isEmpty || usernameValidationMessage != nil) ? 0.6 : 1)

                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Text("Sign Out")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSaving)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            seedFieldsIfNeeded(force: false)
        }
        .onChange(of: profile?.id) { _, _ in
            seedFieldsIfNeeded(force: true)
        }
    }

    private var emailLabel: String? {
        profile?.email ?? fallbackEmail
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usernameValidationMessage: String? {
        guard !trimmedDisplayName.isEmpty else { return nil }
        return UsernameRules.onboardingValidationMessage(
            displayName: trimmedDisplayName,
            username: trimmedUsername.isEmpty ? nil : trimmedUsername
        )
    }

    private var generatedUsernamePreview: String? {
        guard !trimmedDisplayName.isEmpty else { return nil }
        guard usernameValidationMessage == nil else { return nil }

        let explicitUsername = trimmedUsername.isEmpty ? nil : trimmedUsername
        guard let candidate = UsernameRules.onboardingCandidate(
            displayName: trimmedDisplayName,
            username: explicitUsername
        ) else {
            return nil
        }

        if let explicitUsername, explicitUsername == candidate {
            return nil
        }

        return candidate
    }

    private func formField(
        title: String,
        icon: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.64))
                    .frame(width: 18)

                TextField(
                    "",
                    text: text,
                    prompt: Text(prompt).foregroundStyle(.white.opacity(0.34))
                )
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func seedFieldsIfNeeded(force: Bool) {
        guard force || !hasSeeded else { return }

        if let profile {
            if displayName.isEmpty || force {
                let safeProfileUsername = profile.username.flatMap { UsernameRules.isPlaceholderUsername($0) ? nil : $0 }
                displayName = profile.display_name ?? safeProfileUsername ?? settings.displayName
            }
            if username.isEmpty || force {
                if let profileUsername = profile.username, !UsernameRules.isPlaceholderUsername(profileUsername) {
                    username = profileUsername
                } else {
                    username = ""
                }
            }
        } else {
            if displayName.isEmpty || force {
                displayName = settings.displayName == "Chan" ? "" : settings.displayName
            }
        }

        hasSeeded = true
    }

    private func save() {
        guard usernameValidationMessage == nil else { return }

        if let generatedUsernamePreview, !trimmedUsername.isEmpty {
            username = generatedUsernamePreview
        }

        Task {
            await onSave(
                trimmedDisplayName,
                trimmedUsername.isEmpty ? nil : trimmedUsername
            )
        }
    }

    private func signOut() {
        Task {
            try? await authManager.signOut()
        }
    }
}
