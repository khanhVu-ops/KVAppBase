import SwiftUI

struct EmptyStateView: View, Equatable {
    private let icon: String
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource

    init(icon: String = "tray", title: LocalizedStringResource, message: LocalizedStringResource) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
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

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.icon == rhs.icon && lhs.title == rhs.title && lhs.message == rhs.message
    }
}

#Preview("Rỗng") {
    EmptyStateView(
        icon: "shippingbox",
        title: "No orders yet",
        message: "Your orders will appear here."
    )
}
