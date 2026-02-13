import SwiftUI
import UIKit
import Combine

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptiveModifier())
    }
}

private struct KeyboardAdaptiveModifier: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.height)
            .animation(.easeOut(duration: 0.22), value: keyboard.height)
    }
}

private final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        willChange
            .compactMap { notification -> CGFloat? in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                let overlap = UIScreen.main.bounds.maxY - frame.minY
                return max(0, overlap)
            }
            .sink { [weak self] newHeight in
                self?.height = newHeight
            }
            .store(in: &cancellables)

        willHide
            .sink { [weak self] _ in
                self?.height = 0
            }
            .store(in: &cancellables)
    }
}
