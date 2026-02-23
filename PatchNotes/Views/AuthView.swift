import SwiftUI

struct AuthView: View {

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isSubmitting = false
    @State private var isResendingConfirmation = false
    @State private var lastSignupEmail: String?

    var body: some View {
        ZStack {
            DarkAuthBackground()

            ScrollView {
                VStack(spacing: 22) {
                    authHeader

                    DarkAuthContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(
                                title: isSignUp ? "Create Account" : "Sign In",
                                subtitle: isSignUp
                                    ? "Use email and password to create your Patch Notes account."
                                    : "Sign in to sync your feed, profile, and social activity."
                            )

                            VStack(spacing: 12) {
                                authTextField(
                                    title: "Email",
                                    icon: "envelope.fill",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress
                                )

                                authSecureField(
                                    title: "Password",
                                    icon: "lock.fill",
                                    text: $password
                                )
                            }

                            if let infoMessage {
                                inlineMessage(
                                    icon: "checkmark.circle.fill",
                                    text: infoMessage,
                                    color: AppTheme.accentBlue
                                )
                            }

                            if let errorMessage {
                                inlineMessage(
                                    icon: "exclamationmark.triangle.fill",
                                    text: errorMessage,
                                    color: .red
                                )
                            }

                            Button(action: handleAuth) {
                                HStack(spacing: 10) {
                                    if isSubmitting {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text(isSubmitting
                                         ? (isSignUp ? "Creating..." : "Signing In...")
                                         : (isSignUp ? "Create Account" : "Sign In"))
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
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.6)

                            if shouldShowResendConfirmation {
                                Button(action: resendConfirmationEmail) {
                                    HStack(spacing: 8) {
                                        if isResendingConfirmation {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(0.9)
                                        }
                                        Image(systemName: "paperplane.fill")
                                            .font(.caption.weight(.bold))
                                        Text(isResendingConfirmation ? "Resending..." : "Resend Confirmation Email")
                                            .font(.footnote.weight(.semibold))
                                    }
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!canResendConfirmation)
                                .opacity(canResendConfirmation ? 1 : 0.55)
                            }

                            Button {
                                isSignUp.toggle()
                                errorMessage = nil
                                infoMessage = nil
                            } label: {
                                Text(isSignUp ? "Already have an account? Sign In"
                                              : "Don't have an account? Sign Up")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }

                    Text("Email confirmation may be required before first sign in.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 36)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    private func handleAuth() {
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                errorMessage = nil
                infoMessage = nil

                let normalizedEmail = normalized(email)

                if isSignUp {
                    try await authManager.signUp(email: normalizedEmail, password: password)
                    lastSignupEmail = normalizedEmail

                    if authManager.session == nil {
                        infoMessage = "Account created. Check your email for the confirmation link, then sign in."
                    }
                } else {
                    try await authManager.signIn(email: normalizedEmail, password: password)
                }
            } catch {
                errorMessage = userFacingAuthError(
                    error,
                    context: isSignUp ? .signUp : .signIn
                )
            }
        }
    }

    private var authHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.28))
                    .frame(width: 108, height: 108)
                    .blur(radius: reduceMotion ? 0 : 18)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.surfaceTop.opacity(0.98), AppTheme.surfaceBottom.opacity(0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }

                VStack(spacing: -2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppTheme.accent)
                    Text("PN")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Text("PATCH NOTES")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .tracking(2.0)
        }
        .padding(.top, 10)
    }

    private func authTextField(
        title: String,
        icon: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .frame(width: 18)

            TextField(
                "",
                text: text,
                prompt: Text(title).foregroundStyle(.white.opacity(0.34))
            )
            .foregroundStyle(.white)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func authSecureField(
        title: String,
        icon: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .frame(width: 18)

            SecureField(
                "",
                text: text,
                prompt: Text(title).foregroundStyle(.white.opacity(0.34))
            )
            .foregroundStyle(.white)
            .textContentType(.password)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func inlineMessage(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        }
    }

    private var canSubmit: Bool {
        !normalized(email).isEmpty && !password.isEmpty && !isSubmitting
    }

    private var shouldShowResendConfirmation: Bool {
        isSignUp || lastSignupEmail != nil
    }

    private var resendEmail: String {
        let candidate = normalized(lastSignupEmail ?? email)
        return candidate
    }

    private var canResendConfirmation: Bool {
        !resendEmail.isEmpty && !isResendingConfirmation
    }

    private func resendConfirmationEmail() {
        Task {
            isResendingConfirmation = true
            defer { isResendingConfirmation = false }

            do {
                errorMessage = nil
                try await authManager.resendSignUpConfirmation(email: resendEmail)
                infoMessage = "Confirmation email sent. Check your inbox and spam folder."
                lastSignupEmail = resendEmail
            } catch {
                infoMessage = nil
                errorMessage = userFacingAuthError(error, context: .resendConfirmation)
            }
        }
    }

    private enum AuthErrorContext {
        case signIn
        case signUp
        case resendConfirmation
    }

    private func userFacingAuthError(_ error: Error, context: AuthErrorContext) -> String {
        let rawMessage = "\(error) \(error.localizedDescription)".lowercased()

        if rawMessage.contains("email rate limit exceeded")
            || rawMessage.contains("over_email_send_rate_limit")
            || (rawMessage.contains("429") && rawMessage.contains("email")) {
            switch context {
            case .resendConfirmation:
                return "Too many confirmation email requests right now. Please wait a bit before trying again."
            case .signUp:
                return "Email sending is temporarily rate limited. Your account may exist already, but confirmation email delivery is throttled. Please wait and try again."
            case .signIn:
                return "Auth email requests are temporarily rate limited. Please wait and try again."
            }
        }

        if context == .signIn && rawMessage.contains("email not confirmed") {
            return "Your email is not confirmed yet. Open the confirmation email, then sign in again."
        }

        return error.localizedDescription
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
