import Foundation
import Combine
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = FeedService()

    init() {
        service.onPostMetricsChange = { [weak self] updatedPostId in
            self?.handleRealtimeUpdate(updatedPostId: updatedPostId)
        }
        service.subscribeToPostMetrics()
    }

    func loadFeed() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                posts = try await service.fetchHotFeed()
            } catch {
                errorMessage = error.localizedDescription
                print("Error loading feed:", error)
            }
        }
    }

    func handleRealtimeUpdate(updatedPostId: UUID?) {
        Task {
            do {
                let refreshedPosts = try await service.fetchHotFeed()
                withAnimation(.easeInOut(duration: 0.2)) {
                    posts = refreshedPosts
                }
                if let updatedPostId {
                    print("Refreshed hot feed after realtime update for post:", updatedPostId)
                } else {
                    print("Refreshed hot feed after realtime update")
                }
            } catch {
                print("Error refreshing feed after realtime update:", error)
            }
        }
    }
}
