import Foundation
import KVLoggingKit

extension AppBootstrap {

    /// Xoá token cũ ở lần chạy đầu **sau khi cài lại app**.
    ///
    /// Keychain **không** bị xoá khi gỡ app — nó không nằm trong container của app, đó
    /// là hành vi cố ý của iOS (để người dùng cài lại không mất mật khẩu đã lưu). Hệ quả
    /// ở đây: gỡ app, cài lại, mở lên vẫn thấy màn đã đăng nhập với token của lần cài
    /// trước, và không có cách nào quay về màn login ngoài việc bấm đăng xuất.
    ///
    /// Lúc dev thì đó là một câu đố mất thời gian; với người dùng thật thì tệ hơn: token
    /// của tài khoản cũ vẫn sống sau khi họ gỡ app đi vì muốn "xoá sạch".
    ///
    /// `UserDefaults` thì **có** bị xoá cùng app, nên nó là chỗ đúng để đặt cột mốc: cờ
    /// vắng mặt = đây là lần chạy đầu của một lần cài mới.
    /// Tham số có default để chỗ gọi vẫn gọn, nhưng test tiêm được — nếu không thì luật
    /// này chỉ kiểm được bằng cách gỡ app bằng tay, tức là sẽ không ai kiểm.
    @discardableResult
    @MainActor
    static func clearTokensOnFirstLaunch(
        defaults: UserDefaults = .standard,
        tokenStore: any TokenStoring = KeychainTokenStore.shared,
        logger: LogClient = .disabled
    ) -> Bool {
        let key = "app.has-launched-before"
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        tokenStore.clear()
        logger.info("First launch after install — cleared stored tokens", category: "lifecycle")
        return true
    }
}
