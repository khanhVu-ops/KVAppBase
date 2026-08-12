import SwiftUI

/// The app's main call to action.
///
/// A `ButtonStyle` rather than a modifier because SwiftUI hands a style the
/// `isPressed` state, which a modifier cannot see — so a modifier version can
/// never give press feedback, and `.disabled` styling has to be passed in by
/// hand at every call site.
struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyStrong)
            .foregroundStyle(AppColor.Brand.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                (isEnabled ? AppColor.Brand.primary : AppColor.Text.disabled)
                    .opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: Radius.m)
            )
            // Reduce Motion users get the colour change without the squash.
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyStrong)
            .foregroundStyle(AppColor.Brand.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(AppColor.Surface.separator, lineWidth: 1)
                    .background(
                        AppColor.Surface.card.opacity(configuration.isPressed ? 0.6 : 0),
                        in: RoundedRectangle(cornerRadius: Radius.m)
                    )
            )
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
