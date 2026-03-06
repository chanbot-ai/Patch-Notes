import SwiftUI

@main
struct PatchNotesApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var authManager = AuthManager()

    private var authSessionSyncKey: String {
        let userID = authManager.session?.user.id.uuidString ?? "no-user"
        let token = authManager.session?.accessToken ?? "no-token"
        return "\(userID)|\(token)"
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.session != nil {
                    AuthenticatedRootView()
                } else {
                    AuthView()
                }
            }
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(authManager)
                .onAppear {
                    store.setAuthenticatedSession(authManager.session)
                    guard authManager.session != nil else { return }
                    store.startHotFeed()
                }
                .onChange(of: authSessionSyncKey) { _, _ in
                    store.setAuthenticatedSession(authManager.session)
                    guard authManager.session?.user.id != nil else { return }
                    store.startHotFeed()
                }
        }
    }
}

private struct AuthenticatedRootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var settings: AppSettings

    @StateObject private var profileGate = ProfileGateViewModel()

    var body: some View {
        Group {
            switch profileGate.phase {
            case .idle, .loading:
                ZStack {
                    AppBackground()

                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.1)
                        Text("Loading profile…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.80))
                    }
                }
                .preferredColorScheme(.dark)

            case .needsProfile(let profile):
                ProfileOnboardingView(
                    profile: profile,
                    fallbackEmail: authManager.session?.user.email,
                    isSaving: profileGate.isSaving,
                    errorMessage: profileGate.saveErrorMessage,
                    successMessage: profileGate.saveSuccessMessage
                ) { displayName, username in
                    await profileGate.completeProfile(
                        session: authManager.session,
                        displayName: displayName,
                        username: username
                    )
                }

            case .needsAvatar:
                AvatarSelectionView(
                    onComplete: { selectedSlug in
                        await profileGate.completeAvatarSelection(
                            session: authManager.session,
                            slug: selectedSlug
                        )
                    },
                    isSaving: profileGate.isSaving,
                    errorMessage: profileGate.saveErrorMessage
                )

            case .needsGameSelection:
                GameSelectionOnboardingView(
                    onComplete: { selectedGameIDs in
                        await profileGate.completeGameSelection(
                            session: authManager.session,
                            gameIDs: selectedGameIDs
                        )
                    },
                    isSaving: profileGate.isSaving,
                    errorMessage: profileGate.saveErrorMessage
                )

            case .ready:
                AppBootstrapView()

            case .error(let message):
                ZStack {
                    AppBackground()

                    VStack(spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Profile Setup Error")
                                    .font(.title3.weight(.bold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.white)

                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.80))

                                Button {
                                    Task {
                                        await profileGate.refresh(session: authManager.session)
                                    }
                                } label: {
                                    Text("Retry")
                                        .font(.headline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [AppTheme.accent, AppTheme.accentBlue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)

                                Button("Sign Out", role: .destructive) {
                                    Task { try? await authManager.signOut() }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(16)
                }
                .preferredColorScheme(.dark)
            }
        }
        .task(id: authManager.session?.user.id) {
            if let email = authManager.session?.user.email, !email.isEmpty {
                settings.accountEmail = email
            }
            await profileGate.refresh(session: authManager.session)
        }
        .onChange(of: profileGate.currentProfile) { _, profile in
            guard let profile else { return }

            if let profileEmail = profile.email?.trimmingCharacters(in: .whitespacesAndNewlines), !profileEmail.isEmpty {
                settings.accountEmail = profileEmail
            }

            let preferredName = profile.preferredDisplayName
            if !preferredName.isEmpty {
                settings.displayName = preferredName
            }
        }
    }
}

private struct AppBootstrapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettings

    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity = 0.0
    @State private var glowOpacity = 0.0

    private var shouldReduceMotion: Bool {
        reduceMotion || settings.reduceMotion
    }

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                AppBackground()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.35))
                            .frame(width: 180, height: 180)
                            .blur(radius: 24)
                            .opacity(glowOpacity)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.08, green: 0.10, blue: 0.22), Color(red: 0.03, green: 0.05, blue: 0.14)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 132, height: 132)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            }

                        ZStack {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(AppTheme.accent)
                                .offset(x: 0, y: -18)

                            Text("PN")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .offset(y: 16)
                        }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    Text("PATCH NOTES")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white.opacity(logoOpacity))
                        .tracking(2.2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Patch Notes")
            }
        }
        .onAppear {
            animateSplash()
        }
    }

    private func animateSplash() {
        if shouldReduceMotion {
            logoOpacity = 1
            glowOpacity = 1
            logoScale = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.20)) {
                    showSplash = false
                }
            }
            return
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.80)) {
            logoScale = 1
            logoOpacity = 1
        }

        withAnimation(.easeInOut(duration: 0.90).repeatForever(autoreverses: true)) {
            glowOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.30)) {
                showSplash = false
            }
        }
    }
}
