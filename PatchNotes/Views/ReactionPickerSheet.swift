import SwiftUI

struct ReactionPickerSheet: View {
    let reactionTypes: [ReactionType]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void

    @State private var selectedCategory: ReactionCategory = .core
    @State private var searchText = ""

    private var filteredReactions: [ReactionType] {
        let base: [ReactionType]
        if searchText.isEmpty {
            base = reactionTypes.filter { ($0.category ?? "core") == selectedCategory.rawValue }
        } else {
            let query = searchText.lowercased()
            base = reactionTypes.filter {
                ($0.display_name ?? "").lowercased().contains(query) ||
                $0.slug.lowercased().contains(query) ||
                $0.emoji.contains(query)
            }
        }
        return base.sorted { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search Reactions...", text: $searchText)
                    .font(.caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Category pills
            if searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ReactionCategory.allCases) { cat in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = cat
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(cat.icon)
                                        .font(.caption2)
                                    Text(cat.displayName)
                                        .font(.caption2.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == cat
                                        ? AppTheme.accent.opacity(0.25)
                                        : Color.white.opacity(0.06),
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    selectedCategory == cat ? .white : .white.opacity(0.6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
            }

            // Emoji grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(filteredReactions) { type in
                        let isSelected = selectedReactionTypeIDs.contains(type.id)
                        Button {
                            onReact(type.id)
                        } label: {
                            VStack(spacing: 2) {
                                Text(type.emoji)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        isSelected
                                            ? AppTheme.accent.opacity(0.25)
                                            : Color.white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                isSelected ? AppTheme.accent.opacity(0.5) : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    }
                                Text(type.display_name ?? type.slug)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 280, idealWidth: 320, maxHeight: 380)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceTop)
        )
        .presentationCompactAdaptation(.popover)
    }
}
