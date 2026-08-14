import SwiftUI
import Kingfisher

/// Ảnh từ URL.
///
/// **Không dùng `AsyncImage`.** Nó không cache xuống đĩa, nên cuộn list là tải lại từ
/// đầu mỗi lần cell quay lại; nó cũng không downsample, nên một ảnh 4000×3000 nằm
/// nguyên trong RAM để vẽ ra một ô 60pt. Kingfisher lo cả hai.
///
/// `downsampleTo` là tham số **quan trọng nhất** ở đây: ảnh thumbnail phải giải mã ở
/// đúng kích thước sẽ hiển thị. Một list 20 dòng ảnh gốc là vài trăm MB RAM và vài giây
/// giật; cùng list đó với downsampling là vài MB. Truyền kích thước ô (point), không
/// phải kích thước ảnh.
struct RemoteImage<Placeholder: View>: View {

    private let url: URL?
    private let downsampleTo: CGSize?
    private let contentMode: SwiftUI.ContentMode
    private let cornerRadius: CGFloat
    private let placeholder: Placeholder

    init(
        url: URL?,
        downsampleTo: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        cornerRadius: CGFloat = 0,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.downsampleTo = downsampleTo
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let url {
                image(for: url)
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Vùng chạm là cả khung, kể cả phần trong suốt của ảnh — thiếu nó thì ảnh nằm
        // trong Button chỉ bấm được ở chỗ có pixel.
        .contentShape(Rectangle())
    }

    private func image(for url: URL) -> some View {
        var view = KFImage(url)
            .placeholder { placeholder }
            .onFailureView {
                // Hỏng thì nói là hỏng. Để trống một ô xám thì người dùng tưởng đang
                // tải mãi không xong.
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.Text.disabled)
            }

        if let downsampleTo {
            view = view.setProcessor(DownsamplingImageProcessor(size: downsampleTo))
        }

        return view
            // Nhân theo scale màn: thiếu dòng này thì ảnh downsample ra đúng số point
            // và trông mờ trên màn Retina.
            .scaleFactor(UIScreen.main.scale)
            // Giải mã ở background: giải mã trên main là nguồn tụt frame khi cuộn.
            .backgroundDecode()
            .fade(duration: 0.15)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}

extension RemoteImage where Placeholder == AnyView {

    /// Placeholder mặc định: khối shimmer đúng khung ảnh.
    init(
        url: URL?,
        downsampleTo: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        cornerRadius: CGFloat = 0
    ) {
        self.init(
            url: url,
            downsampleTo: downsampleTo,
            contentMode: contentMode,
            cornerRadius: cornerRadius,
            placeholder: {
                AnyView(
                    Rectangle()
                        .fill(AppColor.Surface.card)
                        .shimmer(hidesContent: false)
                )
            }
        )
    }
}

#Preview("Thumbnail 56pt") {
    HStack(spacing: Spacing.m) {
        RemoteImage(
            url: URL(string: "https://picsum.photos/1200/1200"),
            downsampleTo: CGSize(width: 56, height: 56),
            cornerRadius: 12
        )
        .frame(width: 56, height: 56)

        VStack(alignment: .leading) {
            Text(verbatim: "Ảnh gốc 1200×1200").font(AppFont.bodyStrong)
            Text(verbatim: "giải mã ở 56pt").font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        Spacer()
    }
    .padding(Spacing.m)
}

#Preview("URL rỗng → placeholder") {
    RemoteImage(url: nil, cornerRadius: 16)
        .frame(height: 180)
        .padding(Spacing.m)
}
