import SwiftUI

/// Memory Card v1 review sheet: shows the card, lets the user edit title/summary,
/// carries an explicit privacy review step, then offers Save privately (primary) or
/// Share (secondary) — per v2-ux-spec.md section 3.4. Interceptor template only;
/// the Penny template ships alongside Penny becoming a real selectable skin.
struct MemoryCardReviewView: View {
    let entry: JournalEntry
    let onSave: (_ title: String, _ summary: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var summary: String
    @State private var showsSignature = true
    @State private var shareImage: UIImage?
    @State private var isPresentingShareSheet = false

    init(entry: JournalEntry, onSave: @escaping (_ title: String, _ summary: String) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _title = State(initialValue: entry.displayTitle)
        _summary = State(initialValue: entry.text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MemoryCardView(
                        title: title.isEmpty ? "Session Memory" : title,
                        summary: summary.isEmpty ? " " : summary,
                        date: entry.timestamp,
                        isBasicFallback: entry.isBasicFallback,
                        showsSignature: showsSignature
                    )
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("TITLE")
                            .cardFieldLabel()
                        TextField("Session Memory", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("SUMMARY")
                            .cardFieldLabel()
                        TextEditor(text: $summary)
                            .scrollContentBackground(.hidden)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Toggle(isOn: $showsSignature) {
                        Text("Show \u{201C}Made with Kit\u{201D} signature")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .tint(.cyan)

                    privacyNotice

                    VStack(spacing: 12) {
                        Button(action: saveAndDismiss) {
                            Text("SAVE PRIVATELY")
                                .font(.system(.headline, design: .monospaced, weight: .heavy))
                                .tracking(1.5)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: share) {
                            Text("SHARE OR EXPORT")
                                .font(.system(.footnote, design: .monospaced, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.045).ignoresSafeArea())
            .navigationTitle("Memory Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.04, green: 0.04, blue: 0.045), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { saveAndDismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isPresentingShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage, plainTextExport])
            }
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundColor(.cyan.opacity(0.8))
            Text("This card stays private on this device until you choose to share it. It never includes the raw transcript, exact time, or location.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.cyan.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func saveAndDismiss() {
        onSave(title, summary)
        dismiss()
    }

    private var plainTextExport: String {
        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM yyyy"
            return formatter
        }()
        var text = "\(title.isEmpty ? "Session Memory" : title)\n\(formatter.string(from: entry.timestamp))\n\n\(summary)"
        if showsSignature {
            text += "\n\nMade with Kit"
        }
        return text
    }

    private func share() {
        // Commit edits before sharing so the card that gets rendered matches what's saved.
        onSave(title, summary)
        let card = MemoryCardView(
            title: title.isEmpty ? "Session Memory" : title,
            summary: summary.isEmpty ? " " : summary,
            date: entry.timestamp,
            isBasicFallback: entry.isBasicFallback,
            showsSignature: showsSignature
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3 // ~1080px wide at the card's 360pt width, matching the spec's share-image target.
        shareImage = renderer.uiImage
        isPresentingShareSheet = true
    }
}

private extension Text {
    func cardFieldLabel() -> some View {
        self
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(1.5)
            .foregroundColor(.white.opacity(0.4))
    }
}

#Preview {
    MemoryCardReviewView(
        entry: JournalEntry(text: "Noticed how quiet the streets felt and decided to keep tomorrow morning free for writing.", isFromAI: true),
        onSave: { _, _ in }
    )
}
