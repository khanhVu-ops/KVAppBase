import SwiftUI

/// Tham số của hiệu ứng shimmer. Màu lấy từ token, không hardcode, để nó đúng ở cả
/// light lẫn dark mode.
struct ShimmerConfig: Equatable, Sendable {
    var tint: Color = AppColor.Surface.separator
    var highlight: Color = AppColor.Surface.card
    var angle: Angle = .degrees(20)
    /// Bề rộng dải sáng, tính theo đường chéo của view (0.1 … 0.6 là hợp lý).
    var bandSize: CGFloat = 0.28
    /// Số vòng mỗi giây.
    var speed: Double = 0.9
}

extension View {

    /// Skeleton loading: che content bằng một khối xám có dải sáng chạy qua.
    ///
    /// ```swift
    /// Text("Tên khách hàng").shimmer(active: isLoading)
    /// ```
    ///
    /// Dùng chính content làm mask nên khối xám có đúng hình của thứ sắp hiện ra —
    /// khác với việc vẽ mấy hình chữ nhật xám đoán trước layout, thứ luôn lệch khi nội
    /// dung đổi.
    func shimmer(
        active: Bool = true,
        hidesContent: Bool = true,
        config: ShimmerConfig = ShimmerConfig()
    ) -> some View {
        modifier(ShimmerModifier(active: active, hidesContent: hidesContent, config: config))
    }
}

private struct ShimmerModifier: ViewModifier {

    let active: Bool
    let hidesContent: Bool
    let config: ShimmerConfig

    func body(content: Content) -> some View {
        ZStack {
            // `.hidden()` chứ không phải bỏ hẳn: layout phải giữ nguyên kích thước,
            // nếu không thì màn hình nhảy một nhịp đúng lúc dữ liệu về.
            if hidesContent { content.hidden() } else { content }

            if active {
                Rectangle()
                    .fill(config.tint)
                    .mask(content)

                ShimmerBand(config: config)
                    .mask(content)
                    .blendMode(.plusLighter)
            }
        }
    }
}

private struct ShimmerBand: View {

    let config: ShimmerConfig

    /// Tôn trọng "Reduce Motion": người bật nó thường bật vì chuyển động làm họ chóng
    /// mặt. Vẫn hiện khối skeleton, chỉ là dải sáng đứng yên.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            // Pha tính từ đồng hồ chứ không phải từ một `withAnimation` lặp: animation
            // lặp sẽ trôi pha khi app bận, còn cái này luôn đúng nhịp.
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.5 : (t * config.speed).truncatingRemainder(dividingBy: 1)

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let diagonal = hypot(width, height)
                let band = max(16, diagonal * min(max(config.bandSize, 0.05), 0.9))
                let travel = diagonal + band
                let offset = (phase * 2 - 1) * (travel / 2)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: config.highlight, location: 0.5),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: band, height: travel)
                .rotationEffect(config.angle)
                .offset(
                    x: width / 2 + cos(config.angle.radians) * offset - band / 2,
                    y: height / 2 + sin(config.angle.radians) * offset - travel / 2
                )
                .allowsHitTesting(false)
            }
        }
    }
}

#Preview("Shimmer") {
    VStack(alignment: .leading, spacing: Spacing.m) {
        Text(verbatim: "DH-0001").font(AppFont.bodyStrong)
        Text(verbatim: "Nguyễn Văn A").font(AppFont.body)
        Text(verbatim: "250.000 đ").font(AppFont.body)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Spacing.l)
    .shimmer()
}
