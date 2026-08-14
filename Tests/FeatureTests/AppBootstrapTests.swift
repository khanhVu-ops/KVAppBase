import XCTest
@testable import MyApp

/// Keychain sống sót qua việc gỡ app, nên nếu không ai xoá thì bản cài mới mở lên đã
/// đăng nhập sẵn bằng token của lần cài trước — không có đường nào về màn login.
@MainActor
final class AppBootstrapTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // Suite riêng cho từng test: dùng `.standard` là hai test giẫm lên nhau, và
        // test thứ hai thấy cờ của test thứ nhất rồi pass vì lý do sai.
        suiteName = "test.bootstrap.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testClearsTokensOnFirstLaunchAfterInstall() {
        let store = InMemoryTokenStore()
        store.save(access: "từ lần cài trước", refresh: "refresh cũ")

        let didClear = AppBootstrap.clearTokensOnFirstLaunch(defaults: defaults, tokenStore: store)

        XCTAssertTrue(didClear)
        XCTAssertNil(store.accessToken, "token của lần cài trước phải bị xoá")
        XCTAssertNil(store.refreshToken)
    }

    func testDoesNotClearOnEveryLaunch() {
        let store = InMemoryTokenStore()
        AppBootstrap.clearTokensOnFirstLaunch(defaults: defaults, tokenStore: store)

        // Người dùng đăng nhập ở lần chạy đầu…
        store.save(access: "phiên đang dùng", refresh: "refresh")
        // …rồi mở lại app. Xoá lần nữa là đá họ ra khỏi phiên mỗi lần mở app.
        let didClear = AppBootstrap.clearTokensOnFirstLaunch(defaults: defaults, tokenStore: store)

        XCTAssertFalse(didClear)
        XCTAssertEqual(store.accessToken, "phiên đang dùng")
    }
}
