#!/usr/bin/env bash
#
# Luật localization: text mới phải dịch đủ mọi ngôn ngữ app khai, ngay lúc thêm.
#
# Vì sao kiểm bằng script chứ không bằng lời nhắc: một string thiếu bản dịch không
# làm gì cả cho tới khi có người mở app bằng ngôn ngữ đó — nó fallback về English,
# im lặng, và không test nào đỏ. Nợ kiểu đó chỉ lộ ra ở tay người dùng.
#
# Bốn phép kiểm:
#   1  catalog tồn tại, JSON hợp lệ, sourceLanguage = en
#   2  catalog khai đủ 19 ngôn ngữ (danh sách dưới đây là nguồn duy nhất — xcodegen
#      suy `knownRegions` từ chính catalog, nên thêm ngôn ngữ ở đây là Xcode thấy)
#   3  mọi string trong catalog đã `translated` ở **tất cả** 19 ngôn ngữ
#   4  ratchet: mọi chuỗi ở vị trí user-facing trong Features/DesignSystem phải là
#      key của catalog, hoặc nằm trong tools/l10n-baseline.txt — và baseline chỉ
#      được co lại, không được nở ra
#
# Phạm vi đã biết là hẹp: phép kiểm 4 chỉ soi chuỗi trong `Text/Button/Label/
# navigationTitle/...`. Text do Core/Domain sinh ra (`AppError.userMessage`, message
# của toast) là user-facing thật nhưng script này chưa soi — dùng `String(localized:)`
# ở đó, và xem skill `ios-l10n`. Nói ra chỗ hẹp còn hơn để dấu tick xanh ngụ ý rộng.

set -uo pipefail
cd "$(dirname "$0")/.."

CATALOG="App/Resources/Localizable.xcstrings"
BASELINE="tools/l10n-baseline.txt"

# 19 ngôn ngữ, đúng danh sách Localizations của project.
LANGUAGES="en ar zh-Hans zh-Hant nl fr de hi id it ja ko pt-BR pt-PT ru es th tr vi"

failures=0
fail() { printf '\033[31m✗\033[0m %s\n' "$1"; shift; [ "$#" -gt 0 ] && printf '    %s\n' "$@"; failures=$((failures + 1)); }
pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. Catalog đọc được.
# ---------------------------------------------------------------------------
if [ ! -f "$CATALOG" ]; then
    fail "không có $CATALOG" "app không khai ngôn ngữ nào thì không có gì để dịch"
    printf '\n\033[31m1 vấn đề.\033[0m\n'
    exit 1
fi
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CATALOG" 2>/dev/null; then
    fail "$CATALOG không phải JSON hợp lệ" "Xcode sẽ từ chối mở, và build im lặng bỏ qua"
    printf '\n\033[31m1 vấn đề.\033[0m\n'
    exit 1
fi
source_language=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('sourceLanguage',''))" "$CATALOG")
if [ "$source_language" != "en" ]; then
    fail "sourceLanguage là '$source_language', phải là 'en'" \
        "key viết bằng English để code đọc được cả khi chưa dịch"
else
    pass "catalog hợp lệ, sourceLanguage = en"
fi

# ---------------------------------------------------------------------------
# 2 + 3. Đủ ngôn ngữ, và mọi string đã dịch hết.
# ---------------------------------------------------------------------------
report=$(LANGUAGES="$LANGUAGES" python3 - "$CATALOG" <<'PY'
import json, os, sys

wanted = os.environ["LANGUAGES"].split()
catalog = json.load(open(sys.argv[1]))
strings = catalog.get("strings", {})

declared = {code for entry in strings.values() for code in entry.get("localizations", {})}
missing_languages = [code for code in wanted if code not in declared]

incomplete = []
for key, entry in sorted(strings.items()):
    locs = entry.get("localizations", {})
    gaps = [
        code for code in wanted
        if locs.get(code, {}).get("stringUnit", {}).get("state") != "translated"
        or not locs.get(code, {}).get("stringUnit", {}).get("value")
    ]
    if gaps:
        incomplete.append(f"{key} → thiếu: {' '.join(gaps)}")

print("STRINGS", len(strings))
print("MISSING_LANGUAGES", " ".join(missing_languages))
for line in incomplete:
    print("INCOMPLETE", line)
PY
)
string_count=$(awk '/^STRINGS /{print $2}' <<< "$report")
missing_languages=$(sed -n 's/^MISSING_LANGUAGES //p' <<< "$report")
incomplete=$(sed -n 's/^INCOMPLETE //p' <<< "$report")

