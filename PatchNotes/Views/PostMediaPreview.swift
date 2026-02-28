import SwiftUI
import ImageIO

extension URL {
    var isGIFAsset: Bool {
        pathExtension.lowercased() == "gif"
    }

    var isTwitterStatusURL: Bool {
        guard let host = host?.lowercased() else { return false }
        let supportedHost = host == "x.com"
            || host.hasSuffix(".x.com")
            || host == "twitter.com"
            || host.hasSuffix(".twitter.com")
        guard supportedHost else { return false }
        return pathComponents.contains("status")
    }
}

enum RemoteImageAspectRatioProbe {
    private static let cache = NSCache<NSURL, NSNumber>()

    static func aspectRatio(for url: URL) async -> CGFloat? {
        if let cached = cache.object(forKey: url as NSURL) {
            return CGFloat(truncating: cached)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...399).contains(httpResponse.statusCode) {
                return nil
            }

            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let pixelWidth = numericValue(properties[kCGImagePropertyPixelWidth]),
                  let pixelHeight = numericValue(properties[kCGImagePropertyPixelHeight]),
                  pixelWidth > 0,
                  pixelHeight > 0 else {
                return nil
            }

            let ratio = pixelWidth / pixelHeight
            cache.setObject(NSNumber(value: Double(ratio)), forKey: url as NSURL)
            return ratio
        } catch {
            return nil
        }
    }

    private static func numericValue(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(number.doubleValue)
        case let intValue as Int:
            return CGFloat(intValue)
        case let doubleValue as Double:
            return CGFloat(doubleValue)
        default:
            return nil
        }
    }
}

struct PostMediaPreview: View {
    let post: Post
    var height: CGFloat = 190
    var onVideoTap: (() -> Void)? = nil
    @State private var showingVideoPlayback = false
    @State private var measuredContainerWidth: CGFloat = 0
    @State private var measuredImageAspectRatio: CGFloat?

    private var aspectProbeURL: URL? {
        guard post.contentType == .image,
              let mediaURL = post.mediaURL,
              !mediaURL.isGIFAsset else {
            return nil
        }
        return mediaURL
    }

    private var previewHeight: CGFloat {
        guard post.contentType == .image,
              let mediaURL = post.mediaURL,
              !mediaURL.isGIFAsset else {
            return height
        }

        let fallbackHeight = min(max(height * 1.45, height), 340)

        guard let measuredImageAspectRatio,
              measuredImageAspectRatio > 0,
              measuredContainerWidth > 1 else {
            return fallbackHeight
        }

        let idealHeight = measuredContainerWidth / measuredImageAspectRatio
        let minHeight = max(height * 1.1, height)
        let maxHeight = min(max(height * 2.2, height), 420)
        return min(max(idealHeight, minHeight), maxHeight)
    }

    var body: some View {
        Group {
            if let mediaURL = post.mediaURL, post.contentType != .text {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeight)

                    switch post.contentType {
                    case .text:
                        EmptyView()
                    case .image:
                        if mediaURL.isGIFAsset {
                            EmbeddedVideoPlayer(source: .web(mediaURL))
                                .frame(maxWidth: .infinity)
                                .frame(height: previewHeight)
                                .allowsHitTesting(false)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            RemoteMediaImage(
                                primaryURL: mediaURL,
                                fallbackURL: MediaFallback.gameScreenshot,
                                contentMode: .fit
                            )
                                .frame(maxWidth: .infinity)
                                .frame(height: previewHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    case .link:
                        ExternalLinkPreviewCard(url: mediaURL)
                            .frame(maxWidth: .infinity)
                            .frame(height: previewHeight)
                    case .video:
                        let previewURL = post.thumbnailURL ?? mediaURL
                        RemoteMediaImage(primaryURL: previewURL, fallbackURL: MediaFallback.videoThumbnail)
                            .frame(maxWidth: .infinity)
                            .frame(height: previewHeight)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: previewHeight * 0.3, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                if let onVideoTap {
                                    onVideoTap()
                                } else {
                                    showingVideoPlayback = true
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                updateMeasuredContainerWidth(proxy.size.width)
                            }
                            .onChange(of: proxy.size.width) { _, newWidth in
                                updateMeasuredContainerWidth(newWidth)
                            }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
            }
        }
        .task(id: aspectProbeURL) {
            guard let aspectProbeURL else {
                measuredImageAspectRatio = nil
                return
            }
            measuredImageAspectRatio = await RemoteImageAspectRatioProbe.aspectRatio(for: aspectProbeURL)
        }
        .sheet(isPresented: $showingVideoPlayback) {
            if let mediaURL = post.mediaURL {
                InAppSafariView(url: mediaURL)
                    .ignoresSafeArea()
            }
        }
    }

    private func updateMeasuredContainerWidth(_ newWidth: CGFloat) {
        guard newWidth.isFinite, newWidth > 0 else { return }
        if abs(measuredContainerWidth - newWidth) > 0.5 {
            measuredContainerWidth = newWidth
        }
    }
}

struct ExternalLinkPreviewCard: View {
    let url: URL

    private var hostLabel: String {
        (url.host ?? url.absoluteString)
            .replacingOccurrences(of: "www.", with: "")
    }

    private var titleLabel: String {
        url.isTwitterStatusURL ? "X / Twitter Post" : "External Link"
    }

    var body: some View {
        Link(destination: url) {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: url.isTwitterStatusURL ? "bubble.left.and.bubble.right.fill" : "link")
                            .foregroundStyle(AppTheme.accent)
                        Text(titleLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }

                    Text(hostLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    Text(url.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                        Text("Open Link")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14), in: Capsule())
                }
                .padding(14)

                if url.isTwitterStatusURL {
                    Text("X")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
