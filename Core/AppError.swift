import Foundation

/// The only error type that crosses a layer boundary in this app.
///
/// It lives in `AppFoundation` rather than `Domain` because every layer speaks
/// it — `Data` produces it, `Domain` propagates it, features render it — and
/// `Loadable` needs it. Putting it in `Domain` would force `AppFoundation` to
/// depend on `Domain`, inverting the graph for one enum.
///
/// `KVAPIClientError`, `DecodingError`, `URLError` and friends are mapped to
/// this at the edge of `Data` and never travel further. See
/// `AppError+Network.swift` for the mapping.
enum AppError: Error, Equatable, Sendable {

    /// No usable connection. Worth a retry; never worth a logout.
    case offline

    /// The session is gone. `SessionController` handles this centrally — a
    /// ViewModel should ignore it rather than showing its own message.
    case unauthorized

    /// The server explained itself. Show `message` as-is: it is written for
    /// this user, in their language, about their request.
    ///
    /// `nil` khi backend chỉ trả status code không kèm lời nào — trước đây chỗ đó
    /// nhét câu generic vào như thể server đã nói, làm mất phân biệt giữa "server
    /// bảo thế" và "app tự nghĩ ra".
    case server(message: String?, code: Int)

    /// The response did not match what the app expects. Almost always a
    /// backend contract change; never actionable by the user.
    case decoding

    /// The caller cancelled. Not a failure — do not show anything.
    case cancelled

    /// The associated value is a diagnostic for the log, **not** for the user —
    /// see `userMessage`.
    case unknown(String)

    /// What a user should read, or `nil` khi không nên hiện gì.
    ///
    /// Kiểu là `LocalizedStringResource`, **không** phải `String`, và đó là điều kiện
    /// để đổi ngôn ngữ trong app có tác dụng. Đo trên simulator (máy vi, environment
    /// ja): `Text(LocalizedStringResource)` đổi theo `\.locale`, còn
    /// `Text(String(localized:))` thì không — `String(localized:)` resolve **ngay lúc
    /// gọi** theo ngôn ngữ của máy. Trả `String` ở đây nghĩa là mọi lỗi sẽ hiện sai
    /// ngôn ngữ ngay sau khi người dùng vừa đổi ngôn ngữ.
    ///
    /// `LocalizedStringResource` là Foundation, nên luật 1 (`Core`/`Domain` chỉ import
    /// Foundation) vẫn nguyên. Literal là **key** của `Localizable.xcstrings`.
    ///
    /// `nil` cho `.cancelled` thay vì chuỗi rỗng: "không hiện gì" là một trạng thái,
    /// không phải một chuỗi độ dài 0 — và Optional thì compiler bắt người gọi xử lý.
    var userMessage: LocalizedStringResource? {
        switch self {
        case .offline:
            return "No internet connection. Please try again."
        case .unauthorized:
            return "Your session has expired."
        case .server(let message, _):
            // Text của server, đã viết cho đúng người dùng này bằng ngôn ngữ của họ —
            // dịch lại là sai. Tra catalog sẽ trượt và trả về chính chuỗi này.
            guard let message else { return "Something went wrong. Please try again." }
            return LocalizedStringResource(String.LocalizationValue(message))
        case .decoding:
            return "The server returned invalid data. Please try again later."
        case .cancelled:
            return nil
        case .unknown:
            // Never the underlying description. `URLError.cannotFindHost`
            // renders as "Không thể tìm thấy máy chủ có tên máy chủ được chỉ
            // định." — system phrasing about the app's own configuration, shown
            // to someone who cannot act on it. The detail is already in the log,
            // where it belongs; see `diagnostic`.
            return "Something went wrong. Please try again."
        }
    }

    /// The underlying detail, for logs and bug reports. Never render this.
    var diagnostic: String? {
        switch self {
        case .unknown(let message):     return message.isEmpty ? nil : message
        case .server(let message, let code): return "\(code): \(message ?? "-")"
        default:                        return nil
        }
    }

    /// Whether showing a retry button makes sense.
    var isRetryable: Bool {
        switch self {
        case .offline, .unknown:            return true
        case .server(_, let code):          return code >= 500
        case .unauthorized, .decoding, .cancelled: return false
        }
    }
}
