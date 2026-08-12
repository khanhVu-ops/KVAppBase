import SwiftUI

/// `Equatable` on purpose: on iOS 16 the parent's `body` re-runs on every state
/// change, and this is what lets SwiftUI skip rebuilding the subtree when the
/// error has not changed. The closure cannot be compared, so `==` looks at the
/// data only — see the note in the architecture skill about view decomposition.
struct ErrorStateView: View, Equatable {

    private let error: AppError
    private let onRetry: () -> Void

    init(error: AppError, onRetry: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: iconName)
                .font(.system(size: 44))
                .foregroundStyle(AppColor.Semantic.error)

            Text(error.userMessage)
                .font(AppFont.body)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)

            if error.isRetryable {
                Button("Thử lại", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.Brand.primary)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        switch error {
        case .offline: return "wifi.slash"
        case .unauthorized: return "lock"
        default: return "exclamationmark.triangle"
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.error == rhs.error
    }
}
