import SwiftUI
import KVToastKit

enum AppToast {

    /// The app's toast look, expressed through KVToastKit's appearance tokens
    /// rather than a replacement view — the package keeps owning the gesture,
    /// queueing and accessibility behaviour, which is the part worth not
    /// rewriting.
    ///
    /// `@MainActor` because `KVDefaultToastStyle` is: a style is only ever built
    /// while wiring up the view hierarchy, which already runs there.
    @MainActor
    static var style: KVDefaultToastStyle {
        var appearance = KVToastAppearance.default
        appearance.shape = .rounded(Radius.m)
        appearance.font = AppFont.bodyStrong
        appearance.tint = { kind in
            switch kind {
            case .success: return AppColor.Semantic.success
            case .warning: return AppColor.Semantic.warning
            case .error:   return AppColor.Semantic.error
            case .info:    return AppColor.Semantic.info
            }
        }
        return KVDefaultToastStyle(appearance: appearance)
    }
}

extension ToastService {

    /// Bridges the app's transport-free `ToastService` port onto a real toast
    /// center. `post(_:)` hops to the main actor itself, so a ViewModel can call
    /// this from anywhere without an `await`.
    /// Toast được KVToastKit dựng ở **window riêng**, ngoài environment của SwiftUI,
    /// nên `\.locale` không với tới nó: text phải được dịch ngay tại đây, theo ngôn
    /// ngữ người dùng đang chọn. Đây là chỗ duy nhất trong app cần `Bundle` của một
    /// `.lproj` cụ thể — mọi chỗ khác để SwiftUI resolve.
    static func live(_ center: KVToastCenter, language: LanguageStore) -> ToastService {
        ToastService { message, kind in
            MainActor.assumeIsolated {
                center.post(KVToastItem(message: language.localized(message), kind: kind.kvKind))
            }
        }
    }
}

private extension ToastKind {
    var kvKind: KVToastKind {
        switch self {
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
}
