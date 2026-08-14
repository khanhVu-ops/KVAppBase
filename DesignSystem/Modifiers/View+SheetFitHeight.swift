import SwiftUI

extension View {

    /// Cho sheet cao **vừa đúng content**, thay vì `.medium` để hở một khoảng trống.
    ///
    /// Đặt trên content của sheet, không phải trên view mở sheet:
    ///
    /// ```swift
    /// .sheet(isPresented: $isPresented) {
    ///     LanguagePickerView().sheetFitHeight()
    /// }
    /// ```
    ///
    /// Cách làm: đo chiều cao thật của content rồi đưa vào `.presentationDetents`.
    /// Ba chi tiết khiến bản này khác bản viết vội:
    ///
    /// - Đo bằng `background(GeometryReader)`, **không** bọc content trong
    ///   `GeometryReader`: reader chiếm hết không gian cha cho nên bọc vào là content
    ///   bị kéo giãn, và chiều cao đo được thành chiều cao màn hình.
    /// - Detent luôn có ít nhất một giá trị hợp lệ. `.presentationDetents([])` là crash,
    ///   và lần đo đầu tiên luôn là 0.
    /// - Kẹp trần theo màn hình. Content dài hơn màn hình mà đưa nguyên vào detent thì
    ///   sheet cao quá màn, không kéo xuống được và không đóng được.
    func sheetFitHeight(maxFraction: CGFloat = 0.9) -> some View {
        modifier(SheetFitHeightModifier(maxFraction: maxFraction))
    }
}

private struct SheetFitHeightModifier: ViewModifier {

    let maxFraction: CGFloat

    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    // `Color.clear` chứ không phải EmptyView: EmptyView không có layout
                    // nên proxy không đo được gì.
                    Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SheetHeightKey.self) { height in
                guard height > 0, abs(height - contentHeight) > 1 else { return }
                contentHeight = height
            }
            .presentationDetents(detents)
    }

    private var detents: Set<PresentationDetent> {
        guard contentHeight > 0 else { return [.medium] }
        let screenHeight = UIScreen.main.bounds.height
        return [.height(min(contentHeight, screenHeight * maxFraction))]
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Sheet vừa content") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            VStack(spacing: Spacing.m) {
                Text(verbatim: "Sheet cao đúng bằng content")
                    .font(AppFont.titleM)
                Text(verbatim: "Không thừa một khoảng trống nào bên dưới.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.Text.secondary)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
            .sheetFitHeight()
            .sheetDragIndicator()
        }
}
