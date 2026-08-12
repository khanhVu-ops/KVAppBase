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

                row("Mã đơn", order.code)
                row("Khách hàng", order.customerName)
                row("Tổng tiền", order.total.formatted(.currency(code: "VND")))
                row("Ngày đặt", order.placedAt.formatted(date: .abbreviated, time: .shortened))

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

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Spacer()
            Text(value)
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
