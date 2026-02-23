import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false

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
                    SocialView()
                }
                .tag(AppTab.social)
                .tabItem {
                    Label("Social", systemImage: "bubble.left.and.bubble.right.fill")
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
            .overlay(alignment: .topTrailing) {
                settingsButton
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .preferredColorScheme(settings.preferredColorScheme)
        .dynamicTypeSize(settings.largerText ? .xLarge : .large)
        .environment(\.legibilityWeight, settings.highContrastText ? .bold : nil)
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .environmentObject(settings)
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [AppTheme.surfaceTop.opacity(0.92), AppTheme.surfaceBottom.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.30), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 16)
        .accessibilityLabel("Open settings")
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

private struct SettingsSheetView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Upgrade to remove ads and unlock deeper customization.")
                            .font(.subheadline)
                        Text("Monthly: $7.99 · Annual: $69.99")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Upgrade to PN Pro") {}
                    Button("Compare Plans") {}
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
        }
    }
}

private struct AccountManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager

    @State private var isSigningOut = false
    @State private var signOutErrorMessage: String?

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display Name", text: $settings.displayName)
                    .textInputAutocapitalization(.words)
                TextField("Email", text: $settings.accountEmail)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Section("Account") {
                Button("Manage Subscription") {}

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
            } catch {
                signOutErrorMessage = error.localizedDescription
                print("Sign out failed:", error)
            }
        }
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
