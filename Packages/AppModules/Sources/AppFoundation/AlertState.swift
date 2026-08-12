import Foundation

/// An alert described as data.
///
/// An alert is a *state* the screen is in, not a one-shot effect: it survives
/// backgrounding, it is what the screen should show if the view is rebuilt, and
/// a test can assert it without touching SwiftUI. That is why this lives in the
/// ViewModel's `State` instead of travelling through an effect channel like
/// Compose's `ViewEffect`.
public struct AlertState: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }

    public init(error: AppError, title: String = "Lỗi") {
        self.init(title: title, message: error.userMessage)
    }
}