if [ -n "$missing_languages" ]; then
    fail "catalog chưa khai đủ ngôn ngữ" "thiếu: $missing_languages"
else
    pass "catalog khai đủ $(wc -w <<< "$LANGUAGES" | tr -d ' ') ngôn ngữ"
fi

if [ -n "$incomplete" ]; then
    fail "có string chưa dịch đủ" "$incomplete"
elif [ "${string_count:-0}" -eq 0 ]; then
    # Catalog rỗng thì phép kiểm 3 pass rỗng. Nói thẳng ra, đừng để nó đọc như đã kiểm.
    printf '\033[33m–\033[0m catalog chưa có string nào — phép kiểm "dịch đủ" chưa có gì để kiểm\n'
else
    pass "$string_count string, mọi ngôn ngữ đã translated"
fi

# ---------------------------------------------------------------------------
# 4. Ratchet: chuỗi user-facing mới phải đi qua catalog.
# ---------------------------------------------------------------------------
# `verbatim:` được miễn: đó là cách nói tường minh "chuỗi này không dịch" — mã đơn,
# số, tên riêng.
literals=$(grep -rhoE '(Text|Button|Label|navigationTitle|confirmationDialog|alert)\((verbatim: )?"[^"]+"' \
    --include='*.swift' Features DesignSystem \
    | grep -v 'verbatim: ' \
    | sed -E 's/^[A-Za-z]+\("//; s/"$//' | sort -u)

keys=$(python3 -c "import json,sys; print('\n'.join(json.load(open(sys.argv[1])).get('strings',{}).keys()))" "$CATALOG")
[ -f "$BASELINE" ] && baseline=$(grep -v '^#' "$BASELINE" | grep -v '^$') || baseline=""

unlocalized=""
while IFS= read -r literal; do
    [ -n "$literal" ] || continue
    grep -qxF "$literal" <<< "$keys" && continue
    grep -qxF "$literal" <<< "$baseline" && continue
    unlocalized="$unlocalized$literal"$'\n'
done <<< "$literals"

if [ -n "$unlocalized" ]; then
    fail "chuỗi user-facing chưa qua catalog" \
        "$unlocalized" \
        "thêm vào $CATALOG kèm cả $(wc -w <<< "$LANGUAGES" | tr -d ' ') ngôn ngữ, rồi dùng key English trong code"
else
    pass "mọi chuỗi user-facing hoặc là key của catalog, hoặc là nợ đã ghi trong baseline"
fi

# Baseline phải co lại. Một dòng không còn khớp source nào là nợ đã trả mà chưa xoá
# giấy — để đó thì lần sau không ai biết con số thật là bao nhiêu.
stale=""
while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    grep -qxF "$entry" <<< "$literals" || stale="$stale$entry"$'\n'
done <<< "$baseline"
if [ -n "$stale" ]; then
    fail "$BASELINE còn dòng không còn trong source" "$stale" "xoá chúng đi — baseline chỉ được co lại"
else
    baseline_count=$(grep -c . <<< "${baseline:-}" 2>/dev/null || echo 0)
    pass "baseline còn $baseline_count chuỗi nợ, không có dòng chết"
fi

echo
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d vấn đề localization.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mLocalization OK.\033[0m\n'
