import SwiftUI
import WebKit

/// Màn web trong app — điều khoản, chính sách, trang trợ giúp.
///
/// Dùng cho các trang **của mình**. Link ra ngoài (mạng xã hội, một bài viết) thì mở
/// bằng `openURL` để người dùng có đủ Safari: chia sẻ, dịch, đọc offline. Nhốt web của
/// người khác vào một WKWebView trần là cách nhanh nhất để mất những thứ đó.
struct WebScreen: View {

    private let title: LocalizedStringResource
    private let url: URL

    init(title: LocalizedStringResource, url: URL) {
        self.title = title
        self.url = url
    }

    @State private var isLoading = true

    var body: some View {
        WebView(url: url, isLoading: $isLoading)
            .overlay {
                if isLoading {
                    // Không có nó thì trang trắng nhìn như app treo — với mạng chậm
                    // thì đó là vài giây người dùng không biết chuyện gì đang xảy ra.
                    ProgressView().controlSize(.large)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .background(AppColor.Surface.background)
    }
}

/// `WKWebView` gói lại cho SwiftUI.
private struct WebView: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        // Nền trong suốt để `AppColor.Surface.background` phía sau lộ ra trong lúc tải,
        // thay vì một mảng trắng nhấp nháy khi app đang ở dark mode.
        view.isOpaque = false
        view.backgroundColor = .clear
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        // Chỉ load lại khi URL thật sự đổi. Không có guard này thì mỗi lần cha
        // re-render là trang bị tải lại từ đầu, cuộn về đỉnh.
        guard view.url != url else { return }
        view.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        /// Hỏng ngay từ lúc kết nối (offline) rơi vào hàm này, **không** phải hàm trên —
        /// thiếu nó thì spinner quay mãi khi mất mạng.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}

#Preview("Điều khoản") {
    NavigationStack {
        WebScreen(title: "Terms of Use", url: AppEnvironment.termsOfUseURL)
    }
}
