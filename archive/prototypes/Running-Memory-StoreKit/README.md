# Running Memory StoreKit 2 setup

1. In App Store Connect, create one auto-renewable subscription group with monthly and annual products.
2. Replace the two placeholder IDs in `SubscriptionManager.ProductID` with the exact App Store Connect product IDs.
3. Add `SubscriptionManager.swift` and `PaywallView.swift` to the iOS app target. The code targets iOS 17+ and uses Swift Observation.
4. Supply real Terms of Use and Privacy Policy URLs when presenting the paywall.
5. Test with a StoreKit Configuration file, then with sandbox accounts/TestFlight before release.

## App setup

```swift
import SwiftUI

@main
struct RunningMemoryApp: App {
    @State private var subscriptions = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptions)
        }
    }
}
```

## Gate a premium action

Check the entitlement at the exact point where the user starts voice recording or Meta photo sync. UI hiding alone is not a sufficient gate.

```swift
struct RunDetailView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var showingPaywall = false

    var body: some View {
        Button("Start voice recording") {
            guard subscriptions.canUse(.unlimitedVoiceRecording) else {
                showingPaywall = true
                return
            }

            startVoiceRecording()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                subscriptions: subscriptions,
                privacyPolicyURL: URL(string: "https://example.com/privacy")!,
                termsOfUseURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
            )
        }
    }

    private func startVoiceRecording() {
        // Your recording implementation.
    }
}
```

For Meta photo sync, use the same pattern with `.metaGlassesPhotoSync` before starting or scheduling a sync.

## Notes

- `Transaction.currentEntitlements` is the source of truth for current access.
- `Transaction.updates` keeps access current after renewals, refunds, revocations, and purchases completed elsewhere.
- `AppStore.sync()` is only called after the user taps Restore Purchases.
- Production apps with cross-device accounts should also validate subscription state on a trusted server using App Store Server APIs and notifications.
