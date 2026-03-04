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

    var hasProfileInfo: Bool {
        hasText(display_name) && hasText(username)
    }

    var preferredDisplayName: String {
        if let displayName = display_name?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }
        if let username = username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            if UsernameRules.isPlaceholderUsername(username) {
                return ""
            }
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
            return " "
        }

        let collapsed = String(mapped)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    static func isPlaceholderUsername(_ value: String) -> Bool {
        value.range(of: #"^user_[0-9a-f]{32}$"#, options: .regularExpression) != nil
    }

    static func isValidAppUsername(_ value: String) -> Bool {
        guard (minLength...maxLength).contains(value.count) else { return false }
        return value.range(of: #"^[a-z0-9]+$"#, options: .regularExpression) != nil
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

        if let explicitUsername, explicitUsername.contains("_") {
            return "Username cannot contain underscores. Use letters and numbers only."
        }

        let candidate = normalizedCandidate(from: source)

        guard let candidate else {
            return usingExplicitUsername
                ? "Username can only use letters and numbers."
                : "Add a username. We couldn't generate a valid one from your display name."
        }

        if candidate.count < minLength {
            return usingExplicitUsername
                ? "Username must be 3-32 characters."
                : "Add a username (3-32 characters). Your display name generates a username that is too short."
        }

        if !isValidAppUsername(candidate) {
            return "Username must be 3-32 lowercase letters or numbers."
        }

        return nil
    }
}

@MainActor
final class ProfileGateViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        case needsProfile(AppUserProfileRecord?)
        case needsGameSelection(AppUserProfileRecord)
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
            } else if let profile, profile.hasProfileInfo {
                phase = .needsGameSelection(profile)
            } else {
                phase = .needsProfile(profile)
            }
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func completeProfile(session: Session?, displayName: String, username: String?, markOnboardingComplete: Bool = false) async {
        guard let session else { return }

        isSaving = true
        saveErrorMessage = nil
        saveSuccessMessage = nil

        do {
            try await service.upsertProfile(
                userID: session.user.id,
                displayName: displayName,
                username: username,
                markOnboardingComplete: markOnboardingComplete,
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

    func completeGameSelection(session: Session?, gameIDs: [UUID]) async {
        guard let session else { return }

        isSaving = true
        saveErrorMessage = nil
        saveSuccessMessage = nil

        do {
            try await FeedService().bulkFollowGames(
                userID: session.user.id,
                gameIDs: gameIDs,
                accessToken: session.accessToken
            )

            // Save first 3 selections as profile badges
            if gameIDs.count >= 3 {
                try await FeedService().setFavoriteGames(
                    userID: session.user.id,
                    gameIDs: Array(gameIDs.prefix(3)),
                    accessToken: session.accessToken
                )
            }

            try await service.markOnboardingComplete(
                userID: session.user.id,
                accessToken: session.accessToken
            )

            isSaving = false
            saveSuccessMessage = "You're all set!"
            try? await Task.sleep(nanoseconds: 500_000_000)
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

    func isUsernameAvailable(
        candidate: String,
        excludingUserID: UUID,
        accessToken: String
    ) async throws -> Bool {
        let response = try await authedClient(accessToken: accessToken)
            .rpc(
                "is_username_available",
                params: UsernameAvailabilityParams(
                    candidate: candidate,
                    requester_user_id: excludingUserID
                )
            )
            .execute()

        return try decodeUsernameAvailability(from: response.data)
    }

    func markOnboardingComplete(
        userID: UUID,
        accessToken: String
    ) async throws {
        let client = try authedClient(accessToken: accessToken)
        try await client
            .from("users")
            .update(["onboarding_complete": true])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    func upsertProfile(
        userID: UUID,
        displayName: String,
        username: String?,
        markOnboardingComplete: Bool = true,
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

        let client = try authedClient(accessToken: accessToken)

        do {
            try await client
                .from("users")
                .upsert(
                    FullProfileUpsert(
                        id: userID,
                        display_name: trimmedDisplayName,
                        username: resolvedUsername,
                        onboarding_complete: markOnboardingComplete
                    ),
                    onConflict: "id"
                )
                .execute()
            return
        } catch {
            throw mapProfileWriteError(error)
        }
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

    private struct UsernameAvailabilityParams: Encodable {
        let candidate: String
        let requester_user_id: UUID
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

    private func decodeUsernameAvailability(from data: Data) throws -> Bool {
        let decoder = JSONDecoder()

        if let value = try? decoder.decode(Bool.self, from: data) {
            return value
        }

        if let object = try? decoder.decode([String: Bool].self, from: data),
           let value = object.values.first {
            return value
        }

        if let array = try? decoder.decode([Bool].self, from: data),
           let value = array.first {
            return value
        }

        if let array = try? decoder.decode([[String: Bool]].self, from: data),
           let value = array.first?.values.first {
            return value
        }

        throw NSError(
            domain: "PatchNotes.Profile",
            code: 9,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected username availability response."]
        )
    }

    private func mapProfileWriteError(_ error: Error) -> Error {
        let message = [
            error.localizedDescription,
            String(describing: error)
        ]
        .joined(separator: " | ")
        .lowercased()

        if message.contains("users_username_key") || message.contains("duplicate key value violates unique constraint") {
            return NSError(
                domain: "PatchNotes.Profile",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "That username is already taken. Try another one."]
            )
        }

        if message.contains("users_username_allowed_values_check") {
            return NSError(
                domain: "PatchNotes.Profile",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Username must be 3-32 lowercase letters or numbers."]
            )
        }

        if message.contains("users_onboarding_complete_requires_real_username_check") {
            return NSError(
                domain: "PatchNotes.Profile",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "Please choose a real username before continuing."]
            )
        }

        return error
    }
}

struct ProfileOnboardingView: View {
    enum Mode {
        case onboarding
        case editProfile

        var title: String {
            switch self {
            case .onboarding: return "Complete Profile"
            case .editProfile: return "Edit Profile"
            }
        }

        var subtitle: String {
            switch self {
            case .onboarding:
                return "Add a display name to get started."
            case .editProfile:
                return "Update your public profile details."
            }
        }

        var primaryButtonTitle: String {
            switch self {
            case .onboarding: return "Next"
            case .editProfile: return "Save Profile"
            }
        }

        var successButtonTitle: String {
            switch self {
            case .onboarding: return "Profile Saved"
            case .editProfile: return "Saved"
            }
        }

        var showsSignOut: Bool {
            switch self {
            case .onboarding: return true
            case .editProfile: return false
            }
        }
    }

    private enum UsernameAvailabilityState: Equatable {
        case idle
        case checking(String)
        case available(String)
        case taken(String)
        case error(String)
    }

    let mode: Mode
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
    @State private var usernameAvailability: UsernameAvailabilityState = .idle

    init(
        mode: Mode = .onboarding,
        profile: AppUserProfileRecord?,
        fallbackEmail: String?,
        isSaving: Bool,
        errorMessage: String?,
        successMessage: String?,
        onSave: @escaping @MainActor (_ displayName: String, _ username: String?) async -> Void
    ) {
        self.mode = mode
        self.profile = profile
        self.fallbackEmail = fallbackEmail
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.successMessage = successMessage
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            DarkAuthBackground()

            ScrollView {
                VStack(spacing: 18) {
                    DarkAuthContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(mode.title)
                                    .font(.title2.weight(.bold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.white)

                                Text(mode.subtitle)
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
                                title: "Username",
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
                                Text("Username must be 3-32 lowercase letters or numbers. Underscores are not allowed.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.56))
                                    .padding(.horizontal, 2)
                            }

                            usernameAvailabilityView

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
                                            : (successMessage != nil ? mode.successButtonTitle : mode.primaryButtonTitle)
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
                            .disabled(isSaveButtonDisabled)
                            .opacity(isSaveButtonDisabled ? 0.6 : 1)

                            if mode.showsSignOut {
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
        .task(id: usernameAvailabilityLookupKey) {
            await refreshUsernameAvailability()
        }
    }

    private var emailLabel: String? {
        profile?.email ?? fallbackEmail
    }

    private var emailLocalPartDisplayNameSeed: String? {
        guard let email = emailLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty,
              let atIndex = email.firstIndex(of: "@") else {
            return nil
        }

        let localPart = email[..<atIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localPart.isEmpty else { return nil }
        return String(localPart)
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

    private var usernameAvailabilityCandidate: String? {
        guard usernameValidationMessage == nil else { return nil }
        guard !trimmedDisplayName.isEmpty else { return nil }
        return UsernameRules.onboardingCandidate(
            displayName: trimmedDisplayName,
            username: trimmedUsername.isEmpty ? nil : trimmedUsername
        )
    }

    private var usernameAvailabilityLookupKey: String {
        let userID = authManager.session?.user.id.uuidString ?? "no-session"
        let candidate = usernameAvailabilityCandidate ?? "no-candidate"
        return "\(mode)|\(userID)|\(candidate)"
    }

    private var isSaveButtonDisabled: Bool {
        if isSaving || successMessage != nil || trimmedDisplayName.isEmpty || usernameValidationMessage != nil {
            return true
        }

        if case .checking = effectiveUsernameAvailability {
            return true
        }
        if case .taken = effectiveUsernameAvailability {
            return true
        }

        return false
    }

    @ViewBuilder
    private var usernameAvailabilityView: some View {
        switch effectiveUsernameAvailability {
        case .idle:
            EmptyView()
        case .checking(let candidate):
            HStack(alignment: .top, spacing: 8) {
                ProgressView().tint(.white.opacity(0.85))
                    .scaleEffect(0.8)
                Text("Checking @\(candidate)…")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 2)
        case .available(let candidate):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("@\(candidate) is available")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, 2)
        case .taken(let candidate):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text("@\(candidate) is already taken")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 2)
        case .error(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.80))
            }
            .padding(.horizontal, 2)
        }
    }

    private var effectiveUsernameAvailability: UsernameAvailabilityState {
        guard let candidate = usernameAvailabilityCandidate else { return .idle }

        switch usernameAvailability {
        case .idle:
            return .idle
        case .checking(let stateCandidate) where stateCandidate == candidate:
            return usernameAvailability
        case .available(let stateCandidate) where stateCandidate == candidate:
            return usernameAvailability
        case .taken(let stateCandidate) where stateCandidate == candidate:
            return usernameAvailability
        case .error:
            return usernameAvailability
        default:
            return .idle
        }
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
                let safeSettingsDisplayName = UsernameRules.isPlaceholderUsername(settings.displayName) ? "" : settings.displayName
                displayName = profile.display_name ?? safeProfileUsername ?? emailLocalPartDisplayNameSeed ?? safeSettingsDisplayName
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
                let cachedName = settings.displayName
                let shouldHideCachedPlaceholder = UsernameRules.isPlaceholderUsername(cachedName)
                let safeCachedName = (settings.displayName == "Chan" || shouldHideCachedPlaceholder) ? "" : settings.displayName
                displayName = emailLocalPartDisplayNameSeed ?? safeCachedName
            }
        }

#if DEBUG
        print(
            """
            [ProfileOnboarding][seedFieldsIfNeeded] mode=\(String(describing: mode)) force=\(force) \
            hasProfile=\(profile != nil) email=\(emailLabel ?? "nil") profileDisplayName=\(profile?.display_name ?? "nil") \
            profileUsername=\(profile?.username ?? "nil") settingsDisplayName=\(settings.displayName) \
            seededDisplayName=\(displayName) seededUsername=\(username)
            """
        )
#endif

        hasSeeded = true
    }

    private func save() {
        guard usernameValidationMessage == nil else { return }
        guard let session = authManager.session else { return }

        let submittedUsername: String?
        if let generatedUsernamePreview, !trimmedUsername.isEmpty {
            username = generatedUsernamePreview
            submittedUsername = generatedUsernamePreview
        } else if trimmedUsername.isEmpty {
            submittedUsername = nil
        } else {
            submittedUsername = trimmedUsername
        }

        Task {
            if let candidate = UsernameRules.onboardingCandidate(
                displayName: trimmedDisplayName,
                username: submittedUsername
            ) {
                usernameAvailability = .checking(candidate)

                do {
                    let isAvailable = try await UserProfileService().isUsernameAvailable(
                        candidate: candidate,
                        excludingUserID: session.user.id,
                        accessToken: session.accessToken
                    )
                    usernameAvailability = isAvailable ? .available(candidate) : .taken(candidate)
                    guard isAvailable else { return }
                } catch {
                    usernameAvailability = .error("Couldn’t check username availability right now.")
                    return
                }
            }

            await onSave(
                trimmedDisplayName,
                submittedUsername
            )
        }
    }

    private func refreshUsernameAvailability() async {
        guard let session = authManager.session else {
            usernameAvailability = .idle
            return
        }

        guard let candidate = usernameAvailabilityCandidate else {
            usernameAvailability = .idle
            return
        }

        if let currentUsername = profile?.username, currentUsername == candidate {
            usernameAvailability = .available(candidate)
            return
        }

        usernameAvailability = .checking(candidate)

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            return
        }

        guard candidate == usernameAvailabilityCandidate else { return }

        do {
            let isAvailable = try await UserProfileService().isUsernameAvailable(
                candidate: candidate,
                excludingUserID: session.user.id,
                accessToken: session.accessToken
            )

            guard candidate == usernameAvailabilityCandidate else { return }
            usernameAvailability = isAvailable ? .available(candidate) : .taken(candidate)
        } catch {
            guard candidate == usernameAvailabilityCandidate else { return }
            usernameAvailability = .error("Couldn’t check username availability right now.")
        }
    }

    private func signOut() {
        Task {
            try? await authManager.signOut()
        }
    }
}
