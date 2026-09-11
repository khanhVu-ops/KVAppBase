import SwiftUI

// MARK: - Nhánh theo availability

/// App chạy tối thiểu iOS 16.0, nhưng nhiều modifier hữu ích chỉ có từ 16.4 hoặc 17.
/// Những helper dưới đây để rẽ nhánh **theo `#available`** cho gọn.
///
/// ⚠️ Đọc kỹ chỗ này trước khi dùng cho việc khác: rẽ `if/else` giữa một chuỗi modifier
/// làm SwiftUI thấy **hai kiểu view khác nhau** ở hai nhánh, nên nó coi là hai view
/// khác nhau — `@State` của subtree bị reset, animation gãy, gesture mất giữa chừng.
///
/// Với `#available` thì điều đó **vô hại**: kết quả cố định suốt vòng đời tiến trình,
/// nhánh không bao giờ đổi, nên không có lần rebuild nào để mất state.
/// Với một điều kiện theo **state** (`applyIf(isSelected)`) thì đó chính là cái bẫy —
/// dùng modifier nhận tham số thay vì rẽ nhánh:
///
/// ```swift
/// // ❌ đổi identity mỗi lần isHighlighted đổi
/// .applyIf(isHighlighted) { $0.background(Color.yellow) }
/// // ✅ một view, một identity
/// .background(isHighlighted ? Color.yellow : .clear)
/// ```
extension View {

    /// Rẽ nhánh cho một khối `#available`. Chỉ dùng cho điều kiện **không đổi lúc chạy**.
    @ViewBuilder
    func applyIfAvailable<Content: View>(
        _ isAvailable: Bool,
        @ViewBuilder _ transform: (Self) -> Content
    ) -> some View {
        if isAvailable { transform(self) } else { self }
    }

    /// Hai nhánh, khi bản OS cũ cần một cách làm khác chứ không phải "bỏ qua".
    @ViewBuilder
    func applyIfAvailable<New: View, Old: View>(
        _ isAvailable: Bool,
        @ViewBuilder then newer: (Self) -> New,
        @ViewBuilder else older: (Self) -> Old
    ) -> some View {
        if isAvailable { newer(self) } else { older(self) }
    }
}

// MARK: - Sheet

extension View {

    /// Nền cho sheet. `presentationBackground` chỉ có từ **iOS 16.4**; dưới đó chỉ có
    /// cách đặt màu vào chính content, và nền sau content vẫn là màu hệ thống.
    ///
    /// Không tự vẽ lại sheet để có nền tuỳ ý — thứ bạn mất là drag indicator, detent,
    /// resize theo bàn phím, và hành vi accessibility, đổi lấy một hình chữ nhật.
    @ViewBuilder
    func sheetBackground(_ color: Color) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(color)
        } else {
            // Dưới 16.4: tô vào content. Mép sheet vẫn là nền hệ thống, và đó là
            // đánh đổi có ý thức, không phải bug.
            self.background(color)
        }
    }

    /// Vạch kéo của sheet. Dùng cái của hệ thống khi design cần — nó đã đúng vị trí,
    /// đúng màu theo dark mode, và VoiceOver đọc được. Một `Capsule()` tự vẽ thì không.
    func sheetDragIndicator(_ visibility: Visibility = .visible) -> some View {
        presentationDragIndicator(visibility)
    }

    /// `presentationCornerRadius` chỉ có từ **iOS 16.4**. Nhánh cũ giữ nguyên sheet
    /// của hệ thống — mất bo góc tuỳ ý còn hơn mất gesture và accessibility.
    @ViewBuilder
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }
}
