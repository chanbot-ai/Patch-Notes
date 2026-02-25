import Foundation
import SwiftUI
import SafariServices
import WebKit

enum AppTheme {
    static let accent = Color(red: 1.00, green: 0.36, blue: 0.62)
    static let accentBlue = Color(red: 0.36, green: 0.74, blue: 1.00)
    static let bgTop = Color(red: 0.01, green: 0.02, blue: 0.08)
    static let bgBottom = Color(red: 0.00, green: 0.01, blue: 0.04)
    static let surfaceTop = Color(red: 0.10, green: 0.11, blue: 0.18)
    static let surfaceBottom = Color(red: 0.05, green: 0.06, blue: 0.12)
    static let cardA = Color(red: 0.18, green: 0.22, blue: 0.52)
    static let cardB = Color(red: 0.10, green: 0.13, blue: 0.30)
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }
    @Published var accountEmail: String {
        didSet { defaults.set(accountEmail, forKey: Keys.accountEmail) }
    }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }
    @Published var largerText: Bool {
        didSet { defaults.set(largerText, forKey: Keys.largerText) }
    }
    @Published var highContrastText: Bool {
        didSet { defaults.set(highContrastText, forKey: Keys.highContrastText) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayName = defaults.string(forKey: Keys.displayName) ?? "Chan"
        accountEmail = defaults.string(forKey: Keys.accountEmail) ?? "chan@patchnotes.gg"
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "dark") ?? .dark
        reduceMotion = defaults.object(forKey: Keys.reduceMotion) as? Bool ?? false
        largerText = defaults.object(forKey: Keys.largerText) as? Bool ?? false
        highContrastText = defaults.object(forKey: Keys.highContrastText) as? Bool ?? false
    }

    var preferredColorScheme: ColorScheme? {
        appearance.colorScheme
    }

    private enum Keys {
        static let displayName = "pn.settings.displayName"
        static let accountEmail = "pn.settings.accountEmail"
        static let appearance = "pn.settings.appearance"
        static let reduceMotion = "pn.settings.reduceMotion"
        static let largerText = "pn.settings.largerText"
        static let highContrastText = "pn.settings.highContrastText"
    }
}

enum RelativeTimestampFormatter {
    static func hoursAndMinutes(from date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current

        if date > now {
            let components = calendar.dateComponents([.hour, .minute], from: now, to: date)
            let hours = max(components.hour ?? 0, 0)
            let minutes = max(components.minute ?? 0, 0)

            if hours == 0 {
                return "in \(max(minutes, 1))m"
            }
            return "in \(hours)h \(minutes)m"
        }

        let components = calendar.dateComponents([.hour, .minute], from: date, to: now)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)

        if hours == 0 {
            return "\(max(minutes, 1))m ago"
        }
        return "\(hours)h \(minutes)m ago"
    }
}

enum MediaFallback {
    static let gameCover = URL(string: "https://dummyimage.com/600x900/101829/f5f7ff.png&text=Patch+Notes+Cover")!
    static let gameScreenshot = URL(string: "https://dummyimage.com/1280x720/0b1228/e9eeff.png&text=Patch+Notes+Screenshot")!
    static let videoThumbnail = URL(string: "https://dummyimage.com/1280x720/050a1a/e9eeff.png&text=Patch+Notes+Video")!
}

struct RemoteMediaImage: View {
    let primaryURL: URL?
    let alternatePrimaryURLs: [URL]
    let fallbackURL: URL

    @State private var candidateIndex = 0

    init(primaryURL: URL?, fallbackURL: URL, alternatePrimaryURLs: [URL] = []) {
        self.primaryURL = primaryURL
        self.alternatePrimaryURLs = alternatePrimaryURLs
        self.fallbackURL = fallbackURL
    }

    private var candidateURLs: [URL] {
        var ordered: [URL] = []
        if let primaryURL {
            ordered.append(primaryURL)
        }
        for url in alternatePrimaryURLs where !ordered.contains(url) {
            ordered.append(url)
        }
        return ordered
    }

    private var activeCandidateURL: URL? {
        guard candidateURLs.indices.contains(candidateIndex) else { return nil }
        return candidateURLs[candidateIndex]
    }

