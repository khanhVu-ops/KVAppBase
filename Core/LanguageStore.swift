import Foundation

/// Ngôn ngữ đang chọn, và cây bundle để dịch những chuỗi **buộc phải** là `String`.
///
/// Cách đổi ngôn ngữ ở app này là `.environment(\.locale, …)` chứ không phải ghi
/// `AppleLanguages` rồi bắt khởi động lại. Đo trên simulator (ngôn ngữ máy vi,
/// environment ja):
///
/// | Cách viết | Đổi theo environment? |
/// |---|---|
/// | `Text("key")` (`LocalizedStringKey`) | có |
/// | `Text(LocalizedStringResource("key"))` | có |
/// | `Text(String(localized: "key"))` | **không** |
/// | `String(localized: "key", locale: ja)` | **không** — `locale:` chỉ đổi format, không đổi `.lproj` |
///
/// Nên text đi xuyên tầng mang kiểu `LocalizedStringResource`, và View để SwiftUI
/// resolve. Chỗ duy nhất cần `String` thật là text đi ra ngoài environment của
/// SwiftUI — toast dựng ở window riêng — và đó là lý do `localized(_:)` dưới đây
/// tồn tại: nó tra thẳng bundle `.lproj` của ngôn ngữ đang chọn.
@MainActor
final class LanguageStore: ObservableObject {

    private static let storageKey = "app.language"

    @Published private(set) var current: AppLanguage {
        didSet { defaults.set(current.rawValue, forKey: Self.storageKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey) ?? ""
        self.current = AppLanguage(rawValue: saved) ?? .system
    }

    var locale: Locale { current.locale }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        current = language
    }

    /// Dịch một `LocalizedStringResource` sang `String` theo ngôn ngữ đang chọn.
    ///
    /// Chỉ dùng khi bắt buộc phải có `String` — `String(localized:)` sẽ lấy ngôn ngữ
    /// **của máy**, không phải ngôn ngữ người dùng chọn trong app, nên nó lặng lẽ sai
    /// đúng ở màn hình mà người dùng vừa đổi ngôn ngữ xong.
    func localized(_ resource: LocalizedStringResource) -> String {
        Bundle.forLanguage(current).localizedString(forKey: resource.key, value: nil, table: nil)
    }
}

extension UserDefaults {
    /// Dùng cho `#Preview` và test: chọn ngôn ngữ trong canvas không được ghi đè lựa
    /// chọn thật của người dùng trên máy.
    /// Computed chứ không phải `static let`: `UserDefaults` không `Sendable`, nên một
    /// hằng toàn cục là lỗi build dưới `SWIFT_STRICT_CONCURRENCY: complete`. Gọi lại
    /// `UserDefaults(suiteName:)` vẫn trả về cùng một kho, nên không mất gì.
    static var previewDefaults: UserDefaults {
        UserDefaults(suiteName: "com.kvappbase.preview") ?? .standard
    }
}

extension Bundle {
    /// Bundle `.lproj` của một ngôn ngữ, fallback về English rồi main.
    ///
    /// Ưu tiên định danh đầy đủ trước mã trần: `zh-Hans` và `pt-BR` có `.lproj`
    /// riêng, tra bằng `zh`/`pt` sẽ trượt sang bundle khác hoặc không thấy gì.
    static func forLanguage(_ language: AppLanguage) -> Bundle {
        let code = language.code
        var candidates = [code]
        if let base = code.split(separator: "-").first.map(String.init), base != code {
            candidates.append(base)
        }
        candidates.append("en")
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .main
    }
}
