import SwiftUI
import StoreKit

struct RootTabView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedTab: AppTab = .home

    private var resolvedColorScheme: ColorScheme {
        settings.preferredColorScheme ?? systemColorScheme
    }

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $selectedTab) {
                NavigationStack {
                    FeedView()
                }
                .tag(AppTab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

                NavigationStack {
                    ReleaseCalendarView()
                }
                .tag(AppTab.releaseCalendar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

                NavigationStack {
                    MyGamesView()
                }
                .tag(AppTab.myGames)
                .tabItem {
                    Label("My Games", systemImage: "gamecontroller.fill")
                }

                NavigationStack {
                    EsportsView()
                }
                .tag(AppTab.esports)
                .tabItem {
                    Label("Esports", systemImage: "trophy.fill")
                }
            }
            .modifier(IOSTabBarGlassModifier(useDarkChrome: resolvedColorScheme == .dark))
            .tint(AppTheme.accent)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .preferredColorScheme(settings.preferredColorScheme)
        .dynamicTypeSize(settings.largerText ? .xLarge : .large)
        .environment(\.legibilityWeight, settings.highContrastText ? .bold : nil)
    }

}

private struct IOSTabBarGlassModifier: ViewModifier {
    let useDarkChrome: Bool

    func body(content: Content) -> some View {
#if os(iOS)
        content
            .toolbarBackground((useDarkChrome ? Color.black : Color.white).opacity(0.90), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(useDarkChrome ? .dark : .light, for: .tabBar)
            .toolbarColorScheme(useDarkChrome ? .dark : .light, for: .navigationBar)
#else
        content
#endif
    }
}

struct SettingsSheetView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSubscriptionSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Management") {
                    NavigationLink {
                        AccountManagementView()
                    } label: {
                        Label("Manage Account", systemImage: "person.crop.circle")
                    }

                    HStack {
                        Text("Current User")
                        Spacer()
                        Text(settings.displayName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Email")
                        Spacer()
                        Text(settings.accountEmail)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Appearance") {
                    Picker("Color Theme", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.label)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Accessibility") {
                    Toggle("Reduce Motion", isOn: $settings.reduceMotion)
                    Toggle("Larger Text", isOn: $settings.largerText)
                    Toggle("High Contrast Text", isOn: $settings.highContrastText)
                }

                Section("PN Pro Membership") {
                    if storeKitManager.isPremium {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("PN Pro Active")
                                .font(.subheadline.weight(.semibold))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Upgrade to remove ads and unlock deeper customization.")
                                .font(.subheadline)
                            Text("Monthly: $7.99 · Annual: $69.99")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Upgrade to PN Pro") {
                            showSubscriptionSheet = true
                        }
                        Button("Compare Plans") {
                            showSubscriptionSheet = true
                        }
                    }
                }

                Section("Legal") {
                    NavigationLink {
                        EndUserAgreementView()
                    } label: {
                        Text("End User Agreement")
                    }

                    NavigationLink {
                        LegalTextView(title: "Privacy", bodyText: "Patch Notes privacy details and data handling policy will be listed here.")
                    } label: {
                        Text("Privacy Policy")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView()
            }
        }
    }
}

private struct AccountManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var isSigningOut = false
    @State private var signOutErrorMessage: String?

    var body: some View {
        Form {
            Section("Public Profile") {
                NavigationLink {
                    EditPublicProfileView()
                } label: {
                    Label("Edit Public Profile", systemImage: "person.text.rectangle")
                }

                HStack {
                    Text("Display Name")
                    Spacer()
                    Text(settings.displayName)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Email")
                    Spacer()
                    Text(settings.accountEmail)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Account") {
                Button("Manage Subscription") {
                    Task {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            try? await StoreKit.AppStore.showManageSubscriptions(in: windowScene)
                        }
                    }
                }

                Button(isSigningOut ? "Signing Out..." : "Sign Out") {
                    signOut()
                }
                .disabled(isSigningOut)
                .foregroundStyle(.red)

                if let signOutErrorMessage {
                    Text(signOutErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Account")
    }

    private func signOut() {
        Task {
            isSigningOut = true
            signOutErrorMessage = nil
            defer { isSigningOut = false }

            do {
                try await authManager.signOut()
                dismiss()
            } catch {
                signOutErrorMessage = error.localizedDescription
                print("Sign out failed:", error)
            }
        }
    }
}

private struct EditPublicProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @StateObject private var profileGate = ProfileGateViewModel()

    var body: some View {
        Group {
            switch profileGate.phase {
            case .idle, .loading:
                ZStack {
                    AppBackground()
                    ProgressView("Loading profile...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                .preferredColorScheme(.dark)
            case .error(let message):
                ZStack {
                    AppBackground()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        Text("Profile Load Error")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        Button("Retry") {
                            Task { await profileGate.refresh(session: authManager.session) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                }
                .preferredColorScheme(.dark)
            case .needsProfile(let profile), .ready(let profile):
                editProfileView(profile: profile)
            case .needsAvatar(let profile):
                editProfileView(profile: profile)
            case .needsGameSelection(let profile):
                editProfileView(profile: profile)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authManager.session?.user.id) {
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
        .onChange(of: profileGate.saveSuccessMessage) { _, saveSuccessMessage in
            guard saveSuccessMessage != nil else { return }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                if profileGate.saveSuccessMessage != nil {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func editProfileView(profile: AppUserProfileRecord?) -> some View {
        ProfileOnboardingView(
            mode: .editProfile,
            profile: profile,
            fallbackEmail: authManager.session?.user.email,
            isSaving: profileGate.isSaving,
            errorMessage: profileGate.saveErrorMessage,
            successMessage: profileGate.saveSuccessMessage
        ) { displayName, username in
            await profileGate.completeProfile(
                session: authManager.session,
                displayName: displayName,
                username: username,
                markOnboardingComplete: true
            )
        }
        .environmentObject(authManager)
        .environmentObject(settings)
    }
}

private struct EndUserAgreementView: View {
    var body: some View {
        LegalTextView(
            title: "End User Agreement",
            bodyText: "By using Patch Notes, users agree to follow platform rules, respect community standards, and comply with any applicable third-party terms for linked content providers. Prediction-market and commerce features will only be enabled where legally permitted and after identity and payment checks are complete."
        )
    }
}

private struct LegalTextView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
