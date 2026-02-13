import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab: Tab = .orders
    @State private var hideTabBar = false
    private let debugLayoutColors = false

    var body: some View {
        ZStack {
            (debugLayoutColors ? Color.cyan.opacity(0.3) : Theme.background).ignoresSafeArea()

            Group {
                switch selectedTab {
                case .orders:
                    RecordsView { isVisible in
                        hideTabBar = isVisible
                    }
                case .taxes:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .environmentObject(appState)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !hideTabBar {
                customTabBar
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab != .orders {
                hideTabBar = false
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 8) {
            tabButton(.orders, titleKey: "tab.orders", systemImage: "list.bullet.rectangle.portrait.fill")
            tabButton(.taxes, titleKey: "tab.taxes", systemImage: "banknote.fill")
            tabButton(.settings, titleKey: "tab.settings", systemImage: "gearshape.fill")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(debugLayoutColors ? Color(red: 0.55, green: 1.0, blue: 0.35) : Theme.background)
    }

    private func tabButton(_ tab: Tab, titleKey: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(LocalizedStringKey(titleKey))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        debugLayoutColors
                            ? (isSelected ? Color.yellow.opacity(0.45) : Color.black.opacity(0.35))
                            : (isSelected ? Theme.cardMuted.opacity(0.9) : Theme.card.opacity(0.75))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private enum Tab: Hashable {
    case orders
    case taxes
    case settings
}
