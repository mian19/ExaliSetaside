import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let card = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let cardMuted = Color(red: 0.20, green: 0.20, blue: 0.21)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.84)
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.18)
    static let accentDim = Color(red: 0.86, green: 0.68, blue: 0.12)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.15)
    static let success = Color(red: 0.48, green: 1.0, blue: 0.6)

    static let gradient = LinearGradient(
        colors: [accent.opacity(0.95), accentDim.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
