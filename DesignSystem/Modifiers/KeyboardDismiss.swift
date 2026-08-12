import SwiftUI

extension View {

    /// Dismisses the keyboard when the user taps outside a text field.
    ///
    /// Attached at low priority so buttons and list rows underneath keep working
    /// — a plain `.onTapGesture` on a container swallows their taps, which reads
    /// as the screen being dead.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }

    /// Dismisses the keyboard when a scroll view starts moving.
    func dismissKeyboardOnDrag() -> some View {
        scrollDismissesKeyboardCompat()
    }
}

private extension View {
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        // `.scrollDismissesKeyboard` needs iOS 16, which is this app's floor, but
        // keeping the check documents why the fallback exists for anyone who
        // lowers the target.
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.immediately)
        } else {
            self
        }
    }
}
