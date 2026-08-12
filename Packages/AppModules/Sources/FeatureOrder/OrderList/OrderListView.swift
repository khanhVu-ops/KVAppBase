import SwiftUI
import AppFoundation
import Domain
import DesignSystem
import KVRouterKit   // Views may import the full router: `pushView` belongs here

public struct OrderListView: View {

    @StateObject private var viewModel = OrderListViewModel()

    public init() {}

    // On iOS 16 `ObservableObject` publishes per *object*, so this body re-runs
    // on every state change. That is unavoidable; what is avoidable is the work
    // inside it. Everything below hands a plain value to a child view, so
    // SwiftUI can skip the children whose value did not change.
    public var body: some View {
        content
            .background(AppColor.Surface.background)
            .navigationTitle("Đơn hàng")
            .searchable(text: queryBinding, prompt: "Tìm theo mã đơn")
            .task { viewModel.send(.appeared) }
            .refreshable { await refresh() }
            .alert(item: alertBinding) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.orders {
        case .idle, .loading:
            LoadingView(message: "Đang tải đơn hàng")

        case .failed(let error):
            ErrorStateView(error: error) { viewModel.send(.retryTapped) }

        case .loaded:
            if viewModel.state.showsEmptyState {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "Chưa có đơn hàng",
                    message: "Đơn hàng của bạn sẽ xuất hiện ở đây."
                )
            } else {
                OrderRows(
                    orders: viewModel.state.visibleOrders,
                    onTap: { viewModel.send(.orderTapped(id: $0)) }
                )
            }
        }
    }

    private func refresh() async {
        viewModel.send(.pulledToRefresh)
        await viewModel.waitForLoad()
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.state.query },
            set: { viewModel.send(.queryChanged($0)) }
        )
    }

    private var alertBinding: Binding<AlertState?> {
        Binding(
            get: { viewModel.state.alert },
            set: { _ in viewModel.send(.alertDismissed) }
        )
    }
}
