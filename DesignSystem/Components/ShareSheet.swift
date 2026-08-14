import SwiftUI
import UIKit

extension View {

    /// Bảng chia sẻ của hệ thống.
    ///
    /// ```swift
    /// .shareSheet(isPresented: $isSharing, items: [AppEnvironment.appStoreURL])
    /// ```
    ///
    /// iOS 16 có `ShareLink`, và nếu chỉ cần **một nút** chia sẻ thì dùng nó — đẹp hơn,
    /// accessibility sẵn. Cái này dành cho khi việc chia sẻ được kích hoạt từ *state*
    /// (xong một luồng, một action trong menu), chỗ mà `ShareLink` không đặt vào được.
    func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        sheet(isPresented: isPresented) {
            ShareSheet(items: items)
                // Bảng chia sẻ của hệ thống tự lo detent; ép detent vào là nó bị cắt.
                .ignoresSafeArea()
        }
    }
}

/// `UIActivityViewController` gói lại cho SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]
    var excluded: [UIActivity.ActivityType] = []

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excluded
        return controller
    }

    /// Cố ý để trống: dựng lại controller khi cha re-render sẽ làm bảng chia sẻ nhấp
    /// nháy hoặc tự đóng giữa chừng.
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