    var body: some View {
        Group {
            if let activeCandidateURL {
                AsyncImage(url: activeCandidateURL) { phase in
                    switch phase {
                    case .empty:
                        loadingView
                    case .success(let image):
                        resolvedImage(image)
                    case .failure:
                        if hasRemainingCandidate(after: activeCandidateURL) {
                            loadingView
                                .onAppear {
                                    advanceCandidate(after: activeCandidateURL)
                                }
                        } else {
                            fallbackImage
                        }
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .onChange(of: candidateURLs) { _, _ in
            candidateIndex = 0
        }
    }

    private var fallbackImage: some View {
        AsyncImage(url: fallbackURL) { phase in
            switch phase {
            case .empty:
                loadingView
            case .success(let image):
                resolvedImage(image)
            case .failure:
                LinearGradient(
                    colors: [AppTheme.surfaceTop.opacity(0.95), AppTheme.surfaceBottom.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            @unknown default:
                LinearGradient(
                    colors: [AppTheme.surfaceTop.opacity(0.95), AppTheme.surfaceBottom.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.white.opacity(0.04)
            ProgressView().tint(.white)
        }
    }

    private func resolvedImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
    }

    private func hasRemainingCandidate(after url: URL) -> Bool {
        guard let index = candidateURLs.firstIndex(of: url) else { return false }
        return index + 1 < candidateURLs.count
    }

    private func advanceCandidate(after failedURL: URL) {
        guard let activeCandidateURL, activeCandidateURL == failedURL else { return }
        guard candidateIndex + 1 < candidateURLs.count else { return }
        candidateIndex += 1
    }
}

struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = UIColor.black
        controller.preferredControlTintColor = UIColor.white
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

enum YouTubeIDParser {
    static func videoID(from url: URL?) -> String? {
        guard let url else { return nil }

        if let host = url.host?.lowercased(), host.contains("youtu.be") {
            return sanitize(url.pathComponents.dropFirst().first)
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let v = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return sanitize(v)
            }
        }

        let parts = url.pathComponents
        if let liveIndex = parts.firstIndex(of: "live"), liveIndex + 1 < parts.count {
            return sanitize(parts[liveIndex + 1])
        }
        if let embedIndex = parts.firstIndex(of: "embed"), embedIndex + 1 < parts.count {
            return sanitize(parts[embedIndex + 1])
        }
        return nil
    }

    private static func sanitize(_ rawID: String?) -> String? {
        guard let rawID, !rawID.isEmpty else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let cleaned = rawID.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        return cleaned.isEmpty ? nil : cleaned
    }
}

struct YouTubeInlinePlayer: UIViewRepresentable {
    let videoID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else { return }
        context.coordinator.loadedVideoID = videoID
        uiView.loadHTMLString(embedHTML(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
    }

    private func embedHTML(videoID: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              background: #000;
              overflow: hidden;
            }
            iframe {
              position: absolute;
              inset: 0;
              width: 100%;
              height: 100%;
              border: 0;
            }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1&controls=1&rel=0&modestbranding=1"
            allow="autoplay; encrypted-media; picture-in-picture; web-share"
            allowfullscreen>
          </iframe>
        </body>
        </html>
        """
    }

    final class Coordinator {
        var loadedVideoID: String?
    }
}

enum EmbeddedVideoSource: Equatable {
    case youtube(String)
    case web(URL)

    var cacheKey: String {
        switch self {
        case .youtube(let id):
            return "yt:\(id)"
        case .web(let url):
            return "web:\(url.absoluteString)"
        }
    }
}

enum EmbeddedVideoSourceResolver {
    static func resolve(from url: URL?) -> EmbeddedVideoSource? {
        guard let url else { return nil }
        if let videoID = YouTubeIDParser.videoID(from: url) {
            return .youtube(videoID)
        }
        return .web(url)
    }
}

struct EmbeddedVideoPlayer: UIViewRepresentable {
    let source: EmbeddedVideoSource

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.loadedKey != source.cacheKey else { return }
        context.coordinator.loadedKey = source.cacheKey

        switch source {
        case .youtube(let videoID):
            uiView.loadHTMLString(youtubeHTML(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
        case .web(let url):
            uiView.load(URLRequest(url: url))
        }
    }

    private func youtubeHTML(videoID: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              background: #000;
              overflow: hidden;
            }
            iframe {
              position: absolute;
              inset: 0;
              width: 100%;
              height: 100%;
              border: 0;
            }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=1&controls=1&rel=0&modestbranding=1"
            allow="autoplay; encrypted-media; picture-in-picture; web-share"
            allowfullscreen>
          </iframe>
        </body>
        </html>
        """
    }

    final class Coordinator {
        var loadedKey: String?
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [AppTheme.bgTop, AppTheme.bgBottom],
                center: .topLeading,
                startRadius: 10,
                endRadius: 900
            )

            Circle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 140, y: -300)

            Circle()
                .fill(AppTheme.accentBlue.opacity(0.14))
                .frame(width: 360, height: 360)
                .blur(radius: 74)
                .offset(x: -180, y: 340)
        }
        .ignoresSafeArea()
    }
}

struct DarkAuthBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)

            Circle()
                .fill(AppTheme.accent.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 150, y: -260)

            Circle()
                .fill(AppTheme.accentBlue.opacity(0.12))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: -180, y: 340)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                LinearGradient(
                    colors: [AppTheme.surfaceTop.opacity(0.96), AppTheme.surfaceBottom.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 7)
    }
}

struct DarkAuthContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack {
            content
        }
        .padding(16)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .padding(.horizontal, 2)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))
        }
    }
}

