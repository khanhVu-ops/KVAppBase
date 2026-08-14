import Foundation

/// Ngôn ngữ người dùng chọn **trong app**, không phải ngôn ngữ của máy.
///
/// Danh sách này phải khớp `LANGUAGES` trong `tools/check-l10n.sh` và các thư mục
/// `App/Resources/<lang>.lproj` — `check-l10n.sh` so ba chỗ đó với nhau, vì một
/// ngôn ngữ có trong picker mà không có bản dịch là cách nhanh nhất để người dùng
/// chọn xong rồi thấy toàn tiếng Anh.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english        = "en"
    case arabic         = "ar"
    case chineseHans    = "zh-Hans"
    case chineseHant    = "zh-Hant"
    case dutch          = "nl"
    case french         = "fr"
    case german         = "de"
    case hindi          = "hi"
    case indonesian     = "id"
    case italian        = "it"
    case japanese       = "ja"
    case korean         = "ko"
    case portugueseBR   = "pt-BR"
    case portuguesePT   = "pt-PT"
    case russian        = "ru"
    case spanish        = "es"
    case thai           = "th"
    case turkish        = "tr"
    case vietnamese     = "vi"

    var id: String { rawValue }

    /// Mã ngôn ngữ để tra `.lproj`. `.system` lấy theo máy.
    var code: String {
        guard self != .system else {
            return Locale.preferredLanguages.first ?? "en"
        }
        return rawValue
    }

    var locale: Locale { Locale(identifier: code) }

    /// Tên ngôn ngữ **viết bằng chính ngôn ngữ đó** — người đang lạc trong một app
    /// tiếng Thái cần thấy "Tiếng Việt", không phải "Vietnamese".
    ///
    /// Kiểu resource chứ không phải `String`: hàng `.system` là một key cần dịch theo
    /// ngôn ngữ đang chọn, còn tên các ngôn ngữ khác là dữ liệu — tra catalog sẽ trượt
    /// và trả về chính nó.
    var endonym: LocalizedStringResource {
        guard self != .system else { return "System language" }
        let locale = Locale(identifier: code)
        let name = locale.localizedString(forIdentifier: code) ?? code
        let capitalised = name.prefix(1).uppercased() + name.dropFirst()
        return LocalizedStringResource(String.LocalizationValue(capitalised))
    }
}
