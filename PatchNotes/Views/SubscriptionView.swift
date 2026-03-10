import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection

                        if storeKitManager.isPremium {
                            activeSubscriptionBanner
                        } else {
                            planCards
                        }

                        restoreButton

                        if let error = storeKitManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("PN Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.25))
                    .frame(width: 80, height: 80)
                    .blur(radius: 12)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Unlock PN Pro")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Remove ads, unlock exclusive avatars, and get deeper customization.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.70))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 12) {
            if let monthly = storeKitManager.monthlyProduct {
                planCard(product: monthly, badge: nil)
            }

            if let annual = storeKitManager.annualProduct {
                planCard(product: annual, badge: "Save 27%")
            }

            if storeKitManager.products.isEmpty {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 20)
            }
        }
    }

    private func planCard(product: Product, badge: String?) -> some View {
        Button {
            Task {
                try? await storeKitManager.purchase(product)
            }
        } label: {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(product.displayName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)

                            if let badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent, in: Capsule())
                            }
                        }

                        Text(product.displayPrice + " / " + (product.subscription?.subscriptionPeriod.displayUnit ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer()

                    if storeKitManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(storeKitManager.isLoading)
    }

    // MARK: - Active Subscription

    private var activeSubscriptionBanner: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PN Pro Active")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("You have full access to all premium features.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await storeKitManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .disabled(storeKitManager.isLoading)
    }
}

// MARK: - Subscription Period Display

private extension Product.SubscriptionPeriod {
    var displayUnit: String {
        switch unit {
        case .month: return value == 1 ? "month" : "\(value) months"
        case .year: return value == 1 ? "year" : "\(value) years"
        case .week: return value == 1 ? "week" : "\(value) weeks"
        case .day: return value == 1 ? "day" : "\(value) days"
        @unknown default: return ""
        }
    }
}
