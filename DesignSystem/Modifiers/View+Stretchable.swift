import SwiftUI

extension View {

    /// Header giãn ra khi kéo `ScrollView` xuống quá đầu.
    ///
    /// ```swift
    /// ScrollView {
    ///     Image("banner").resizable().scaledToFill()
    ///         .stretchableHeader(height: 220)
    ///     ...
    /// }
    /// .coordinateSpace(name: StretchableHeader.space)   // BẮT BUỘC
    /// ```
    ///
    /// Vì sao bản này khác bản hay gặp: phần lớn cách viết đo offset bằng
    /// `frame(in: .global)`. Trên iOS 16 nó sai ở đúng những chỗ người ta hay đặt
    /// header — dưới navigation bar, trong sheet, hoặc khi safe area đổi lúc xoay máy —
    /// vì `.global` bao gồm cả phần chrome đó, nên header đã bị giãn sẵn ngay khi mở
    /// màn, hoặc nhảy một nấc lúc bar ẩn/hiện. Đo trong **coordinate space có tên** của
    /// chính scroll view thì offset bắt đầu từ 0 bất kể trên nó là gì.
    ///
    /// Hai chỗ nữa dễ sai và đã xử ở đây: `scaleEffect` phải neo `.bottom` (không thì
    /// ảnh giãn cả hai đầu và mép trên hở ra), và chiều cao phải cộng thêm phần kéo
    /// **trước khi** `clipped()` — đổi thứ tự thì phần giãn bị cắt mất, tức là không
    /// giãn gì cả.
    func stretchableHeader(height: CGFloat) -> some View {
        modifier(StretchableHeaderModifier(height: height))
    }
}

enum StretchableHeader {
    /// Tên coordinate space mà `stretchableHeader` đo trong đó. Đặt lên `ScrollView`.
    static let space = "kvStretchableHeaderSpace"
}

private struct StretchableHeaderModifier: ViewModifier {

    let height: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            // > 0 khi người dùng kéo xuống quá đầu; <= 0 khi cuộn lên (không giãn,
            // header chỉ trôi đi như nội dung bình thường).
            let stretch = max(0, proxy.frame(in: .named(StretchableHeader.space)).minY)

            content
                .frame(width: proxy.size.width, height: height + stretch)
                .scaleEffect(1, anchor: .bottom)
                .offset(y: -stretch)
                .clipped()
        }
        .frame(height: height)
    }
}

#Preview("Stretchable header") {
    ScrollView {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColor.Brand.primary, AppColor.Semantic.info],
                startPoint: .top,
                endPoint: .bottom
            )
            .stretchableHeader(height: 220)

            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(0..<12, id: \.self) { index in
                    Text(verbatim: "Hàng \(index + 1)")
                        .font(AppFont.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Spacing.m)
        }
    }
    .coordinateSpace(name: StretchableHeader.space)
    .ignoresSafeArea(edges: .top)
}
