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
    var loadingMessage: LocalizedStringResource?
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

// Preview dùng `[String]`, không dùng entity của app. DesignSystem phải dựng
// được mà không cần biết app này bán hàng hay đo bước chân — và một app tạo từ
// template không có `Order` để mà preview.

#Preview("Đã tải") {
    LoadableContent(state: .loaded(["A", "B", "C"]), loadingMessage: "Loading", onRetry: {}) { items in
        Text(verbatim: "\(items.count) mục")
    }
}

#Preview("Đang tải") {
    LoadableContent(state: Loadable<[String]>.loading, loadingMessage: "Loading", onRetry: {}) { _ in
        EmptyView()
    }
}

#Preview("Lỗi") {
    LoadableContent(state: Loadable<[String]>.failed(.offline), loadingMessage: "Loading", onRetry: {}) { _ in
        EmptyView()
    }
}
