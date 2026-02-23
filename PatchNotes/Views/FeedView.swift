import SwiftUI
import Foundation
import Supabase

struct FeedView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore

    @State private var showingComposer = false

    var body: some View {
        List {
            if store.feedIsLoading && store.posts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading feed...")
                    Spacer()
                }
            }

            if let errorMessage = store.feedErrorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feed Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .foregroundStyle(.red)
            }

            if !store.feedIsLoading && store.posts.isEmpty && store.feedErrorMessage == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No posts yet")
                        .font(.headline)
                    Text("Create the first post from the compose button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(store.posts) { post in
                FeedPostRow(
                    post: post,
                    reactionCountOverride: store.reactionTotal(for: post),
                    reactionTypes: store.reactionTypes,
                    reactionCounts: store.reactionCountsByPost[post.id] ?? [],
                    selectedReactionTypeIDs: store.viewerReactionTypeIDsByPost[post.id] ?? [],
                    onReact: { reactionTypeID in
                        store.react(to: post.id, with: reactionTypeID)
                    }
                )
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingComposer = true
                } label: {
                    Label("Post", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("Create post")
            }
        }
        .sheet(isPresented: $showingComposer) {
            NavigationStack {
                PostComposerView {
                    store.loadHotFeed()
                }
                .environmentObject(authManager)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .refreshable {
            await store.refreshHotFeed()
        }
        .overlay(alignment: .top) {
            if let reactionErrorMessage = store.reactionErrorMessage {
                ReactionErrorToast(message: reactionErrorMessage)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.reactionErrorMessage)
    }
}

private struct FeedPostRow: View {
    let post: Post
    let reactionCountOverride: Int
    let reactionTypes: [ReactionType]
    let reactionCounts: [PostReactionCount]
    let selectedReactionTypeIDs: Set<UUID>
    let onReact: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = post.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(post.type.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !reactionTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reactionTypes) { type in
                            let count = reactionCounts.first(where: { $0.reactionTypeID == type.id })?.count ?? 0
                            let isSelected = selectedReactionTypeIDs.contains(type.id)

                            Button {
                                onReact(type.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(type.emoji)
                                    Text("\(count)")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.78))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    (isSelected ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.06)),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected ? AppTheme.accent.opacity(0.45) : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 12) {
                Label("\(reactionCountOverride)", systemImage: "face.smiling")
                Label("\(post.comment_count ?? 0)", systemImage: "bubble.right")
                if let hotScore = post.hot_score {
                    Label(String(format: "%.1f", hotScore), systemImage: "flame.fill")
                }
                Spacer()
                Text(post.created_at, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ReactionErrorToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }
}

private struct PostComposerView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let onPostCreated: @MainActor () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = PostComposerService()

    var body: some View {
        Form {
            Section("Create Post") {
                TextField("Title (optional)", text: $title)

                TextField("What's happening?", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)
            }

            Section {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.white)
                        }
                        Text(isSaving ? "Posting..." : "Post")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving || !canSubmit)
            }
        }
        .navigationTitle("New Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
        }
    }

    private var canSubmit: Bool {
        !trimmedTitle.isEmpty || !trimmedBody.isEmpty
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard let session = authManager.session else {
            errorMessage = "You need to sign in before posting."
            return
        }

        guard canSubmit else { return }

        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }

            do {
                try await service.createTextPost(
                    session: session,
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    body: trimmedBody.isEmpty ? nil : trimmedBody
                )
                onPostCreated()
                dismiss()
            } catch {
                errorMessage = service.friendlyMessage(for: error)
            }
        }
    }
}

private struct PostComposerService {
    private struct NewPostInsert: Encodable {
        let author_id: UUID
        let type: String
        let title: String?
        let body: String?
        let is_system_generated: Bool
    }

    func createTextPost(
        session: Session,
        title: String?,
        body: String?
    ) async throws {
        let accessToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            throw NSError(
                domain: "PatchNotes.PostComposer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Your session is missing an access token. Please sign out and sign in again."]
            )
        }

        let client = SupabaseManager.shared.authenticatedClient(accessToken: accessToken)

        try await client
            .from("posts")
            .insert(
                NewPostInsert(
                    author_id: session.user.id,
                    type: "text",
                    title: title,
                    body: body,
                    is_system_generated: false
                )
            )
            .execute()
    }

    func friendlyMessage(for error: Error) -> String {
        let message = [error.localizedDescription, String(describing: error)]
            .joined(separator: " | ")
            .lowercased()

        if message.contains("42501") || message.contains("row-level security") {
            return "Your account does not have permission to create posts yet."
        }

        if message.contains("users can insert posts") || message.contains("author_id") {
            return "Post creation failed because the author ID was rejected."
        }

        return error.localizedDescription
    }
}
