import SwiftUI

/// Chọn ngôn ngữ trong app.
///
/// Đổi ở đây là **toàn bộ** text đổi theo, không cần khởi động lại: `LanguageStore`
/// publish một `Locale` mới, `MyApp` bơm nó vào `\.locale`, và mọi `Text` mang
/// `LocalizedStringKey`/`LocalizedStringResource` được SwiftUI resolve lại. Đó là lý
/// do text đi xuyên tầng phải mang kiểu resource chứ không phải `String` — xem
/// `AppError.userMessage`.
struct LanguagePickerView: View {

    @EnvironmentObject private var language: LanguageStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(AppLanguage.allCases) { item in
                LanguageRow(
                    name: item.endonym,
                    isSelected: item == language.current,
                    onTap: { language.select(item) }
                )
            }
            .listStyle(.plain)
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

/// View con nhận value + closure, và `Equatable` — luật hiệu năng iOS 16: cha
/// invalidate theo object nên chỉ có cách này mới cho SwiftUI bỏ qua cả subtree.
private struct LanguageRow: View, Equatable {

    let name: LocalizedStringResource
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(name)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColor.Brand.primary)
                }
            }
            // Không có nó thì chỉ phần chữ bắt được tap, khoảng trống giữa tên và
            // dấu tick nuốt mất chạm — hàng trông như chết.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.isSelected == rhs.isSelected
    }
}

#Preview("Language picker") {
    LanguagePickerView()
        .environmentObject(LanguageStore(defaults: .previewDefaults))
}

#Preview("Đang chọn tiếng Nhật") {
    let store = LanguageStore(defaults: .previewDefaults)
    store.select(.japanese)
    return LanguagePickerView()
        .environmentObject(store)
        .environment(\.locale, store.locale)
}
