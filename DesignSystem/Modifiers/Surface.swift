import SwiftUI

extension View {

    /// The app's card surface: background, corner radius, and a shadow that is
    /// visible on light and disappears on dark, where a raised surface reads as
    /// a lighter fill instead.
    func cardStyle(padding: CGFloat = Spacing.m) -> some View {
        modifier(CardStyleModifier(padding: padding))
    }

    /// Full-width, for buttons and rows that should fill their container.
    func fillWidth(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Standard screen padding. One place to change the app's gutter.
    func screenPadding() -> some View {
        padding(.horizontal, Spacing.m).padding(.vertical, Spacing.s)
    }
}

private struct CardStyleModifier: ViewModifier {
    let padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColor.Surface.card, in: RoundedRectangle(cornerRadius: Radius.m))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0 : 0.06),
                radius: 8,
                y: 2
            )
    }
}
