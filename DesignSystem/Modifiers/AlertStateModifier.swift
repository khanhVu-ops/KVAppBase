import SwiftUI

extension View {

    /// Presents an `AlertState` held in a ViewModel.
    ///
    /// Every screen was writing the same eight lines: a `Binding` that reads the
    /// state and dispatches a dismiss action on write, plus an `Alert` built from
    /// the three fields. Wrapping it keeps the alert declarative and keeps the
    /// dismiss action from being forgotten — a discarded alert whose state is
    /// never cleared cannot be shown a second time.
    func alert(
        _ state: AlertState?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        alert(item: Binding(get: { state }, set: { if $0 == nil { onDismiss() } })) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Đóng"), action: onDismiss)
            )
        }
    }

    /// Two-button variant for a destructive confirmation.
    func confirmationAlert(
        _ state: AlertState?,
        confirmTitle: String,
        onConfirm: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        alert(item: Binding(get: { state }, set: { if $0 == nil { onDismiss() } })) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .destructive(Text(confirmTitle), action: onConfirm),
                secondaryButton: .cancel(Text("Đóng"), action: onDismiss)
            )
        }
    }
}
