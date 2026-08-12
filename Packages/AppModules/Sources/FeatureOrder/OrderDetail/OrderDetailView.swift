import SwiftUI
import AppFoundation
import Domain
import DesignSystem

public struct OrderDetailView: View {

    @StateObject private var viewModel: OrderDetailViewModel

    /// Reached from the list, with the object already in hand — renders with no
    /// spinner. This is the `pushView { }` path.
    public init(order: Order) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderID: order.id, seed: order))
    }

    /// Reached from a route, a deep link or a restored stack — only an id is
    /// available, so the screen fetches.
    public init(orderID: String) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderID: orderID))
    }

    public var body: some View {
        content
            .background(AppColor.Surface.background)
            .navigationTitle("Chi tiết đơn")
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.send(.appeared) }
            .alert(item: alertBinding) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .destructive(Text("Huỷ đơn")) {
                        viewModel.send(.cancelConfirmed)
                    },
                    secondaryButton: .cancel(Text("Đóng")) {
                        viewModel.send(.alertDismissed)
                    }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.order {
        case .idle, .loading:
            LoadingView()
        case .failed(let error):
            ErrorStateView(error: error) { viewModel.send(.appeared) }
        case .loaded(let order):
            OrderDetailContent(
                order: order,
                isCancelling: viewModel.state.isCancelling,
                onCancel: { viewModel.send(.cancelTapped) }
            )
        }
    }

    private var alertBinding: Binding<AlertState?> {
        Binding(
            get: { viewModel.state.alert },
            set: { _ in viewModel.send(.alertDismissed) }
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
