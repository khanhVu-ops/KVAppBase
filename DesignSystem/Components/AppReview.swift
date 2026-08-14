import SwiftUI
import StoreKit

/// Xin đánh giá — hoặc mở thẳng App Store khi hệ thống sẽ không hiện hộp thoại.
///
/// Vì sao cần cả hai đường: `requestReview` của hệ thống bị Apple giới hạn (khoảng 3
/// lần/năm cho mỗi người) và khi vượt hạn **nó không làm gì cả, cũng không báo gì**.
/// Nếu người dùng chủ động bấm "Đánh giá" mà app gọi `requestReview` rồi im lặng thì
/// nút đó đọc như bị hỏng. Nên:
///
/// - Khoảnh khắc thụ động (vừa xong một việc, mở app lần thứ n): `requestReview`.
/// - Người dùng **chủ động bấm**: mở thẳng ô viết đánh giá trên App Store.
///
/// Số lần đã xin được đếm lại, để lần thứ ba trở đi không cố hiện một hộp thoại mà hệ
/// thống gần như chắc chắn nuốt.
@MainActor
enum AppReview {

    private static let askCountKey = "app.review.ask-count"
    /// Apple cho ~3 lần/năm. Sau ngần ấy lần thì coi như hết quota và đi đường store.
    private static let systemPromptBudget = 3

    /// Gọi ở khoảnh khắc thụ động. Không có gì hiện ra cũng là kết quả hợp lệ.
    static func requestPassively(_ request: RequestReviewAction) {
        let asked = UserDefaults.standard.integer(forKey: askCountKey)
        guard asked < systemPromptBudget else { return }
        UserDefaults.standard.set(asked + 1, forKey: askCountKey)
        request()
    }

    /// Gọi khi người dùng bấm nút "Đánh giá".
    ///
    /// Còn quota thì thử hộp thoại trong app (không rời app, tỉ lệ hoàn thành cao hơn);
    /// hết quota thì mở App Store, để cú bấm luôn dẫn tới **một** kết quả nhìn thấy được.
    static func requestOrOpenStore(_ request: RequestReviewAction, open: OpenURLAction) {
        let asked = UserDefaults.standard.integer(forKey: askCountKey)
        guard asked < systemPromptBudget, AppEnvironment.isAppStoreIDConfigured else {
            openWriteReview(open)
            return
        }
        UserDefaults.standard.set(asked + 1, forKey: askCountKey)
        request()
    }

    static func openWriteReview(_ open: OpenURLAction) {
        guard AppEnvironment.isAppStoreIDConfigured else {
            // Ở template thì appStoreID còn là placeholder. Mở link đó ra một trang
            // trắng còn khó hiểu hơn là không làm gì và nói tại sao.
            assertionFailure("AppEnvironment.appStoreID còn là placeholder — điền id thật trước khi bật nút đánh giá.")
            return
        }
        open(AppEnvironment.writeReviewURL)
    }
}

extension View {

    /// Nút "Đánh giá" dùng đúng đường: bấm tay thì luôn dẫn tới đâu đó.
    ///
    /// ```swift
    /// Button("Rate this app") { }.reviewAction()
    /// ```
    func reviewAction() -> some View {
        modifier(ReviewActionModifier())
    }
}

private struct ReviewActionModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.simultaneousGesture(TapGesture().onEnded {
            AppReview.requestOrOpenStore(requestReview, open: openURL)
        })
    }
}
