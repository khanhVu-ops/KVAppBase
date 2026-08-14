#!/usr/bin/env bash
#
# Luật localization: text mới phải dịch đủ mọi ngôn ngữ app khai, ngay lúc thêm.
#
# Vì sao kiểm bằng script chứ không bằng lời nhắc: một string thiếu bản dịch không
# làm gì cả cho tới khi có người mở app bằng ngôn ngữ đó — nó fallback về English,
# im lặng, và không test nào đỏ. Nợ kiểu đó chỉ lộ ra ở tay người dùng.
#
# Bảy phép kiểm:
#   1  catalog tồn tại, JSON hợp lệ, sourceLanguage = en
#   2  catalog khai đủ 19 ngôn ngữ (danh sách dưới đây là nguồn duy nhất — xcodegen
#      suy `knownRegions` từ chính catalog, nên thêm ngôn ngữ ở đây là Xcode thấy)
#   3  mọi string trong catalog đã `translated` ở **tất cả** 19 ngôn ngữ
#   4  ratchet: chuỗi user-facing trong Features/DesignSystem phải là key của catalog
#      hoặc nằm trong tools/l10n-baseline.txt — và baseline chỉ được co lại
#   5  mọi key dùng trong code phải có thật trong catalog
#   6  `String(localized:)` chỉ được xuất hiện ở đúng một chỗ (cầu nối toast)
#   7  `AppLanguage` (picker) khớp danh sách ngôn ngữ
#   8  View format số/ngày bằng `Text(value, format:)`, không phải `.formatted()`
#
# Luật 6 và 8 sinh ra từ một phép đo trên simulator (ngôn ngữ máy vi, environment ja):
#
#   Text("key") / Text(LocalizedStringResource)   → đổi theo ngôn ngữ chọn trong app
#   Text(String(localized: "key"))                → KHÔNG
#   String(localized: "key", locale: ja)          → KHÔNG (`locale:` chỉ đổi format)
#   Text(value, format: .currency(...))           → đổi
#   value.formatted(.currency(...))               → KHÔNG
#
# Nên text đi xuyên tầng mang `LocalizedStringResource` và để View resolve. Cả hai
# cách sai đều **compile, chạy, không log gì** — chúng chỉ hiện ra khi người dùng đổi
# ngôn ngữ rồi thấy một nửa màn hình không đổi theo.
#
# Phạm vi còn hẹp: `Data/` không bị soi (đầy literal wire-level), chuỗi ghép động
# `"\(a) \(b)"` thì script không đọc được ý định, và `accessibilityLabel` chưa ai canh.

set -uo pipefail
cd "$(dirname "$0")/.."

CATALOG="App/Resources/Localizable.xcstrings"
BASELINE="tools/l10n-baseline.txt"

# 19 ngôn ngữ, đúng danh sách Localizations của project.
LANGUAGES="en ar zh-Hans zh-Hant nl fr de hi id it ja ko pt-BR pt-PT ru es th tr vi"

failures=0

# grep, nhưng bỏ những dòng mà nội dung bắt đầu bằng comment. Doc comment nhắc một
# cách viết sai làm ví dụ là chuyện bình thường và đáng khuyến khích — ba luật dưới
# đây đều từng đỏ vì chính doc của repo này.
code_grep() {
    grep -rnE "$@" --include='*.swift' 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true
}

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
literals=$(
    {
        code_grep '(Text|Button|Label|navigationTitle|confirmationDialog|alert)\((verbatim: )?"[^"]+"' Features DesignSystem \
            | grep -oE '(Text|Button|Label|navigationTitle|confirmationDialog|alert)\((verbatim: )?"[^"]+"' \
            | grep -v 'verbatim: ' | sed -E 's/^[A-Za-z]+\("//; s/"$//'
        # Copy của alert và toast do ViewModel dựng: cũng là text người dùng đọc, chỉ
        # khác chỗ đứng. `logger.*` thì không — log không phải UI, đừng dịch log.
        code_grep '(title|message):[[:space:]]*"[^"]+"' Features \
            | grep -oE '(title|message):[[:space:]]*"[^"]+"' \
            | sed -E 's/^[a-z]+:[[:space:]]*"//; s/"$//'
        code_grep '\.(success|error|info|warning)\("[^"]+"\)' Features \
            | grep -v 'logger\.' | grep -oE '\.(success|error|info|warning)\("[^"]+"\)' \
            | sed -E 's/^\.[a-z]+\("//; s/"\)$//'
    } | sort -u
)

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

# ---------------------------------------------------------------------------
# 5. Key của String(localized:) phải có thật trong catalog.
#    Đây là lỗi im lặng nhất trong cả file này: gõ sai key hay quên thêm vào
#    catalog thì app hiện đúng chữ English của key, không crash, không log.
# ---------------------------------------------------------------------------
orphans=""
while IFS= read -r key; do
    [ -n "$key" ] || continue
    grep -qxF "$key" <<< "$keys" && continue
    grep -qxF "$key" <<< "$baseline" && continue
    orphans="$orphans$key"$'\n'
