import SwiftUI

struct BadgeManagementView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var authManager: AuthManager

    @State private var selectedSlugs: [String] = []
    @State private var isSaving = false

    private var milestones: UserMilestones {
        store.currentUserMilestones ?? UserMilestones(comments_posted: 0, replies_posted: 0, reactions_given: 0)
    }

    private var earnedBadges: [MilestoneBadgeDef] {
        MilestoneBadgeCatalog.earnedBadges(for: milestones)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Selected badges preview
                selectedBadgesPreview
                    .padding(.horizontal, 16)

                // Progress summary
                progressSection
                    .padding(.horizontal, 16)

                // Badge catalog by category
                ForEach(MilestoneBadgeCatalog.categories, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.loadMyMilestones()
            loadCurrentSelection()
        }
    }

    // MARK: - Selected Badges Preview

    private var selectedBadgesPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Display Badges")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Select up to 3 badges to show next to your name.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    if index < selectedSlugs.count {
                        let slug = selectedSlugs[index]
                        let badge = MilestoneBadgeCatalog.badge(for: slug)
                        Button {
                            selectedSlugs.remove(at: index)
                            saveSelection()
                        } label: {
                            VStack(spacing: 4) {
                                Text(badge?.emoji ?? "🏅")
                                    .font(.title)
                                    .frame(width: 50, height: 50)
                                    .background(AppTheme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(AppTheme.accent.opacity(0.5), lineWidth: 2)
                                    }
                                Text(badge?.label ?? slug)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Text("+")
                                        .font(.title2)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            Text("Empty")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(width: 60)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Stats")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                statPill(label: "Comments", value: milestones.comments_posted, emoji: "💬")
                statPill(label: "Replies", value: milestones.replies_posted, emoji: "↩️")
                statPill(label: "Reactions", value: milestones.reactions_given, emoji: "❤️")
            }
        }
    }

    private func statPill(label: String, value: Int, emoji: String) -> some View {
        VStack(spacing: 3) {
            Text(emoji)
                .font(.title3)
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let badges = MilestoneBadgeCatalog.all.filter { $0.category == category }
        VStack(alignment: .leading, spacing: 10) {
            Text(category)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach(badges) { badge in
                    badgeTile(badge)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func badgeTile(_ badge: MilestoneBadgeDef) -> some View {
        let earned = badge.isEarned(by: milestones)
        let isSelected = selectedSlugs.contains(badge.slug)

        Button {
            guard earned else { return }
            if isSelected {
                selectedSlugs.removeAll { $0 == badge.slug }
            } else if selectedSlugs.count < 3 {
                selectedSlugs.append(badge.slug)
            }
            saveSelection()
        } label: {
            VStack(spacing: 4) {
                Text(badge.emoji)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(
                        isSelected ? AppTheme.accent.opacity(0.2) :
                        earned ? Color.white.opacity(0.06) : Color.white.opacity(0.02),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? AppTheme.accent.opacity(0.5) :
                                earned ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .opacity(earned ? 1.0 : 0.35)

                Text(badge.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(earned ? 0.7 : 0.3))
                    .lineLimit(1)

                Text(badge.description)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.white.opacity(earned ? 0.4 : 0.2))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!earned)
    }

    // MARK: - Helpers

    private func loadCurrentSelection() {
        guard let userID = authManager.session?.user.id else { return }
        let current = store.displayBadges(for: userID)
        selectedSlugs = current.sorted { $0.ordinal < $1.ordinal }.map(\.slug)
    }

    private func saveSelection() {
        store.updateDisplayBadges(slugs: selectedSlugs)
    }
}
