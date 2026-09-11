# KVAppBase

Base project SwiftUI cho iOS 16+, Swift 6: MVVM + Clean Architecture trên 5
package nội bộ (KVRouterKit, KVDIKit, KVNetworkit, KVToastKit, KVLoggingKit).

<!-- template-only:start -->
Đây là **template**. Để tạo app mới, dùng [KVAppKit](https://github.com/khanhVu-ops/KVAppKit)
— nó kéo repo này theo version đã pin rồi đổi danh tính app.

Hai dòng marker quanh đoạn này không phải trang trí: `init-base.sh` cắt đúng khối
giữa chúng khi copy README sang repo app mới, để repo đó không tự giới thiệu mình
là template. Đừng xoá marker.
<!-- template-only:end -->

## Chạy thử

```bash
xcodegen generate
open MyApp.xcodeproj
```

`xcodegen generate` phải chạy lại sau khi thêm hoặc di chuyển **bất kỳ** file
nào — đây là một app target, nên không có SPM tự phát hiện file mới.

Hoặc kiểm tất cả bằng một lệnh:

```bash
./tools/verify.sh          # luật kiến trúc → build module → test → build app
```

## Có gì trong này

Một vertical slice đầy đủ, đã build và test được:

- **`Features/Order`** — list (search, pull-to-refresh, empty, error, offline) và
  detail (seed từ list hoặc fetch theo id, huỷ đơn có xác nhận).
- **`Features/Auth`** — sign-in với validate ở use case, `DebouncedField`.
- **`DesignSystem/Modifiers`** + **`Components`** — modifier và view dùng chung:
  `onFirstAppear`, `alert(_:onDismiss:)`, `cardStyle`, `dismissKeyboardOnTap`,
  `LoadableContent`, `PrimaryButtonStyle`.
- 19 test qua ba tầng: Domain thuần, Data qua `KVMockNetworkSession`, ViewModel
  qua `KVRouterSpy`.

## Kiến trúc

```
Core/           Loadable · AlertState · AppError · AppEnvironment
Domain/         Entities · Repository protocol · Services (port) · UseCase
Data/           DTO · Network/{Endpoints,Interceptors} · Mapping · Local · Repositories · Testing
DI/             mọi KVDependencyKey, và nơi duy nhất
DesignSystem/   Foundation (token) · Components · Modifiers · Toast · Resources/Tokens.xcassets
Features/       Auth/ · Order/          một folder là một luồng, không phải một màn
                mỗi feature có <Name>Route.swift ở gốc folder của nó
App/            entry · Navigation · Bootstrap · Session · Resources
Tests/          DomainTests · DataTests · FeatureTests
```

Một app target, phân tầng bằng folder. Hướng phụ thuộc chạy Core → Domain → Data
→ DI → DesignSystem → Features → App, không có mũi tên nào quay lại.

Vì tất cả nằm trong một module, **compiler không chặn** vi phạm phân tầng: file
cùng module thấy nhau không cần `import`. `tools/check-arch.sh` là thứ thay thế,
và nó suy luật từ chính source — đọc tên type khai báo dưới `Data/` rồi tìm chúng
ở nơi không được biết, nên không cần danh sách bảo trì tay.

`tools/check-arch-selftest.sh` chứng minh 12 luật đó **vẫn bắt được vi phạm**: nó
tạo một vi phạm thật cho từng luật rồi kiểm tra script có fail. Một luật im lặng
ngừng khớp còn tệ hơn không có luật.

## Bốn luật

1. `Domain` chỉ import Foundation.
2. `KVAPIClientError` không bao giờ ra khỏi `Data` — map sang `AppError` ở
   repository.
3. Feature không import `Data`.
4. View con nhận value, không nhận ViewModel. Trên iOS 16 `ObservableObject`
   invalidate theo object, nên đây là luật hiệu năng chứ không phải thẩm mỹ.

## State và navigation

Một `State` struct + một `enum Action` + `send(_:)` là cửa duy nhất để state đổi.
Alert là state, không phải effect. ViewModel đẩy **route** qua `any KVRouting`;
View đẩy **view** bằng `router.pushView { }` khi đã có object trong tay.

Chi tiết và lý do: xem skill `ios-architecture` trong KVAppKit.

## iOS 17

Đổi `ObservableObject` → `@Observable` là diff theo file, không đụng kiến trúc —
xem `ios-architecture/references/ios16.md`.

## Lệnh

```bash
xcodegen generate                  # sau khi thêm/di chuyển BẤT KỲ file nào
./tools/check-arch.sh              # 12 luật phân tầng
./tools/check-arch-selftest.sh     # chứng minh 12 luật đó còn hiệu lực
./tools/check-l10n.sh              # text mới đã dịch đủ 19 ngôn ngữ chưa
./tools/verify.sh                  # tất cả + build + test
```

## CI/CD

Hai workflow, chạy trên self-hosted macOS runner (nhãn `varmeta`) — máy có sẵn Xcode,
simulator và **chứng chỉ ký**. Chứng chỉ không rời máy đó; GitHub chỉ trigger.

| Workflow | Khi nào | Làm gì |
|---|---|---|
| `.github/workflows/verify.yml` | push `main`, mọi PR | `./tools/verify.sh` — luật kiến trúc → self-test → localization → build → test |
| `.github/workflows/release.yml` | bấm tay (Actions → Run workflow) | `fastlane ios <lane>` |

```bash
fastlane ios build_only   # build .ipa đã ký, không upload
fastlane ios beta         # TestFlight
fastlane ios web_test     # ad-hoc → App Distribution nội bộ (var-meta)
fastlane ios release      # App Store, không tự submit review
```

Khác các app CocoaPods của team ở ba điểm, đều vì repo này là một target + XcodeGen:
mọi lane `xcodegen generate` trước (`.xcodeproj` gitignore, checkout của CI không có
nó), `build_app` nhận `project:` chứ không phải `workspace:`, và version đọc từ
`project.yml` — `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` là **nguồn duy nhất**,
`Info.plist` chỉ tham chiếu chúng. fastlane không tự tăng version: sửa `project.yml`
rồi commit, để số trên TestFlight luôn truy ngược được về một commit.

Secret nằm ngoài repo, workflow copy vào lúc build rồi xoá (kể cả khi build đỏ):
`~/secrets/fastlane/asc-api-key.json` (dùng chung mọi app) và
`~/secrets/fastlane/signing.properties` (riêng app này, trỏ tới `.p12` + profile).
Cả hai đã nằm trong `.gitignore`. Trước lane `web_test` đầu tiên phải đặt `DIST_CODE`
trong `fastlane/Fastfile` — nó fail sớm nếu bạn quên.

## Localization

App khai **19 ngôn ngữ**: en (source) · ar · zh-Hans · zh-Hant · nl · fr · de · hi ·
id · it · ja · ko · pt-BR · pt-PT · ru · es · th · tr · vi.

Bảng dịch là **19 file `.strings`**, mỗi ngôn ngữ một thư mục:
`App/Resources/<lang>.lproj/Localizable.strings`. Không dùng String Catalog — file phẳng
thì diff/merge đọc được, hệ dịch thuê ngoài nào cũng nhận, và Xcode không tự ghi vào nó
(catalog thì bị compiler bóc chuỗi vào rồi đóng dấu `stale` lên đúng những key đang dùng
nhiều nhất). Đánh đổi: không có cột State, và plural cần `.stringsdict` riêng.

XcodeGen suy `knownRegions` từ chính các thư mục `.lproj`, nên thêm một ngôn ngữ là tạo
thêm một thư mục — không có chỗ thứ hai để lệch.

Luật: **text mới phải dịch đủ 19 ngôn ngữ ngay lúc thêm.** `tools/check-l10n.sh` bắt
chuỗi user-facing không đi qua catalog và chuỗi thiếu bản dịch; nợ có sẵn của template
nằm trong `tools/l10n-baseline.txt` và danh sách đó **chỉ được co lại**. Cách thêm một
string, và vì sao text xuyên tầng phải mang `LocalizedStringResource`: xem skill
`ios-l10n`.

`tools/xcodegen-if-needed.sh` lo giúp trường hợp hay quên nhất: `.claude/settings.json`
gọi nó như `PostToolUse` hook, và nó `xcodegen generate` khi có file `.swift` **mới**,
im lặng khi chỉ là một lần sửa. Di chuyển hay xoá file thì vẫn phải tự chạy.

Đừng sửa `MyApp.xcodeproj` bằng tay — nó được sinh ra và đã gitignore.
