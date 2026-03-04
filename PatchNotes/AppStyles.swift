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

private final class RemoteImageCache: @unchecked Sendable {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    init() { cache.countLimit = 120 }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func set(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

struct RemoteMediaImage: View {
    let primaryURL: URL?
    let alternatePrimaryURLs: [URL]
    let fallbackURL: URL
    let contentMode: ContentMode

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    init(
        primaryURL: URL?,
        fallbackURL: URL,
        alternatePrimaryURLs: [URL] = [],
        contentMode: ContentMode = .fill
    ) {
        self.primaryURL = primaryURL
        self.alternatePrimaryURLs = alternatePrimaryURLs
        self.fallbackURL = fallbackURL
        self.contentMode = contentMode
    }

    private var allCandidateURLs: [URL] {
        var urls: [URL] = []
        if let primaryURL { urls.append(primaryURL) }
        for url in alternatePrimaryURLs where !urls.contains(url) {
            urls.append(url)
        }
        urls.append(fallbackURL)
        return urls
    }

    var body: some View {
        Group {
            if let loadedImage {
                resolvedImage(Image(uiImage: loadedImage))
            } else if loadFailed {
                LinearGradient(
                    colors: [AppTheme.surfaceTop.opacity(0.95), AppTheme.surfaceBottom.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                loadingView
            }
        }
        .task(id: primaryURL) {
            await loadFromCandidates()
        }
    }

    private func loadFromCandidates() async {
        loadedImage = nil
        loadFailed = false

        for url in allCandidateURLs {
            if let cached = RemoteImageCache.shared.image(for: url) {
                loadedImage = cached
                return
            }
            do {
                var request = URLRequest(url: url)
                request.setValue("PatchNotes/1.0 (iOS; like Safari)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if Task.isCancelled { return }
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let image = UIImage(data: data) else { continue }
                RemoteImageCache.shared.set(image, for: url)
                loadedImage = image
                return
            } catch {
                if Task.isCancelled { return }
                continue
            }
        }
        loadFailed = true
    }

    private var loadingView: some View {
        ZStack {
            Color.white.opacity(0.04)
            ProgressView().tint(.white)
        }
    }

    @ViewBuilder
    private func resolvedImage(_ image: Image) -> some View {
        switch contentMode {
        case .fill:
            image
                .resizable()
                .scaledToFill()
        case .fit:
            image
                .resizable()
                .scaledToFit()
        @unknown default:
            image
                .resizable()
                .scaledToFit()
        }
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
        return """
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
    var mutedAutoplay: Bool = false

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
        let cacheKey = "\(source.cacheKey)|mutedAutoplay:\(mutedAutoplay)"
        guard context.coordinator.loadedKey != cacheKey else { return }
        context.coordinator.loadedKey = cacheKey

        switch source {
        case .youtube(let videoID):
            uiView.loadHTMLString(
                youtubeHTML(videoID: videoID, mutedAutoplay: mutedAutoplay),
                baseURL: URL(string: "https://www.youtube.com")
            )
        case .web(let url):
            uiView.load(URLRequest(url: url))
        }
    }

    private func youtubeHTML(videoID: String, mutedAutoplay: Bool) -> String {
        let query: String
        if mutedAutoplay {
            query = "playsinline=1&autoplay=1&mute=1&controls=0&rel=0&modestbranding=1&loop=1&playlist=\(videoID)"
        } else {
            query = "playsinline=1&autoplay=1&controls=1&rel=0&modestbranding=1"
        }
        return """
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
            src="https://www.youtube.com/embed/\(videoID)?\(query)"
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
        "Sentinels":     URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/Sentinels_logo.svg/200px-Sentinels_logo.svg.png")!,
        "Paper Rex":     URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Paper_Rex_logo.svg/200px-Paper_Rex_logo.svg.png")!,
        "T1":            URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/T1_esports_logo.svg/200px-T1_esports_logo.svg.png")!,
        "G2":            URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/1/12/Esports_organization_G2_Esports_logo.svg/200px-Esports_organization_G2_Esports_logo.svg.png")!,
        "Gen.G":         URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Gen.G_Logo.svg/200px-Gen.G_Logo.svg.png")!,
        "Liquid":        URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/f/f1/Team_Liquid_logo.svg/200px-Team_Liquid_logo.svg.png")!,
        "FaZe":          URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Faze_Clan.svg/200px-Faze_Clan.svg.png")!,
        "Fnatic":        URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/4/43/Esports_organization_Fnatic_logo.svg/200px-Esports_organization_Fnatic_logo.svg.png")!,
        "NRG":           URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/NRG_Esports_logo.svg/200px-NRG_Esports_logo.svg.png")!,
        "100 Thieves":   URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/16/100_Thieves_logo.svg/200px-100_Thieves_logo.svg.png")!,
        "Loud":          URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/LOUD_logo.svg/200px-LOUD_logo.svg.png")!,
        "Evil Geniuses": URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Evil_Geniuses_Logo.svg/200px-Evil_Geniuses_Logo.svg.png")!,
        "Cloud9":        URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Cloud9_logo_c._2023.svg/200px-Cloud9_logo_c._2023.svg.png")!,
        "TSM":           URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/TSM_Logo.svg/200px-TSM_Logo.svg.png")!,
        "DRX":           URL(string: "https://upload.wikimedia.org/wikipedia/commons/3/34/DRX_logo_2023.png")!,
        "KT Rolster":    URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/KT_Logo.svg/200px-KT_Logo.svg.png")!,
        "Team Spirit":   URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Team_Spirit_new_em.svg/200px-Team_Spirit_new_em.svg.png")!,
        "Spirit":        URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Team_Spirit_new_em.svg/200px-Team_Spirit_new_em.svg.png")!,
        "MOUZ":          URL(string: "https://upload.wikimedia.org/wikipedia/commons/3/39/MOUZlogo2021.png")!,
        "Heroic":        URL(string: "https://upload.wikimedia.org/wikipedia/commons/8/8f/Heroic_2023_logo.png")!,
        "Virtus.pro":    URL(string: "https://upload.wikimedia.org/wikipedia/en/3/3b/Virtus_pro_logo_new.png")!,
        "Vitality":      URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/4/49/Team_Vitality_logo.svg/200px-Team_Vitality_logo.svg.png")!,
        "BetBoom":       URL(string: "https://upload.wikimedia.org/wikipedia/commons/2/24/BetBoom_Team.png")!,
        "Falcons":       URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/4/4d/Team_Falcons_Logo.svg/200px-Team_Falcons_Logo.svg.png")!,
        "Team Secret":   URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/2/2a/Team_Secret_logo.svg/200px-Team_Secret_logo.svg.png")!,
        "OG":            URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/5/5c/OG_Esports_logo.svg/200px-OG_Esports_logo.svg.png")!,
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
                        .scaledToFit()
                        .padding(size * 0.10)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.24), lineWidth: 1)
                        }
                case .empty, .failure:
                    gradientBadge
                @unknown default:
                    gradientBadge
                }
            }
            .frame(width: size, height: size)
        } else {
            gradientBadge
        }
    }
}

struct LivePulseDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.35))
                .frame(width: 12, height: 12)
                .scaleEffect(pulsing ? 1.8 : 1)
                .opacity(pulsing ? 0 : 0.8)
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.80 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
