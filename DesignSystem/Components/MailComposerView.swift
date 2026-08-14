import SwiftUI
import MessageUI

/// Soạn mail hỗ trợ ngay trong app.
///
/// `MFMailComposeViewController` chỉ dùng được khi máy đã cấu hình tài khoản trong app
/// Mail — trên máy chỉ dùng Gmail/Outlook thì `canSendMail()` trả `false`. Nên luôn đi
/// kèm đường lui `mailto:`; bỏ qua bước kiểm đó là nút "Liên hệ" im lặng không làm gì
/// trên một phần máy thật.
struct MailComposerView: UIViewControllerRepresentable {

    let recipient: String
    let subject: String
    let body: String
    var onFinish: (@Sendable @MainActor () -> Void)?

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    /// Đường lui khi máy không có app Mail: đẩy sang `mailto:` để hệ thống chọn app.
    static func mailtoURL(recipient: String, subject: String, body: String) -> URL? {
        var components = URLComponents(string: "mailto:\(recipient)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }

    /// Thông tin máy đính kèm sẵn trong mail hỗ trợ. Không có nó thì mọi mail đều bắt
    /// đầu bằng một vòng hỏi lại "bạn dùng bản nào, máy gì".
    static func diagnosticsBody() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return """


        ---
        App: \(version) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: (@Sendable @MainActor () -> Void)?

        init(onFinish: (@Sendable @MainActor () -> Void)?) { self.onFinish = onFinish }

        /// Requirement của `MFMailComposeViewControllerDelegate` là **nonisolated**,
        /// nên không đánh `@MainActor` lên nó được (conformance sẽ không hợp lệ). Cách
        /// đúng dưới `SWIFT_STRICT_CONCURRENCY: complete` là hop tường minh sang main,
        /// và chỉ mang theo giá trị gửi được — `onFinish` phải `@Sendable`.
        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let finish = onFinish
            Task { @MainActor in
                // Tự dismiss: controller này không nằm trong stack của SwiftUI nên
                // không ai đóng hộ, và người dùng kẹt lại sau khi bấm Gửi.
                controller.dismiss(animated: true)
                finish?()
            }
        }
    }
}
