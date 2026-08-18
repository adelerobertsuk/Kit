import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    enum ProductID {
        static let monthly = "com.yourcompany.runningmemory.premium.monthly"
        static let annual = "com.yourcompany.runningmemory.premium.annual"

        static let all: Set<String> = [monthly, annual]
    }

    enum PremiumFeature: String, CaseIterable, Identifiable {
        case unlimitedVoiceRecording
        case metaGlassesPhotoSync

        var id: Self { self }

        var title: String {
            switch self {
            case .unlimitedVoiceRecording: "Uncapped voice recording"
            case .metaGlassesPhotoSync: "Meta glasses photo sync"
            }
        }

        var systemImage: String {
            switch self {
            case .unlimitedVoiceRecording: "waveform"
            case .metaGlassesPhotoSync: "eyeglasses"
            }
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                "The App Store could not verify this purchase."
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var hasPremiumAccess: Bool {
        !purchasedProductIDs.isDisjoint(with: ProductID.all)
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly }
    }

    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual }
    }

    private init() {
        transactionUpdatesTask = observeTransactionUpdates()

        Task {
            await refresh()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedProducts = Product.products(for: ProductID.all)
            async let entitlementRefresh: Void = updatePurchasedProducts()

            products = try await loadedProducts.sorted(by: Self.sortProducts)
            _ = await entitlementRefresh
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return hasPremiumAccess

            case .pending, .userCancelled:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func restorePurchases() async throws {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        hasPremiumAccess
    }

    func clearError() {
        errorMessage = nil
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { return }

                do {
                    let transaction = try Self.checkVerified(update)
                    await self?.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var activeProductIDs: Set<String> = []

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard !transaction.isUpgraded else { continue }

            if let expirationDate = transaction.expirationDate,
               expirationDate <= Date() {
                continue
            }

            activeProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = activeProductIDs
    }

    private nonisolated static func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let value):
            value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }

    private nonisolated static func sortProducts(_ lhs: Product, _ rhs: Product) -> Bool {
        let order = [ProductID.annual, ProductID.monthly]
        return (order.firstIndex(of: lhs.id) ?? .max)
            < (order.firstIndex(of: rhs.id) ?? .max)
    }
}
