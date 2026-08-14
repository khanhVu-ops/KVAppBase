import SwiftUI

/// Renders the four states of a `Loadable` so each screen stops repeating the
/// same `switch`.
///
/// The idle/loading/failed branches were identical in the order list and the
/// order detail, and the third screen would have copied them again. Only the
/// loaded case is ever screen-specific, so that is the only closure a caller has
/// to write.
struct LoadableContent<Value: Equatable & Sendable, Content: View>: View {

    let state: Loadable<Value>
    var loadingMessage: String?
    let onRetry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            LoadingView(message: loadingMessage)
        case .failed(let error):
            ErrorStateView(error: error, onRetry: onRetry)
        case .loaded(let value):
            content(value)
        }
    }
}

#Preview("Đã tải") {
    LoadableContent(state: .loaded(Order.samples), loadingMessage: "Đang tải", onRetry: {}) { orders in
        Text(verbatim: "\(orders.count) đơn hàng")
    }
}

#Preview("Đang tải") {
    LoadableContent(state: Loadable<[Order]>.loading, loadingMessage: "Đang tải đơn hàng", onRetry: {}) { _ in
        EmptyView()
    }
}

#Preview("Lỗi") {
    LoadableContent(state: Loadable<[Order]>.failed(.offline), loadingMessage: "Đang tải", onRetry: {}) { _ in
        EmptyView()
    }
}
