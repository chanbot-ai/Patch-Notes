import SwiftUI

struct ProfileDrawerView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var settings: AppSettings

    @State private var showSettings = false
    @State private var showAvatarPicker = false
    @State private var showAvatarConfirm = false
    @State private var dragOffset: CGFloat = 0

    private let drawerWidth: CGFloat = UIScreen.main.bounds.width * 0.82

    private var displayName: String {
        let name = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "User" : name
    }

    private var username: String? {
        let email = settings.accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? nil : email
    }

    private var memberSinceText: String? {
        guard let session = authManager.session else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "Member since \(formatter.string(from: session.user.createdAt))"
    }

    private var userBadges: [DisplayBadge] {
        guard let userID = authManager.session?.user.id else { return [] }
        return store.displayBadges(for: userID)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Scrim
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                }

            // Drawer panel
            NavigationStack {
                drawerContent
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .frame(width: drawerWidth)
            .background(AppTheme.surfaceTop)
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.6), radius: 20, x: 5)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if value.translation.width < -80 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(duration: 0.25)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView()
                .environmentObject(settings)
        }
    }

    // MARK: - Drawer Content

    private var drawerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header: close + gear
                headerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // Avatar + profile info
                profileSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                // Menu items
                menuSection
                    .padding(.top, 12)

                Spacer(minLength: 40)
            }
        }
        .background(AppTheme.surfaceTop)
        .preferredColorScheme(.dark)
        .navigationDestination(isPresented: $showAvatarPicker) {
            AvatarSelectionView(
                onComplete: { slug in
                    store.updateAvatar(slug: slug)
                    showAvatarPicker = false
                },
                isSaving: false,
                errorMessage: nil,
                milestones: store.currentUserMilestones,
                initialSlug: store.currentUserAvatarSlug
            )
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Avatar (tappable)
            Button {
                showAvatarConfirm = true
            } label: {
                Text(store.currentUserAvatarEmoji)
                    .font(.system(size: 44))
                    .frame(width: 72, height: 72)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .confirmationDialog("", isPresented: $showAvatarConfirm, titleVisibility: .hidden) {
                Button("Change Avatar") { showAvatarPicker = true }
                Button("Cancel", role: .cancel) {}
            }

            // Name + badges
            HStack(spacing: 8) {
                Text(displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                if !userBadges.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(userBadges.prefix(3)) { badge in
                            Text(badge.emoji)
                                .font(.system(size: 14))
                        }
                    }
                }
            }

            if let username {
                Text(username)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            if let memberSince = memberSinceText {
                Text(memberSince)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 0) {
            Button {
                showAvatarPicker = true
            } label: {
                menuRow(icon: "face.smiling.inverse", label: "Change Avatar")
            }

            NavigationLink {
                BadgeManagementView()
            } label: {
                menuRow(icon: "medal.fill", label: "Manage Badges")
            }

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.vertical, 8)

            Button {
                showSettings = true
            } label: {
                menuRow(icon: "gearshape.fill", label: "Settings")
            }
        }
    }

    private func menuRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28)

            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
