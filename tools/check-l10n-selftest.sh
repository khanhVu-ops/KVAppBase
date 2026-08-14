#!/usr/bin/env bash
#
# Chứng minh check-l10n.sh thật sự bắt được vi phạm.
#
# Cùng lý do như check-arch-selftest: một luật im lặng ngừng khớp còn tệ hơn không có
# luật, vì dấu tick xanh lúc đó chứng nhận điều ngược lại. Ở localization thì càng
# đúng — thiếu bản dịch không làm gì cả cho tới khi có người mở app bằng ngôn ngữ đó.

set -uo pipefail
cd "$(dirname "$0")/.."

CATALOG="App/Resources/Localizable.xcstrings"
BASELINE="tools/l10n-baseline.txt"
PROBE_VIEW="DesignSystem/Components/LoadingView.swift"

pass_count=0 fail_count=0
tmp="$(mktemp -d)"
cp "$CATALOG" "$tmp/catalog"
cp "$BASELINE" "$tmp/baseline"
cp "$PROBE_VIEW" "$tmp/view"
restore() {
    cp "$tmp/catalog" "$CATALOG"
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

# mutate_catalog <python body>  — nhận `catalog` là dict, sửa tại chỗ
mutate_catalog() {
    python3 - "$CATALOG" <<PY
import json, sys
path = sys.argv[1]
catalog = json.load(open(path))
$1
json.dump(catalog, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)
PY
}

echo "Kiểm check-l10n.sh có thật sự bắt được vi phạm:"
echo

if ! ./tools/check-l10n.sh >/dev/null 2>&1; then
    echo "Repo đang có vi phạm localization sẵn — sửa trước rồi chạy self-test."
    exit 1
fi

mutate_catalog 'catalog["sourceLanguage"] = "vi"'
check "1 · sourceLanguage không phải en"
cp "$tmp/catalog" "$CATALOG"

mutate_catalog 'for entry in catalog["strings"].values(): entry["localizations"].pop("ja", None)'
check "2 · catalog thiếu một ngôn ngữ"
cp "$tmp/catalog" "$CATALOG"

mutate_catalog 'for entry in catalog["strings"].values(): entry["localizations"]["th"]["stringUnit"]["state"] = "new"'
check "3 · một ngôn ngữ chưa dịch xong"
cp "$tmp/catalog" "$CATALOG"

printf '\n// probe\nprivate struct __ProbeLabel: View { var body: some View { Text("Please wait") } }\n' >> "$PROBE_VIEW"
check "4 · chuỗi user-facing mới không qua catalog"
cp "$tmp/view" "$PROBE_VIEW"

printf 'Một chuỗi không còn ở đâu cả\n' >> "$BASELINE"
check "5 · baseline còn dòng đã chết"
cp "$tmp/baseline" "$BASELINE"

cp Core/AppError.swift "$tmp/apperror"
perl -pi -e 's/return "Your session has expired\."/return "Key nay khong co trong catalog"/' Core/AppError.swift
check "6 · code dùng key không có trong catalog"
cp "$tmp/apperror" Core/AppError.swift

# Cách sai nguy hiểm nhất: compile được, chạy được, chỉ đứng yên ở ngôn ngữ máy.
perl -pi -e 's/return "Your session has expired\."/return String(localized: "Your session has expired.")/' Core/AppError.swift
check "7 · String(localized:) đóng băng text ngoài cầu nối"
cp "$tmp/apperror" Core/AppError.swift

cp Features/Order/OrderList/OrderRows.swift "$tmp/rows"
perl -pi -e 's/Text\(order\.total, format: \.currency\(code: "VND"\)\)/Text(order.total.formatted(.currency(code: "VND")))/' Features/Order/OrderList/OrderRows.swift
check "8 · View dùng .formatted() thay vì Text(value, format:)"
cp "$tmp/rows" Features/Order/OrderList/OrderRows.swift

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
