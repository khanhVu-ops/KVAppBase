import SwiftUI

struct LoadingView: View {
    private let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
            if let message {
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Đang tải")
    }
}

#Preview("Đang tải") {
    LoadingView(message: "Đang tải đơn hàng")
}

#Preview("Không có message") {
    LoadingView()
}
