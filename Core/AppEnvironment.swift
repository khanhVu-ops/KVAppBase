import Foundation

/// Build-time configuration, read from the Info.plist keys that `project.yml`
/// fills in from an xcconfig.
///
/// Reading it here rather than at each call site means a missing key fails once,
/// loudly, at launch — instead of producing a request to `https://` at runtime.
struct AppEnvironment: Sendable {
    let apiBaseURL: String
    let name: String

    /// Serve the app from in-memory fixtures instead of the network.
    ///
    /// A base project nobody can run is a base project nobody reads. Without
    /// this the sign-in screen is a dead end — there is no backend behind
    /// `api-dev.example.com` — and every screen after it is unreachable.
    /// Switch it off in `project.yml` the moment a real API exists.
    let usesStubBackend: Bool

    static let current: AppEnvironment = {
        let bundle = Bundle.main
        let baseURL = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let name = bundle.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String

        // A missing key is a broken build configuration and should stop the app
        // at launch. But a unit-test bundle has no app Info.plist by design, and
        // asserting there turns every test that touches an endpoint into a crash
        // — which is exactly what happened the first time this ran.
        #if DEBUG
        assert(
            baseURL?.isEmpty == false || isRunningTests,
            "API_BASE_URL missing from Info.plist — check the xcconfig for this configuration"
        )
        #endif

        return AppEnvironment(
            apiBaseURL: baseURL ?? "https://api.test.local",
            name: name ?? (isRunningTests ? "test" : "debug"),
            usesStubBackend: bundle.object(forInfoDictionaryKey: "USES_STUB_BACKEND") as? String == "YES"
        )
    }()

    /// Tests run in a host-less bundle, so `Bundle.main` is the test runner.
    static let isRunningTests = NSClassFromString("XCTestCase") != nil

    var isProduction: Bool { name == "production" }
}

// MARK: - Hằng số của app

/// Những giá trị không đến từ build configuration mà từ **danh tính app**: id trên
/// store, email hỗ trợ, các trang pháp lý.
///
/// Kiểu `URL` chứ không phải `String`: một chuỗi sai chính tả chỉ lộ ra khi người dùng
/// bấm vào và không có gì xảy ra, còn ở đây nó không dựng được `URL` là thấy ngay.
extension AppEnvironment {

    /// **ĐỔI khi tạo app mới** — số này lấy trên App Store Connect sau khi tạo app.
    /// Giữ nguyên placeholder thì `appStoreURL`/`shareURL` trỏ vào một trang không tồn
    /// tại, nên `isAppStoreIDConfigured` được dùng để chặn nút "Đánh giá" ở Debug.
    static let appStoreID = "0000000000"

    static var isAppStoreIDConfigured: Bool { appStoreID != "0000000000" }

    static let supportEmail = "support@var-meta.com"

    /// Trang app trên store — dùng để share.
    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// Mở thẳng ô viết đánh giá. `action=write-review` là phần khác biệt duy nhất so
    /// với link store thường, và là thứ khiến nút "Đánh giá" thật sự đưa người dùng
    /// tới chỗ viết được.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    static let privacyPolicyURL = URL(string: "https://sites.google.com/var-meta.com/privacypolicy/home")!
    static let termsOfUseURL = URL(string: "https://sites.google.com/var-meta.com/termofuse2026/home")!

    /// EULA riêng: để `nil` khi app dùng EULA mặc định của Apple. Apple **bắt buộc**
    /// có link EULA trên màn hình bán gói đăng ký — app nào có IAP thì điền vào đây.
    static let eulaURL: URL? = nil
}
