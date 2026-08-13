# KVAppBase — Claude Code

Đây là **template**, không phải một app. Mọi thứ sửa ở đây sẽ được nhân ra mọi
project tạo sau đó, nên một chỗ sai ở đây đắt hơn một chỗ sai trong app thật.

Rule đầy đủ và toàn bộ skill nằm ở **KVAppKit**, không ở đây (`AGENTS.md` +
`.claude/skills/` của kit). App tạo từ template mang kit đi theo; bản thân template
thì không. Kit thường được clone cạnh repo này — `../KVAppKit` — nên khi làm việc
trong repo này, đọc file tương ứng trong kit trước khi viết Swift:

| Việc | Đọc |
|---|---|
| Tạo/sửa bất kỳ file Swift nào | `../KVAppKit/.claude/skills/ios-architecture/` |
| Chạm bất kỳ symbol `KV*` | `../KVAppKit/.claude/skills/kv-packages/` |
| Nói là đã xong | `../KVAppKit/.claude/skills/ios-verify/` |

Không thấy kit ở đó thì hỏi đường dẫn, đừng đoán luật từ trí nhớ.

## Bốn luật

1. `Domain` chỉ import Foundation.
2. `KVAPIClientError` không ra khỏi `Data` — map sang `AppError` ở repository.
3. Feature không import `Data`.
4. View con nhận value, không nhận ViewModel (luật hiệu năng iOS 16).

## Trước khi nói xong

```bash
./tools/verify.sh
```

10 luật → 11 self-test → xcodegen → build + test.

File `.swift` **mới** thì hook `PostToolUse` trong `.claude/settings.json` đã
`xcodegen generate` giúp (qua `tools/xcodegen-if-needed.sh`). **Di chuyển hoặc xoá**
file thì vẫn phải tự chạy — một app target không tự phát hiện, và triệu chứng là
"code có đó mà compiler bảo không tìm thấy".

Sửa `check-arch.sh` thì chạy `check-arch-selftest.sh`. Một luật im lặng ngừng
khớp còn tệ hơn không có luật, vì dấu tick xanh lúc đó chứng nhận điều ngược lại.

Đừng sửa `MyApp.xcodeproj` bằng tay — nó được sinh ra và đã gitignore.

## Riêng cho template

- README.md có khối `<!-- template-only -->`; `init-base.sh` của kit cắt đúng khối
  đó khi copy sang repo app. Giữ marker.
- Đổi tên hoặc thêm folder tầng ở root thì phải cập nhật README (luật 10 kiểm),
  và cân nhắc rule/skill nào trong kit đang mô tả cây này.
- `USES_STUB_BACKEND: YES` chỉ đúng cho Debug của template, để nó chạy được ngay
  khi chưa có backend.
