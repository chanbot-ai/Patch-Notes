import SwiftUI
import Supabase

private enum ComposerMediaKind: String {
    case image
    case video
    case link
}

private struct ComposerMediaAttachment {
    let url: URL
    let thumbnailURL: URL?
    let kind: ComposerMediaKind
}

struct PostComposerView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onPostCreated: @MainActor () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedGameID: UUID?
    @State private var mediaURLText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = PostComposerService()

    var body: some View {
        Form {
            Section("Create Post") {
                TextField("Title (optional)", text: $title)

                TextField("What's happening?", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)

                Picker("Attach Game (optional)", selection: $selectedGameID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(availableGames) { game in
                        Text(store.isFollowingGame(game) ? "Following · \(game.title)" : game.title)
                            .tag(Optional(game.id))
                    }
                }
            }

            Section("Media (optional)") {
                TextField("Image, video, or X/Twitter URL", text: $mediaURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                if let mediaAttachment {
                    ComposerMediaPreview(attachment: mediaAttachment, height: 180)

                    Button("Remove Media") {
                        mediaURLText = ""
                    }
                    .foregroundStyle(.white.opacity(0.8))
                } else if let mediaValidationMessage {
                    Text(mediaValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
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
        !trimmedTitle.isEmpty || !trimmedBody.isEmpty || mediaAttachment != nil
    }

    private var availableGames: [Game] {
        store.socialGames.sorted { lhs, rhs in
            let lhsFollowing = store.isFollowingGame(lhs)
            let rhsFollowing = store.isFollowingGame(rhs)
            if lhsFollowing != rhsFollowing {
                return lhsFollowing && !rhsFollowing
            }
            if lhs.releaseDate == rhs.releaseDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.releaseDate < rhs.releaseDate
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedMediaURL: String {
        mediaURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mediaAttachment: ComposerMediaAttachment? {
        guard let url = normalizeMediaURL(trimmedMediaURL) else { return nil }
        guard let kind = inferMediaKind(url: url) else { return nil }
        let thumbnailURL = inferThumbnailURL(for: url, kind: kind)
        return ComposerMediaAttachment(url: url, thumbnailURL: thumbnailURL, kind: kind)
    }

    private var mediaValidationMessage: String? {
        guard !trimmedMediaURL.isEmpty else { return nil }
        return mediaAttachment == nil ? "Enter a valid image, video, or X/Twitter post URL." : nil
    }

    private func save() {
        guard let session = authManager.session else {
            errorMessage = "You need to sign in before posting."
            return
        }

        guard canSubmit else { return }
        if !trimmedMediaURL.isEmpty, mediaAttachment == nil {
            errorMessage = "Please enter a valid image, video, or X/Twitter post URL."
            return
        }

        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }

            do {
                try await service.createPost(
                    session: session,
                    linkedGame: availableGames.first(where: { $0.id == selectedGameID }),
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    body: trimmedBody.isEmpty ? nil : trimmedBody,
                    mediaAttachment: mediaAttachment
                )
                onPostCreated()
                dismiss()
            } catch {
                errorMessage = service.friendlyMessage(for: error)
            }
        }
    }

    private func normalizeMediaURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }

    private func inferMediaKind(url: URL) -> ComposerMediaKind? {
        if url.isTwitterStatusURL {
            return .link
        }
        if YouTubeIDParser.videoID(from: url) != nil {
            return .video
        }
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "webm"].contains(ext) {
            return .video
        }
        if ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"].contains(ext) {
            return .image
        }
        return nil
    }

    private func inferThumbnailURL(for url: URL, kind: ComposerMediaKind) -> URL? {
        if kind == .video, let id = YouTubeIDParser.videoID(from: url) {
            return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
        }
        if kind == .image {
            return url
        }
        return nil
    }
}

private struct ComposerMediaPreview: View {
    let attachment: ComposerMediaAttachment
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(height: height)

            switch attachment.kind {
            case .image:
                RemoteMediaImage(primaryURL: attachment.url, fallbackURL: MediaFallback.gameScreenshot)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .video:
                let previewURL = attachment.thumbnailURL ?? attachment.url
                RemoteMediaImage(primaryURL: previewURL, fallbackURL: MediaFallback.videoThumbnail)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: height * 0.3, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                    }
            case .link:
                ExternalLinkPreviewCard(url: attachment.url)
                    .frame(height: height)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct PostComposerService {
    private struct NewPostInsert: Encodable {
        let author_id: UUID
        let game_id: UUID?
        let type: String
        let title: String?
        let body: String?
        let media_url: String?
        let thumbnail_url: String?
        let is_system_generated: Bool
    }

    private let feedService = FeedService()

    func createPost(
        session: Session,
        linkedGame: Game?,
        title: String?,
        body: String?,
        mediaAttachment: ComposerMediaAttachment?
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
        if let linkedGame {
            try await feedService.ensureGameExists(linkedGame, accessToken: accessToken)
        }

        let resolvedMediaURL = mediaAttachment?.url.absoluteString
        let resolvedThumbnailURL = mediaAttachment?.thumbnailURL?.absoluteString
        let resolvedType = mediaAttachment?.kind.rawValue ?? "text"

        try await client
            .from("posts")
            .insert(
                NewPostInsert(
                    author_id: session.user.id,
                    game_id: linkedGame?.id,
                    type: resolvedType,
                    title: title,
                    body: body,
                    media_url: resolvedMediaURL,
                    thumbnail_url: resolvedThumbnailURL,
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