struct MetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.90))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.14), in: Capsule())
    }
}

struct HotBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("HOT")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.orange.opacity(0.30), lineWidth: 1)
        }
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12), in: Capsule())
    }
}

struct TeamLogoBadge: View {
    let team: String
    var size: CGFloat = 20

    private static let logoURLs: [String: URL] = [
        "Sentinels":     URL(string: "https://ui-avatars.com/api/?name=Sentinels&background=d4333f&color=fff&size=128&rounded=true&bold=true")!,
        "Paper Rex":     URL(string: "https://ui-avatars.com/api/?name=Paper+Rex&background=1aa4f2&color=fff&size=128&rounded=true&bold=true")!,
        "T1":            URL(string: "https://ui-avatars.com/api/?name=T1&background=f22626&color=fff&size=128&rounded=true&bold=true")!,
        "G2":            URL(string: "https://ui-avatars.com/api/?name=G2&background=f22626&color=fff&size=128&rounded=true&bold=true")!,
        "Gen.G":         URL(string: "https://ui-avatars.com/api/?name=Gen.G&background=3d8cf5&color=fff&size=128&rounded=true&bold=true")!,
        "Liquid":        URL(string: "https://ui-avatars.com/api/?name=Liquid&background=3d8cf5&color=fff&size=128&rounded=true&bold=true")!,
        "FaZe":          URL(string: "https://ui-avatars.com/api/?name=FaZe&background=fa9124&color=fff&size=128&rounded=true&bold=true")!,
        "Fnatic":        URL(string: "https://ui-avatars.com/api/?name=Fnatic&background=fa9124&color=fff&size=128&rounded=true&bold=true")!,
        "NRG":           URL(string: "https://ui-avatars.com/api/?name=NRG&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "100 Thieves":   URL(string: "https://ui-avatars.com/api/?name=100+Thieves&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Loud":          URL(string: "https://ui-avatars.com/api/?name=Loud&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Evil Geniuses": URL(string: "https://ui-avatars.com/api/?name=Evil+Geniuses&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Cloud9":        URL(string: "https://ui-avatars.com/api/?name=Cloud9&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "TSM":           URL(string: "https://ui-avatars.com/api/?name=TSM&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "DRX":           URL(string: "https://ui-avatars.com/api/?name=DRX&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "KT Rolster":    URL(string: "https://ui-avatars.com/api/?name=KT+Rolster&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Team Spirit":   URL(string: "https://ui-avatars.com/api/?name=Team+Spirit&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "MOUZ":          URL(string: "https://ui-avatars.com/api/?name=MOUZ&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Heroic":        URL(string: "https://ui-avatars.com/api/?name=Heroic&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Virtus.pro":    URL(string: "https://ui-avatars.com/api/?name=Virtus.pro&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Vitality":      URL(string: "https://ui-avatars.com/api/?name=Vitality&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Spirit":        URL(string: "https://ui-avatars.com/api/?name=Spirit&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "BetBoom":       URL(string: "https://ui-avatars.com/api/?name=BetBoom&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Falcons":       URL(string: "https://ui-avatars.com/api/?name=Falcons&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "Team Secret":   URL(string: "https://ui-avatars.com/api/?name=Team+Secret&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
        "OG":            URL(string: "https://ui-avatars.com/api/?name=OG&background=5c3bc9&color=fff&size=128&rounded=true&bold=true")!,
    ]

    private var logoURL: URL? { Self.logoURLs[team] }

    private var initials: String {
        let letters = team.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "T" : letters
    }

    private var colors: [Color] {
        switch team {
        case "Sentinels":
            return [Color(red: 0.84, green: 0.20, blue: 0.28), Color(red: 0.40, green: 0.07, blue: 0.09)]
        case "Paper Rex":
            return [Color(red: 0.10, green: 0.64, blue: 0.95), Color(red: 0.08, green: 0.30, blue: 0.68)]
        case "T1", "G2":
            return [Color(red: 0.95, green: 0.15, blue: 0.15), Color(red: 0.50, green: 0.04, blue: 0.04)]
        case "Gen.G", "Liquid":
            return [Color(red: 0.24, green: 0.55, blue: 0.96), Color(red: 0.10, green: 0.20, blue: 0.55)]
        case "FaZe", "Fnatic":
            return [Color(red: 0.98, green: 0.57, blue: 0.14), Color(red: 0.61, green: 0.30, blue: 0.04)]
        default:
            return [AppTheme.accentBlue, AppTheme.accent]
        }
    }

    private var gradientBadge: some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.40, weight: .black))
                    .foregroundStyle(.white)
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
    }

    var body: some View {
        if let url = logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.24), lineWidth: 1)
                        }
                case .empty, .failure:
                    gradientBadge
                @unknown default:
                    gradientBadge
                }
            }
        } else {
            gradientBadge
        }
    }
}
