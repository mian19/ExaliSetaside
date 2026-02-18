import SwiftUI

struct RootView: View {
    @AppStorage(AppStorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !hasSeenOnboarding {
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

