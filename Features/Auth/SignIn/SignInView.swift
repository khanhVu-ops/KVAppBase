import SwiftUI

struct SignInView: View {

    @StateObject private var viewModel: SignInViewModel

    init(onSignedIn: @escaping @MainActor (AuthSession) -> Void) {
        _viewModel = StateObject(wrappedValue: SignInViewModel(onSignedIn: onSignedIn))
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Sign in")
                .font(AppFont.titleL)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Spacing.m) {
                // Text lives in the field's own small view with local `@State`
                // and is committed on change of focus/submit. Binding every
                // keystroke straight into the ViewModel would republish the
                // whole object on iOS 16 and re-run this body per character.
                DebouncedField(
                    title: "Email",
                    initial: viewModel.state.email,
                    keyboard: .emailAddress,
                    onCommit: { viewModel.send(.emailChanged($0)) }
                )

                DebouncedField(
                    title: "Password",
                    initial: viewModel.state.password,
                    isSecure: true,
                    onCommit: { viewModel.send(.passwordChanged($0)) }
                )

                if let fieldError = viewModel.state.fieldError {
                    Text(fieldError)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.Semantic.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button {
                viewModel.send(.submitTapped)
            } label: {
                if viewModel.state.isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Sign in").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.state.canSubmit)

            Button("Forgot password?") { viewModel.send(.forgotPasswordTapped) }
                .font(AppFont.caption)

            Spacer()
        }
        .padding(Spacing.l)
        .background(AppColor.Surface.background)
        .dismissKeyboardOnTap()
    }
}

/// Keeps in-progress text out of the ViewModel.
///
/// The ViewModel needs the value when the user is done with the field, not on
/// every keystroke — and on iOS 16 the difference is one full body re-run per
/// character versus one per field.
struct DebouncedField: View {

    let title: LocalizedStringResource
    let initial: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    let onCommit: (String) -> Void

    @State private var text: String = ""
    @State private var committed: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        // `prompt:` + label, không phải `TextField(title, text:)`: overload nhận
        // `LocalizedStringResource` cho vị trí đầu chỉ có từ **iOS 26**, nên cách viết
        // gọn kia không build được ở target 16.0. Init này có từ iOS 15 và còn tốt hơn
        // một chút — label là thứ VoiceOver đọc, prompt là chữ mờ người dùng thấy.
        Group {
            if isSecure {
                SecureField(text: $text, prompt: Text(title)) { Text(title) }
            } else {
                TextField(text: $text, prompt: Text(title)) { Text(title) }
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .focused($isFocused)
        .textFieldStyle(.roundedBorder)
        .onAppear {
            text = initial
            committed = initial
        }
        // `.task(id:)` cancels the previous run whenever `text` changes, which
        // makes this a debounce with no timer to manage. Typing twenty
        // characters publishes once or twice instead of twenty times — the point
        // of the exercise on iOS 16 — while the ViewModel still catches up on
        // its own, so a Submit button bound to committed state enables without
        // the user having to tap elsewhere first.
        //
        // Committing only on focus loss (the obvious first attempt) leaves the
        // button disabled while both fields are visibly filled. That looks
        // broken, and it is the reason this debounce exists at all.
        .task(id: text) {
            guard text != committed else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            commit()
        }
        .onSubmit(commit)
        .onChange(of: isFocused) { focused in
            // Leaving the field must not wait out the debounce.
            if !focused { commit() }
        }
    }

    private func commit() {
        guard text != committed else { return }
        committed = text
        onCommit(text)
    }
}

struct ForgotPasswordView: View {
    private let email: String?
    init(email: String?) { self.email = email }

    var body: some View {
        EmptyStateView(
            icon: "envelope",
            title: "Forgot password",
            message: email.map { "We will send instructions to \($0)." } ?? "Replace this with your real screen."
        )
        .navigationTitle("Forgot password")
    }
}

#Preview("Đăng nhập") {
    SignInView(onSignedIn: { _ in })
}

#Preview("Quên mật khẩu") {
    NavigationStack {
        ForgotPasswordView(email: "a@example.com")
    }
}
