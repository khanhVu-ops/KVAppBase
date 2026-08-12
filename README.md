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

Hoặc kiểm tất cả bằng một lệnh:

```bash
./tools/verify.sh          # luật kiến trúc → build module → test → build app
```

## Có gì trong này

Một vertical slice đầy đủ, đã build và test được:

- **`FeatureOrder`** — list (search, pull-to-refresh, empty, error, offline) và
  detail (seed từ list hoặc fetch theo id, huỷ đơn có xác nhận).
- **`FeatureAuth`** — sign-in với validate ở use case, `DebouncedField`.
- 19 test qua ba tầng: Domain thuần, Data qua `KVMockNetworkSession`, ViewModel
  qua `KVRouterSpy`.

## Kiến trúc

```
AppFoundation   Foundation only            Loadable · AlertState · AppError · AppEnvironment
Domain          → AppFoundation            Entities · Repository protocols · UseCases · ports
Data            → Domain + KVNetworkit     DTO · Endpoints · Repository impls · mapping
AppDI           → Domain + Data + KVDIKit  mọi dependency key, và nơi duy nhất
DesignSystem    → AppFoundation + KVToast  token (asset catalog) · component · toast style
Feature*        → Domain + DesignSystem + AppDI + KVRouter{Core,Kit}
App             → tất cả                   composition root
```

Graph trong `Packages/AppModules/Package.swift` **là** kiến trúc: một tầng không
import được cái mà target của nó không depend, nên sai là build error. Những luật
compiler không diễn đạt được thì `tools/check-arch.sh` kiểm, và CI fail nếu vi
phạm.

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
xcodegen generate            # sau khi thêm/di chuyển file trong App/
./tools/check-arch.sh        # luật phân tầng
./tools/verify.sh            # tất cả
```

Đừng sửa `MyApp.xcodeproj` bằng tay — nó được sinh ra và đã gitignore.
