import SwiftUI

struct PennyAppIcon: View {
    let mintGreen = Color(red: 0.65, green: 0.90, blue: 0.80)
    let pastelPink = Color(red: 1.0, green: 0.68, blue: 0.68)
    let creamBG = Color(red: 0.99, green: 0.98, blue: 0.95)

    var body: some View {
        ZStack {
            creamBG

            // Computer Book Frame
            RoundedRectangle(cornerRadius: 48)
                .fill(pastelPink)
                .frame(width: 720, height: 720)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 48)
                        .stroke(mintGreen, lineWidth: 16)
                )

            // Screen & Pixel Paw
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(mintGreen.opacity(0.3))
                        .frame(width: 500, height: 420)

                    // Pixel Paw Silhouette
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Circle().fill(Color.black.opacity(0.8)).frame(width: 44, height: 44)
                            Circle().fill(Color.black.opacity(0.8)).frame(width: 52, height: 52)
                            Circle().fill(Color.black.opacity(0.8)).frame(width: 44, height: 44)
                        }
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 140, height: 110)
                    }
                }

                // Retro Buttons
                HStack(spacing: 24) {
                    Circle().fill(Color.white).frame(width: 40, height: 40)
                    Circle().fill(Color.white).frame(width: 40, height: 40)
                    Rectangle().fill(Color.white).frame(width: 120, height: 20).cornerRadius(10)
                }
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    PennyAppIcon()
}
