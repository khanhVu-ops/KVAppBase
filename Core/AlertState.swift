import Foundation

/// An alert described as data.
///
/// An alert is a *state* the screen is in, not a one-shot effect: it survives
/// backgrounding, it is what the screen should show if the view is rebuilt, and
/// a test can assert it without touching SwiftUI. That is why this lives in the
/// ViewModel's `State` instead of travelling through an effect channel like
/// Compose's `ViewEffect`.
struct AlertState: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    init(id: UUID = UUID(), title: LocalizedStringResource, message: LocalizedStringResource) {
        self.id = id
        self.title = title
        self.message = message
    }

    /// `.cancelled` không có gì để nói, nên nó không dựng được alert — người gọi phải
    /// xử lý `nil` thay vì hiện một hộp thoại trống.
    init?(error: AppError, title: LocalizedStringResource = "Error") {
        guard let message = error.userMessage else { return nil }
        self.init(title: title, message: message)
    }
}
