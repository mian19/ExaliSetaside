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

            VStack {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.accent.opacity(0.24), lineWidth: 1)
                        .frame(width: 232, height: 232)
                        .rotationEffect(.degrees(-12))

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.cardMuted.opacity(0.45))
                        .frame(width: 188, height: 138)
                        .rotationEffect(.degrees(-14))
                        .offset(x: shift ? -20 : -8, y: shift ? -12 : -2)
                        .shadow(color: Theme.accent.opacity(0.22), radius: 14, x: 0, y: 10)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.card.opacity(0.94))
                        .frame(width: 188, height: 138)
                        .rotationEffect(.degrees(10))
                        .offset(x: shift ? 20 : 8, y: shift ? 12 : 2)
                        .shadow(color: Theme.accentDim.opacity(0.2), radius: 14, x: 0, y: 10)

                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.card.opacity(0.96))
                        .frame(width: 128, height: 128)
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        }
                        .overlay {
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(Theme.gradient)
                                .offset(y: surge ? -2 : 2)
                        }
                        .scaleEffect(surge ? 1.08 : 0.92)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 24, x: 0, y: 14)
                        .animation(.easeInOut(duration: 0.92).repeatForever(autoreverses: true), value: surge)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Theme.accent.opacity(0.72), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 320, height: 26)
                        .blendMode(.screen)
                        .blur(radius: 7)
                        .offset(y: sweep ? 84 : -84)
                        .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true), value: sweep)
                }
                .scaleEffect(reveal ? 1 : 0.82)
                .opacity(reveal ? 1 : 0)
                .blur(radius: reveal ? 0 : 8)

                Spacer()
            }
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
