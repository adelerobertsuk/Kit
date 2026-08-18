import StoreKit
import SwiftUI

struct PaywallView: View {
    @Bindable var subscriptions: SubscriptionManager

    let privacyPolicyURL: URL
    let termsOfUseURL: URL
    var onSubscribed: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedProductID = SubscriptionManager.ProductID.annual
    @State private var showingError = false

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    features

                    if subscriptions.isLoading && subscriptions.products.isEmpty {
                        ProgressView("Loading plans…")
                            .frame(maxWidth: .infinity, minHeight: 150)
                    } else if subscriptions.products.isEmpty {
                        unavailableView
                    } else {
                        plans
                        subscribeButton
                    }

                    footer
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if subscriptions.products.isEmpty {
                    await subscriptions.refresh()
                }
                selectDefaultProduct()
            }
            .onChange(of: subscriptions.products.map(\.id)) {
                selectDefaultProduct()
            }
            .onChange(of: subscriptions.hasPremiumAccess) {
                guard subscriptions.hasPremiumAccess else { return }
                onSubscribed?()
                dismiss()
            }
            .onChange(of: subscriptions.errorMessage) {
                showingError = subscriptions.errorMessage != nil
            }
            .alert("Unable to complete purchase", isPresented: $showingError) {
                Button("OK") { subscriptions.clearError() }
            } message: {
                Text(subscriptions.errorMessage ?? "Please try again.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            Text("Run without limits")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Capture every thought and bring your run photos together with Running Memory Premium.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(spacing: 16) {
            ForEach(SubscriptionManager.PremiumFeature.allCases) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.systemImage)
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 28)

                    Text(feature.title)
                        .font(.headline)

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var plans: some View {
        VStack(spacing: 12) {
            ForEach(subscriptions.products, id: \.id) { product in
                Button {
                    selectedProductID = product.id
                } label: {
                    planRow(for: product)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    selectedProductID == product.id ? .isSelected : []
                )
            }
        }
    }

    private func planRow(for product: Product) -> some View {
        let isSelected = selectedProductID == product.id

        return HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.id == SubscriptionManager.ProductID.annual ? "Annual" : "Monthly")
                        .font(.headline)

                    if product.id == SubscriptionManager.ProductID.annual {
                        Text("BEST VALUE")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                    }
                }

                if let detail = billingDetail(for: product) {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(product.displayPrice)
                .font(.headline)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.orange : Color.secondary.opacity(0.2), lineWidth: 2)
        }
        .contentShape(Rectangle())
    }

    private var subscribeButton: some View {
        Button {
            guard let selectedProduct else { return }

            Task {
                do {
                    let purchased = try await subscriptions.purchase(selectedProduct)
                    if purchased {
                        onSubscribed?()
                        dismiss()
                    }
                } catch {
                    // SubscriptionManager publishes the user-facing error.
                }
            }
        } label: {
            Group {
                if subscriptions.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(selectedProduct == nil || subscriptions.isPurchasing)
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Plans unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Try Again") {
                Task { await subscriptions.refresh() }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("Payment is charged to your Apple Account. Your subscription renews automatically unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task {
                        do {
                            try await subscriptions.restorePurchases()
                        } catch {
                            // SubscriptionManager publishes the user-facing error.
                        }
                    }
                }

                Button("Terms") { openURL(termsOfUseURL) }
                Button("Privacy") { openURL(privacyPolicyURL) }
            }
            .font(.footnote)
        }
    }

    private func selectDefaultProduct() {
        if subscriptions.annualProduct != nil {
            selectedProductID = SubscriptionManager.ProductID.annual
        } else if let firstProduct = subscriptions.products.first {
            selectedProductID = firstProduct.id
        }
    }

    private func billingDetail(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: return nil
        }

        return "Billed every \(period.value) \(unit)"
    }
}

// MARK: - Drop-in premium gate

struct PremiumFeatureButton<Label: View>: View {
    @Bindable var subscriptions: SubscriptionManager
    let feature: SubscriptionManager.PremiumFeature
    let privacyPolicyURL: URL
    let termsOfUseURL: URL
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var showingPaywall = false

    var body: some View {
        Button {
            if subscriptions.canUse(feature) {
                action()
            } else {
                showingPaywall = true
            }
        } label: {
            label()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                subscriptions: subscriptions,
                privacyPolicyURL: privacyPolicyURL,
                termsOfUseURL: termsOfUseURL
            )
        }
    }
}
