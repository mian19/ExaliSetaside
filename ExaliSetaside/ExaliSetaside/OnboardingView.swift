import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page: Int = 0
    @State private var selectedMode: TaxationMode = .freelancer

    private let pages = [
        OnboardingPage(icon: "chart.line.uptrend.xyaxis", title: "onboarding.1.title", subtitle: "onboarding.1.subtitle"),
        OnboardingPage(icon: "slider.horizontal.3", title: "onboarding.2.title", subtitle: "onboarding.2.subtitle"),
        OnboardingPage(icon: "bell.badge", title: "onboarding.3.title", subtitle: "onboarding.3.subtitle")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(Theme.card)
                                .frame(width: 240, height: 240)
                            Image(systemName: item.icon)
                                .font(.system(size: 88, weight: .semibold))
                                .foregroundStyle(Theme.gradient)
                        }

                        Text(LocalizedStringKey(item.title))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)

                        Text(LocalizedStringKey(item.subtitle))
                            .font(.system(size: 16, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 24)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 460)

            VStack(alignment: .leading, spacing: 10) {
                Text("onboarding.mode.title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Picker("onboarding.mode.title", selection: $selectedMode) {
                    ForEach(TaxationMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.localizedTitleKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)

            Button {
                if page < pages.count - 1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        page += 1
                    }
                } else {
                    onFinish()
                }
            } label: {
                Text(page == pages.count - 1 ? "onboarding.action.start" : "onboarding.action.next")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(Color.black)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 20)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

