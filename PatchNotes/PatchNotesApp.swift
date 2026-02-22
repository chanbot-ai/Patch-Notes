import SwiftUI

@main
struct PatchNotesApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}

private struct AppBootstrapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettings

    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity = 0.0
    @State private var glowOpacity = 0.0

    private var shouldReduceMotion: Bool {
        reduceMotion || settings.reduceMotion
    }

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                AppBackground()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.35))
                            .frame(width: 180, height: 180)
                            .blur(radius: 24)
                            .opacity(glowOpacity)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.08, green: 0.10, blue: 0.22), Color(red: 0.03, green: 0.05, blue: 0.14)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 132, height: 132)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            }

                        ZStack {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(AppTheme.accent)
                                .offset(x: 0, y: -18)

                            Text("PN")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .offset(y: 16)
                        }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    Text("PATCH NOTES")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white.opacity(logoOpacity))
                        .tracking(2.2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Patch Notes")
            }
        }
        .onAppear {
            animateSplash()
        }
    }

    private func animateSplash() {
        if shouldReduceMotion {
            logoOpacity = 1
            glowOpacity = 1
            logoScale = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.20)) {
                    showSplash = false
                }
            }
            return
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.80)) {
            logoScale = 1
            logoOpacity = 1
        }

        withAnimation(.easeInOut(duration: 0.90).repeatForever(autoreverses: true)) {
            glowOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.30)) {
                showSplash = false
            }
        }
    }
}
