import SwiftUI

public struct EmptyStateView: View, Equatable {
    private let icon: String
    private let title: String
    private let message: String

    public init(icon: String = "tray", title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(AppColor.Text.disabled)
            Text(title).font(AppFont.bodyStrong)
            Text(message)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.icon == rhs.icon && lhs.title == rhs.title && lhs.message == rhs.message
    }
}
