import SwiftUI

extension View {

    /// Tấm dán đáy màn — `.sheet` của hệ thống, cao vừa đúng nội dung, có nền.
    ///
    /// ### Vì sao là `.sheet` chứ không phải một `overlay` tự dựng
    ///
    /// `overlay { scrim + content }` *trông* đúng và thiếu hết những thứ UIKit làm
    /// sẵn cho một tấm dán đáy: gạt xuống để đóng, đà quán tính khi gạt, bàn phím
    /// đẩy sheet lên, VoiceOver coi phần dưới sheet là không chạm được, và
    /// `Reduce Motion`. Dựng lại từng cái đó là dựng lại
    /// `UISheetPresentationController` — và không ai dựng lại hết, nên cái thiếu
    /// sẽ là accessibility, thứ không lộ ra khi bấm thử.
    ///
    /// Ba lý do người ta thường viện ra để né `.sheet`, và lời giải có sẵn ở đây:
    ///
    /// | Lý do | Lời giải |
    /// |---|---|
    /// | "`.sheet` chiếm cả màn trên iOS 16" | `sheetFitHeight()` đo nội dung rồi đưa vào `presentationDetents` |
    /// | "design vẽ vạch kéo riêng" | `sheetDragIndicator()` — vạch hệ thống đã đúng vị trí, đúng dark mode, VoiceOver đọc được |
    /// | "cần lớp mờ phía sau" | hệ thống tự vẽ |
    ///
    /// Sheet vẫn là **state**: `isPresented` đọc từ `state` của ViewModel, nên nó
    /// sống sót qua rebuild và test đọc được mà không cần SwiftUI.
    ///
    /// ### Hai presentation trên cùng một view thì một cái biến mất
    ///
    /// Trên iOS 16, hai `.sheet` (hay `.sheet` + `.photosPicker`) gắn trên **cùng**
    /// một view thì cái gắn sau ăn cái trước, và cái kia không bao giờ hiện — im
    /// lặng, không log. Tách ra hai view khác nhau.
    ///
    /// Và đừng đợi `onDismiss` để mở cái thứ hai: `onDismiss` **không** chạy khi
    /// sheet đóng vì state tự đặt về `nil`.
    ///
    /// - Parameter onDismiss: người dùng tự đóng (gạt xuống, chạm ra ngoài) ⇒ dọn
    ///   state. **Không** gọi khi state tự đặt về `nil`.
    func bottomSheet<Content: View>(
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        background: Color = AppColor.Surface.card,
        cornerRadius: CGFloat = Radius.l,
        dragIndicator: Visibility = .visible,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(
            isPresented: Binding(
                get: { isPresented },
                set: { if !$0 { onDismiss() } }
            )
        ) {
            content()
                // `fixedSize` **trước** `sheetFitHeight`, và nó không phải tuỳ chọn.
                //
                // Chiều cao sheet suy ra từ chiều cao nội dung, nên hai thứ đó là một
                // vòng: SwiftUI đề nghị chiều cao detent hiện tại, nội dung co vào cho
                // vừa, phép đo trả về con số đã co, detent chốt ở đó. Vòng này *đứng
                // yên ở chỗ sai* — một câu mô tả hai dòng bị cắt còn một dòng và ở lại
                // như vậy.
                //
                // `fixedSize(horizontal: false, vertical: true)` bắt nội dung báo chiều
                // cao **nó muốn**, không phải chiều cao được đề nghị, nên phép đo đúng.
                .fixedSize(horizontal: false, vertical: true)
                .sheetFitHeight()
                .sheetDragIndicator(dragIndicator)
                .sheetCornerRadius(cornerRadius)
                // Nền của **cả tấm sheet**, không chỉ của content.
                //
                // Detent cao bằng nội dung, nhưng tấm sheet còn dải safe area dưới
                // (home indicator) mà nội dung không với tới. Không đặt cái này thì dải
                // đó là màu mặc định của hệ thống, và nó lộ ra thành một vệt khác màu
                // dưới đáy — nhìn như card bị hụt.
                .sheetBackground(background)
        }
    }
}

#Preview("Bottom sheet") {
    AppColor.Surface.background
        .ignoresSafeArea()
        .bottomSheet(isPresented: true, onDismiss: {}) {
            VStack(spacing: Spacing.m) {
                Text(verbatim: "Tấm dán đáy")
                    .font(AppFont.titleM)
                Text(verbatim: "Cao vừa nội dung, có nền presentation, gạt xuống đóng được.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
        }
}
