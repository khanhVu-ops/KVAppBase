import SwiftUI
import UIKit

/// Rung phản hồi.
///
/// Bản trong các app cũ có một modifier `hapticOnTap` gắn `.onTapGesture` — nó **nuốt
/// cú chạm**: đặt lên `Button` thì rung có mà action không chạy, và vùng chạm của
/// `Button` (đã đúng theo accessibility) bị thay bằng vùng của gesture. Ở đây rung là
/// một lệnh gọi trong action, hoặc đi kèm `ButtonStyle` — không có modifier nào cướp
/// gesture.
enum Haptic {
    case light, medium, heavy, soft, rigid
    case success, warning, error
    case selection

    @MainActor
    func play() {
        switch self {
        case .light:     UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:     UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:     UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:   UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:   UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:     UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

extension View {

    /// Rung khi một giá trị đổi — đúng cho "vừa xong", "vừa lỗi", "vừa chọn xong".
    ///
    /// Đây là chỗ iOS 17 có `.sensoryFeedback`; app này chạy từ 16.0 nên tự làm, cùng
    /// ngữ nghĩa: gắn vào **thay đổi state**, không gắn vào cử chỉ chạm.
    func haptic<V: Equatable>(_ haptic: Haptic, on value: V) -> some View {
        onChange(of: value) { _ in haptic.play() }
    }

    /// Rung khi điều kiện chuyển sang `true`.
    func haptic(_ haptic: Haptic, when condition: Bool) -> some View {
        onChange(of: condition) { isOn in
            guard isOn else { return }
            haptic.play()
        }
    }
}
