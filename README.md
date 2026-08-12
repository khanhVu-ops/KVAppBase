# KVAppBase

Base project SwiftUI cho iOS 16+, Swift 6: MVVM + Clean Architecture trên 5
package nội bộ (KVRouterKit, KVDIKit, KVNetworkit, KVToastKit, KVLoggingKit).

Đây là **template**. Để tạo app mới, dùng [KVAppKit](https://github.com/khanhVu-ops/KVAppKit)
— nó kéo repo này theo version đã pin rồi đổi danh tính app.

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
Data/           DTO · Endpoint · Interceptor · Mapping · Local · Repository impl · Testing
DI/             mọi KVDependencyKey, và nơi duy nhất
DesignSystem/   Foundation (token) · Components · Modifiers · Toast
Features/       Auth/ · Order/          một folder là một luồng, không phải một màn
App/            entry · Navigation · Bootstrap · Session · Resources
Tests/          DomainTests · DataTests · FeatureTests
```

Một app target, phân tầng bằng folder. Hướng phụ thuộc chạy Core → Domain → Data
→ DI → DesignSystem → Features → App, không có mũi tên nào quay lại.

Vì tất cả nằm trong một module, **compiler không chặn** vi phạm phân tầng: file
cùng module thấy nhau không cần `import`. `tools/check-arch.sh` là thứ thay thế,
và nó suy luật từ chính source — đọc tên type khai báo dưới `Data/` rồi tìm chúng
ở nơi không được biết, nên không cần danh sách bảo trì tay.

`tools/check-arch-selftest.sh` chứng minh 8 luật đó **vẫn bắt được vi phạm**: nó
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
./tools/check-arch.sh              # 8 luật phân tầng
./tools/check-arch-selftest.sh     # chứng minh 8 luật đó còn hiệu lực
./tools/verify.sh                  # tất cả + build + test
```

Đừng sửa `MyApp.xcodeproj` bằng tay — nó được sinh ra và đã gitignore.
