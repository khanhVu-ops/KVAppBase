#!/usr/bin/env bash
#
# Chứng minh check-l10n.sh thật sự bắt được vi phạm.
#
# Cùng lý do như check-arch-selftest: một luật im lặng ngừng khớp còn tệ hơn không có
# luật, vì dấu tick xanh lúc đó chứng nhận điều ngược lại. Ở localization thì càng
# đúng — thiếu bản dịch không làm gì cả cho tới khi có người mở app bằng ngôn ngữ đó.

set -uo pipefail
cd "$(dirname "$0")/.."

SOURCE_STRINGS="App/Resources/en.lproj/Localizable.strings"
JA_STRINGS="App/Resources/ja.lproj/Localizable.strings"
BASELINE="tools/l10n-baseline.txt"
PROBE_VIEW="DesignSystem/Components/LoadingView.swift"

pass_count=0 fail_count=0
tmp="$(mktemp -d)"
cp "$SOURCE_STRINGS" "$tmp/en"
cp "$JA_STRINGS" "$tmp/ja"
cp "$BASELINE" "$tmp/baseline"
cp "$PROBE_VIEW" "$tmp/view"
restore() {
    cp "$tmp/en" "$SOURCE_STRINGS"
    cp "$tmp/ja" "$JA_STRINGS"
    cp "$tmp/baseline" "$BASELINE"
    cp "$tmp/view" "$PROBE_VIEW"
    [ -f "$tmp/apperror" ] && cp "$tmp/apperror" Core/AppError.swift
    [ -f "$tmp/rows" ] && cp "$tmp/rows" Features/Order/OrderList/OrderRows.swift
    [ -f "$tmp/applanguage" ] && cp "$tmp/applanguage" Core/AppLanguage.swift
    rm -rf "$tmp"
}
trap restore EXIT

check() {
    local name="$1"
    if ./tools/check-l10n.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m %s — vi phạm KHÔNG bị bắt\n' "$name"
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    fi
}

echo "Kiểm check-l10n.sh có thật sự bắt được vi phạm:"
echo

if ! ./tools/check-l10n.sh >/dev/null 2>&1; then
    echo "Repo đang có vi phạm localization sẵn — sửa trước rồi chạy self-test."
    exit 1
fi

# 1 · Thiếu dấu `;` — lỗi tệ nhất của .strings: CFBundle bỏ qua CẢ FILE, app rơi về
#     tiếng Anh cho ngôn ngữ đó, không một dòng log.
perl -pi -e 's/;\s*$//' "$JA_STRINGS"
check "1 · .strings sai cú pháp"
cp "$tmp/ja" "$JA_STRINGS"

# 2 · Một ngôn ngữ thiếu key.
perl -ni -e 'print unless /^"Retry"/' "$JA_STRINGS"
check "2 · một ngôn ngữ thiếu key"
cp "$tmp/ja" "$JA_STRINGS"

# 3 · Có key nhưng giá trị rỗng — "đã thêm dòng" không phải "đã dịch".
perl -pi -e 's/^("Retry" = )".*";$/$1"";/' "$JA_STRINGS"
check "3 · giá trị rỗng"
cp "$tmp/ja" "$JA_STRINGS"

# 4 · Chuỗi user-facing mới trong View, không qua bảng dịch.
printf '\n// probe\nprivate struct __ProbeLabel: View { var body: some View { Text("Please wait") } }\n' >> "$PROBE_VIEW"
check "4 · chuỗi user-facing mới không qua bảng dịch"
cp "$tmp/view" "$PROBE_VIEW"

# 5 · Baseline giữ một dòng nợ đã trả.
printf 'Một chuỗi không còn ở đâu cả\n' >> "$BASELINE"
check "5 · baseline còn dòng đã chết"
cp "$tmp/baseline" "$BASELINE"

# 6 · Code dùng key không có trong bảng dịch — app hiện nguyên key, không log gì.
cp Core/AppError.swift "$tmp/apperror"
perl -pi -e 's/return "Your session has expired\."/return "Key nay khong co trong bang dich"/' Core/AppError.swift
check "6 · code dùng key không có trong bảng dịch"
cp "$tmp/apperror" Core/AppError.swift

# 7 · Cách sai nguy hiểm nhất: compile được, chạy được, chỉ đứng yên ở ngôn ngữ máy.
perl -pi -e 's/return "Your session has expired\."/return String(localized: "Your session has expired.")/' Core/AppError.swift
check "7 · String(localized:) đóng băng text ngoài cầu nối"
cp "$tmp/apperror" Core/AppError.swift

# 8 · Format số bằng .formatted() trong View.
cp Features/Order/OrderList/OrderRows.swift "$tmp/rows"
perl -pi -e 's/Text\(order\.total, format: \.currency\(code: "VND"\)\)/Text(order.total.formatted(.currency(code: "VND")))/' Features/Order/OrderList/OrderRows.swift
check "8 · View dùng .formatted() thay vì Text(value, format:)"
cp "$tmp/rows" Features/Order/OrderList/OrderRows.swift

# 9 · Picker thiếu một ngôn ngữ mà app có khai.
cp Core/AppLanguage.swift "$tmp/applanguage"
perl -pi -e 's/^    case thai .*$//' Core/AppLanguage.swift
check "9 · picker thiếu một ngôn ngữ app có khai"
cp "$tmp/applanguage" Core/AppLanguage.swift

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d phép kiểm không bắt được vi phạm.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d phép kiểm đều bắt được vi phạm.\033[0m\n' "$pass_count"
