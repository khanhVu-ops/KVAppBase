import SwiftUI

struct OrderDetailView: View {

    @StateObject private var viewModel: OrderDetailViewModel

    /// Reached from the list, with the object already in hand — renders with no
    /// spinner. This is the `pushView { }` path.
    init(order: Order) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderID: order.id, seed: order))
    }

    /// Reached from a route, a deep link or a restored stack — only an id is
    /// available, so the screen fetches.
    init(orderID: String) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderID: orderID))
    }

    var body: some View {
        LoadableContent(
            state: viewModel.state.order,
            onRetry: { viewModel.send(.appeared) }
        ) { order in
            OrderDetailContent(
                order: order,
                isCancelling: viewModel.state.isCancelling,
                onCancel: { viewModel.send(.cancelTapped) }
            )
        }
        .background(AppColor.Surface.background)
        .navigationTitle("Chi tiết đơn")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.send(.appeared) }
        .confirmationAlert(
            viewModel.state.alert,
            confirmTitle: "Huỷ đơn",
            onConfirm: { viewModel.send(.cancelConfirmed) },
            onDismiss: { viewModel.send(.alertDismissed) }
        )
    }
}

struct OrderDetailContent: View, Equatable {

    let order: Order
    let isCancelling: Bool
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                OrderStatusBadge(status: order.status)

                row("Mã đơn", Text(verbatim: order.code))
                row("Khách hàng", Text(verbatim: order.customerName))
                row("Tổng tiền", Text(order.total, format: .currency(code: "VND")))
                row("Ngày đặt", Text(order.placedAt, format: .dateTime.day().month().year().hour().minute()))

                if order.isCancellable {
                    Button(role: .destructive, action: onCancel) {
                        if isCancelling {
                            ProgressView()
                        } else {
                            Text("Huỷ đơn hàng").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCancelling)
                    .padding(.top, Spacing.m)
                }
            }
            .padding(Spacing.m)
        }
    }

    /// Nhận `Text` chứ không nhận `String`: số và ngày phải để SwiftUI format theo
    /// `\.locale`. `value.formatted(...)` dựng chuỗi **ngay lúc gọi** bằng
    /// `Locale.current` (ngôn ngữ của máy), nên nó không đổi khi người dùng đổi ngôn
    /// ngữ trong app — đã thấy tận mắt: cùng một đơn, list hiện `đ250,000` còn màn này
    /// vẫn `250.000 đ`.
    private func row(_ title: LocalizedStringResource, _ value: Text) -> some View {
        HStack {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Spacer()
            value
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.Text.primary)
        }
        .accessibilityElement(children: .combine)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.order == rhs.order && lhs.isCancelling == rhs.isCancelling
    }
}

#Preview {
    NavigationStack { OrderDetailView(order: .sample()) }
}
