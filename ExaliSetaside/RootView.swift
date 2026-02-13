import SwiftUI

struct RootView: View {
    @AppStorage(AppStorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !splashFinished {
                SplashView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        splashFinished = true
                    }
                }
                .transition(.opacity)
            } else if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}

private enum AppStorageKeys {
    static let hasSeenOnboarding = "hasSeenOnboarding"
}

