import SwiftUI
import KVRouterKit   // Views may import the full router: `pushView` belongs here

struct OrderListView: View {

    @StateObject private var viewModel = OrderListViewModel()
    @State private var isLanguagePickerPresented = false

    init() {}

    // On iOS 16 `ObservableObject` publishes per *object*, so this body re-runs
    // on every state change. That is unavoidable; what is avoidable is the work
    // inside it. Everything below hands a plain value to a child view, so
    // SwiftUI can skip the children whose value did not change.
    var body: some View {
        LoadableContent(
            state: viewModel.state.orders,
            loadingMessage: "Đang tải đơn hàng",
            onRetry: { viewModel.send(.retryTapped) }
        ) { _ in
            loadedContent
        }
        .background(AppColor.Surface.background)
        .navigationTitle("Đơn hàng")
        .searchable(text: queryBinding, prompt: "Tìm theo mã đơn")
        .task { viewModel.send(.appeared) }
        .refreshable { await refresh() }
        .alert(viewModel.state.alert) { viewModel.send(.alertDismissed) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isLanguagePickerPresented = true
                } label: {
                    Image(systemName: "globe")
                }
                .accessibilityLabel("Language")
            }
        }
        .sheet(isPresented: $isLanguagePickerPresented) {
            LanguagePickerView()
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
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
}