done < <(
    {
        # Literal của `LocalizedStringResource` ở Core/Domain: `return "..."` giờ LÀ key.
        # Lọc comment TRƯỚC khi bóc literal: chính doc của file này có bảng nhắc
        # `String(localized: "key")` như một ví dụ sai, và nó từng làm luật đỏ.
        grep -rnE 'return "[^"]+"' --include='*.swift' Core Domain \
            | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' \
            | grep -oE 'return "[^"]+"' | sed -E 's/^return "//; s/"$//'
        grep -rnE 'String\(localized: "[^"]+"' --include='*.swift' \
            Core Domain Data DI DesignSystem Features App \
            | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' \
            | grep -oE 'String\(localized: "[^"]+"' | sed -E 's/^String\(localized: "//; s/"$//'
    } | grep -vE '^\\\(|^$' | sort -u
)
if [ -n "$orphans" ]; then
    fail "code dùng key không có trong catalog" "$orphans" \
        "app sẽ hiện nguyên key — không crash, không log, nên chỉ người dùng thấy"
else
    pass "mọi key dùng trong code đều có trong catalog"
fi

# ---------------------------------------------------------------------------
# 7. Danh sách ngôn ngữ trong picker phải khớp danh sách app khai.
#    Một ngôn ngữ có trong `AppLanguage` mà không có bản dịch = người dùng chọn xong
#    rồi thấy toàn tiếng Anh; ngược lại = dịch xong mà không ai chọn được.
# ---------------------------------------------------------------------------
declared_cases=$(grep -oE 'case [a-zA-Z]+ *= *"[^"]+"' Core/AppLanguage.swift \
    | sed -E 's/.*= *"//; s/"$//' | sort -u)
wanted=$(tr ' ' '\n' <<< "$LANGUAGES" | sort -u)
missing_in_picker=$(comm -23 <(echo "$wanted") <(echo "$declared_cases"))
extra_in_picker=$(comm -13 <(echo "$wanted") <(echo "$declared_cases"))
if [ -n "$missing_in_picker" ] || [ -n "$extra_in_picker" ]; then
    message=""
    [ -n "$missing_in_picker" ] && message="$message"$'app khai nhưng picker không có: '"$(echo "$missing_in_picker" | tr '\n' ' ')"$'\n'
    [ -n "$extra_in_picker" ] && message="$message"$'picker có nhưng app không khai: '"$(echo "$extra_in_picker" | tr '\n' ' ')"
    fail "AppLanguage lệch danh sách ngôn ngữ" "$message"
else
    pass "AppLanguage khớp đúng danh sách ngôn ngữ"
fi

# ---------------------------------------------------------------------------
# 8. Trong View: format số/ngày bằng `Text(value, format:)`, không phải `.formatted()`.
#    `.formatted()` dựng chuỗi ngay lúc gọi bằng `Locale.current` = ngôn ngữ của MÁY,
#    nên nó không đổi khi người dùng đổi ngôn ngữ trong app. Đã thấy tận mắt: cùng một
#    đơn hàng, list (`Text(value, format:)`) hiện `đ250,000` sau khi đổi sang tiếng
#    Nhật, còn màn chi tiết (`.formatted()`) vẫn `250.000 đ`.
# ---------------------------------------------------------------------------
formatted_hits=$(grep -rn '\.formatted(' --include='*.swift' Features DesignSystem \
    | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true)
if [ -n "$formatted_hits" ]; then
    fail "View dùng .formatted() thay vì Text(value, format:)" "$formatted_hits" \
        "chuỗi dựng bằng .formatted() giữ nguyên ngôn ngữ của máy sau khi đổi ngôn ngữ trong app"
else
    pass "View format số/ngày qua Text(value, format:)"
fi

# ---------------------------------------------------------------------------
# 6. `String(localized:)` chỉ được xuất hiện ở đúng một chỗ.
#    Nó resolve **ngay lúc gọi** theo `Locale.current` = ngôn ngữ của MÁY, nên mọi
#    text đi qua nó đóng băng ở ngôn ngữ hệ thống và không đổi khi người dùng đổi
#    ngôn ngữ trong app. Text xuyên tầng phải mang `LocalizedStringResource` để View
#    resolve; chỗ duy nhất buộc phải ra `String` là cầu nối toast trong
#    `Core/LanguageStore.swift`, và nó tra bundle `.lproj` chứ không dùng API này.
# ---------------------------------------------------------------------------
frozen=$(grep -rn 'String(localized:' --include='*.swift' \
    Core Domain Data DI DesignSystem Features App \
    | grep -v '^Core/LanguageStore.swift' \
    | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true)
if [ -n "$frozen" ]; then
    fail "String(localized:) ngoài cầu nối được phép" "$frozen" \
        "text sẽ đứng yên ở ngôn ngữ máy — dùng LocalizedStringResource và để View resolve"
else
    pass "không có text nào bị đóng băng bằng String(localized:)"
fi

echo
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d vấn đề localization.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mLocalization OK.\033[0m\n'
