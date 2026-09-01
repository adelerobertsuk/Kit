import SwiftUI

struct KITAppIcon: View {
    let kitRed = Color(red: 1.0, green: 0.0, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 24) {
                // KIT LED Voice Box (Center Piece)
                HStack(spacing: 16) {
                    // Left Column
                    VStack(spacing: 6) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i > 4 ? kitRed : kitRed.opacity(0.15))
                                .frame(width: 48, height: 16)
                        }
                    }
                    // Center Column
                    VStack(spacing: 6) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i > 1 ? kitRed : kitRed.opacity(0.15))
                                .frame(width: 48, height: 16)
                        }
                    }
                    // Right Column
                    VStack(spacing: 6) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i > 4 ? kitRed : kitRed.opacity(0.15))
                                .frame(width: 48, height: 16)
                        }
                    }
                }
                .padding(32)
                .background(Color(white: 0.05))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(white: 0.2), lineWidth: 2))

                // Sweeping Scanner Bar Base
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, kitRed, .white, kitRed, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 280, height: 14)
                    .shadow(color: kitRed, radius: 12)
            }
            .scaleEffect(2.9)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    KITAppIcon()
}
