import SwiftUI
import UIKit

/// Thin wrapper around the native Share Sheet — Memory Card v1 shares a rendered card
/// image plus accessible plain text, per the v2-ux-spec's "image + plain text" default.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
