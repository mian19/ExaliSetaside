import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @State private var shift = false
    @State private var surge = false
    @State private var sweep = false
    @State private var reveal = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.2),
                    .clear,
                    Theme.accentDim.opacity(0.22),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 36)
            .scaleEffect(shift ? 1.15 : 0.86)
            .offset(x: shift ? -30 : 28, y: shift ? -42 : 38)
            .animation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true), value: shift)

            ZStack {
                Ellipse()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 260, height: 130)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -120, y: -180)
                    .blur(radius: 2)

                Capsule()
                    .fill(Theme.cardMuted.opacity(0.9))
                    .frame(width: 220, height: 52)
                    .rotationEffect(.degrees(16))
                    .offset(x: shift ? 84 : 102, y: shift ? -48 : -26)
                    .shadow(color: Theme.accent.opacity(0.2), radius: 12, x: 0, y: 8)

                Capsule()
                    .stroke(Theme.accent.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 180, height: 44)
                    .rotationEffect(.degrees(-19))
                    .offset(x: -74, y: 26)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.card.opacity(0.95))
                    .frame(width: 170, height: 120)
                    .rotationEffect(.degrees(-11))
                    .offset(x: 92, y: 154)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(Theme.gradient)
                            .offset(x: 22, y: 20)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Theme.accent.opacity(0.82))
                            .frame(width: 16, height: 16)
                            .offset(x: -18, y: -18)
                    }
                    .scaleEffect(surge ? 1.06 : 0.94)
                    .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: surge)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Theme.accent.opacity(0.78), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 360, height: 24)
                    .rotationEffect(.degrees(-17))
                    .blendMode(.screen)
                    .blur(radius: 6)
                    .offset(x: sweep ? 70 : -70, y: sweep ? -36 : 60)
                    .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: sweep)
            }
            .scaleEffect(reveal ? 1 : 0.82)
            .opacity(reveal ? 1 : 0)
            .blur(radius: reveal ? 0 : 8)
        }
        .onAppear {
            shift = true
            surge = true
            sweep = true
            withAnimation(.spring(response: 0.75, dampingFraction: 0.78).delay(0.08)) {
                reveal = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                onFinish()
            }
        }
    }
}
