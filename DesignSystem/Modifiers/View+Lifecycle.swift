import SwiftUI

extension View {

    /// Runs `action` the first time this view appears, and not again.
    ///
    /// `.task` and `.onAppear` both fire again when the app returns from the
    /// background, or when a parent rebuilds the subtree. For "load the screen's
    /// data" that means a refetch and a spinner every time the user switches
    /// apps and comes back.
    ///
    /// The ViewModel can guard on its own state (`guard case .idle`), and should
    /// for correctness. This is for the cases where there is no state to guard —
    /// analytics on screen entry, a one-time animation, focusing a field.
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }

    /// Async variant, cancelled if the view goes away before it finishes.
    func taskOnce(_ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(TaskOnceModifier(action: action))
    }
}

private struct OnFirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

private struct TaskOnceModifier: ViewModifier {
    let action: @Sendable () async -> Void
    @State private var hasRun = false

    func body(content: Content) -> some View {
        content.task {
            guard !hasRun else { return }
            hasRun = true
            await action()
        }
    }
}
