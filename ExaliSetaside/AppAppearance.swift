import UIKit

enum AppAppearance {
    private static let debugLayoutColors = false

    static func configure() {
        configureNavigationBar()
        configureTabBar()
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        appearance.shadowColor = UIColor(white: 1.0, alpha: 0.08)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white
        ]

        appearance.titleTextAttributes = titleAttrs
        appearance.largeTitleTextAttributes = titleAttrs

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.compactScrollEdgeAppearance = appearance
        navBar.tintColor = UIColor(red: 1.0, green: 0.85, blue: 0.18, alpha: 1)
    }

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = debugLayoutColors
            ? UIColor(red: 0.55, green: 1.0, blue: 0.35, alpha: 0.95)
            : UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        appearance.shadowColor = .clear

        let selectedColor = UIColor(red: 1.0, green: 0.85, blue: 0.18, alpha: 1)
        let normalColor = UIColor(white: 0.78, alpha: 1)

        for itemAppearance in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = selectedColor
        tabBar.unselectedItemTintColor = normalColor
        tabBar.isTranslucent = false
    }
}
