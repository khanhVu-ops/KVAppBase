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
    case server(message: String, code: Int)

    /// The response did not match what the app expects. Almost always a
    /// backend contract change; never actionable by the user.
    case decoding

    /// The caller cancelled. Not a failure — do not show anything.
    case cancelled

    /// The associated value is a diagnostic for the log, **not** for the user —
    /// see `userMessage`.
    case unknown(String)

    /// What a user should read. Kept here so every screen phrases the same
    /// failure the same way.
    var userMessage: String {
        switch self {
        case .offline:
            return "Không có kết nối mạng. Vui lòng thử lại."
        case .unauthorized:
            return "Phiên đăng nhập đã hết hạn."
        case .server(let message, _):
            return message
        case .decoding:
            return "Dữ liệu trả về không hợp lệ. Vui lòng thử lại sau."
        case .cancelled:
            return ""
        case .unknown:
            // Never the underlying description. `URLError.cannotFindHost`
            // renders as "Không thể tìm thấy máy chủ có tên máy chủ được chỉ
            // định." — system phrasing about the app's own configuration, shown
            // to someone who cannot act on it. The detail is already in the log,
            // where it belongs; see `diagnostic`.
            return "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }

    /// The underlying detail, for logs and bug reports. Never render this.
    var diagnostic: String? {
        switch self {
        case .unknown(let message):     return message.isEmpty ? nil : message
        case .server(let message, let code): return "\(code): \(message)"
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
