import SwiftUI

struct AvatarSelectionView: View {
    let onComplete: @MainActor (_ selectedSlug: String) async -> Void
    let isSaving: Bool
    let errorMessage: String?
    var milestones: UserMilestones? = nil
    var initialSlug: String? = nil

    @EnvironmentObject private var storeKitManager: StoreKitManager

    @State private var selectedSlug: String = "gamer_1"
    @State private var didSetInitial = false

    private let columns = [
        GridItem(.adaptive(minimum: 56), spacing: 10)
    ]

    var body: some View {
        ZStack {
            DarkAuthBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(AvatarCatalog.categories, id: \.self) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }

                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !didSetInitial, let slug = initialSlug {
                selectedSlug = slug
                didSetInitial = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose Your Avatar")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)

            Text("Pick an emoji avatar that represents you.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.70))

            HStack(spacing: 10) {
                Text(AvatarCatalog.emoji(for: selectedSlug))
                    .font(.system(size: 36))
                    .frame(width: 52, height: 52)
                    .background(AppTheme.accent.opacity(0.20), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.45), lineWidth: 2)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(AvatarCatalog.avatar(for: selectedSlug)?.label ?? "Avatar")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(AvatarCatalog.avatar(for: selectedSlug)?.category ?? "")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let avatars = AvatarCatalog.all.filter { $0.category == category }

        if !avatars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(category)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    if category == "Exclusive" {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow.opacity(0.8))
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(avatars) { avatar in
                        avatarCell(avatar)
                    }
                }
            }
        }
    }

    // MARK: - Avatar Cell

    @ViewBuilder
    private func avatarCell(_ avatar: AvatarOption) -> some View {
        let isSelected = selectedSlug == avatar.slug
        let isUnlocked = AvatarCatalog.isUnlocked(avatar, milestones: milestones, isPremium: storeKitManager.isPremium)
        let isLocked = avatar.isLocked && !isUnlocked

        Button {
            guard !isLocked else { return }
            withAnimation(.spring(duration: 0.25)) {
                selectedSlug = avatar.slug
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Text(avatar.emoji)
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .background(
                            isSelected ? AppTheme.accent.opacity(0.25) :
                            isLocked ? Color.white.opacity(0.02) : Color.white.opacity(0.06),
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected ? AppTheme.accent.opacity(0.60) :
                                    isLocked ? Color.white.opacity(0.06) : Color.white.opacity(0.10),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .opacity(isLocked ? 0.35 : 1.0)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .background(Color.black.opacity(0.7), in: Circle())
                            .offset(x: 16, y: 16)
                    }
                }

                Text(avatar.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(isLocked ? 0.30 : isSelected ? 0.90 : 0.50))
                    .lineLimit(1)

                if isLocked, let req = avatar.unlockRequirement {
                    Text(AvatarCatalog.unlockDescription(for: req))
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.yellow.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 16)
            }

            Button {
                Task {
                    await onComplete(selectedSlug)
                }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(isSaving ? "Saving..." : "Continue")
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
            .disabled(isSaving)
            .opacity(isSaving ? 0.5 : 1.0)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
