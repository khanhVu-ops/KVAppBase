#!/usr/bin/env bash
#
# Luật localization: text mới phải dịch đủ mọi ngôn ngữ app khai, ngay lúc thêm.
#
# Vì sao kiểm bằng script chứ không bằng lời nhắc: một string thiếu bản dịch không
# làm gì cả cho tới khi có người mở app bằng ngôn ngữ đó — nó fallback về English,
# im lặng, và không test nào đỏ. Nợ kiểu đó chỉ lộ ra ở tay người dùng.
#
# Nguồn là **một file `.strings` cho mỗi ngôn ngữ**, không phải String Catalog. Lý do:
# file phẳng nên diff và merge đọc được, mọi hệ dịch thuê ngoài đều nhận `.strings`, và
# Xcode không tự viết vào nó — catalog thì bị compiler bóc chuỗi vào lúc build rồi đóng
# dấu "stale" lên chính những key đang được dùng nhiều nhất.
#
# Hai thứ mất đi, nói ra để không ai tưởng script canh hộ:
#   · `.strings` không có cột State, nên không phân biệt được "đã dịch" và "điền tạm
#     bằng tiếng Anh". Script chỉ đảm bảo đủ key, đủ ngôn ngữ, không giá trị rỗng.
#   · Plural cần `.stringsdict` riêng (xem skill `ios-l10n`).
#
# Bảy phép kiểm:
#   1  file nguồn en.lproj/Localizable.strings tồn tại và đúng cú pháp
#   2  đủ 19 ngôn ngữ, cùng một bộ key, không giá trị rỗng
#   3  ratchet: chuỗi user-facing trong Features/DesignSystem phải là key có thật,
#      hoặc nằm trong tools/l10n-baseline.txt — và baseline chỉ được co lại
#   4  mọi key dùng trong code phải có trong file nguồn
#   5  `String(localized:)` chỉ được xuất hiện ở đúng một chỗ (cầu nối toast)
#   6  `AppLanguage` (picker) khớp danh sách ngôn ngữ
#   7  View format số/ngày bằng `Text(value, format:)`, không phải `.formatted()`
#
# Luật 5 và 7 sinh ra từ một phép đo trên simulator (ngôn ngữ máy vi, environment ja):
#
#   Text("key") / Text(LocalizedStringResource)   → đổi theo ngôn ngữ chọn trong app
#   Text(String(localized: "key"))                → KHÔNG
#   String(localized: "key", locale: ja)          → KHÔNG (`locale:` chỉ đổi format)
#   Text(value, format: .currency(...))           → đổi
#   value.formatted(.currency(...))               → KHÔNG
#
# Cả hai cách sai đều **compile, chạy, không log gì**. Chúng chỉ hiện ra khi người dùng
# đổi ngôn ngữ rồi thấy một nửa màn hình không đổi theo.
#
# Phạm vi còn hẹp: `Data/` không bị soi (đầy literal wire-level), chuỗi ghép động
# `"\(a) \(b)"` thì script không đọc được ý định, và `accessibilityLabel` chưa ai canh.

set -uo pipefail
cd "$(dirname "$0")/.."

STRINGS_DIR="App/Resources"
SOURCE_STRINGS="$STRINGS_DIR/en.lproj/Localizable.strings"
BASELINE="tools/l10n-baseline.txt"

# 19 ngôn ngữ, đúng danh sách Localizations của project. XcodeGen suy `knownRegions` từ
# chính các thư mục `.lproj`, nên thêm một ngôn ngữ là tạo thêm một thư mục.
LANGUAGES="en ar zh-Hans zh-Hant nl fr de hi id it ja ko pt-BR pt-PT ru es th tr vi"

failures=0

# grep, nhưng bỏ những dòng mà nội dung bắt đầu bằng comment. Doc comment nhắc một cách
# viết sai làm ví dụ là chuyện bình thường — ba luật dưới đây đều từng đỏ vì chính doc
# của repo này.
code_grep() {
    grep -rnE "$@" --include='*.swift' 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true
}

fail() { printf '\033[31m✗\033[0m %s\n' "$1"; shift; [ "$#" -gt 0 ] && printf '    %s\n' "$@"; failures=$((failures + 1)); }
pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. File nguồn đọc được.
#    Sai cú pháp trong .strings là lỗi im lặng tệ nhất ở đây: thiếu một dấu `;` thì
#    CFBundle bỏ qua **toàn bộ file**, app rơi về tiếng Anh cho ngôn ngữ đó, và không
#    có một dòng log nào. Nên lint từng file, không chỉ file nguồn.
# ---------------------------------------------------------------------------
if [ ! -f "$SOURCE_STRINGS" ]; then
    fail "không có $SOURCE_STRINGS" "app không có ngôn ngữ nguồn thì không có gì để dịch"
    printf '\n\033[31m1 vấn đề.\033[0m\n'
    exit 1
fi
if ! plutil -lint "$SOURCE_STRINGS" >/dev/null 2>&1; then
    fail "$SOURCE_STRINGS sai cú pháp" "thiếu dấu ; hoặc dấu ngoặc kép — build sẽ KHÔNG báo gì"
    printf '\n\033[31m1 vấn đề.\033[0m\n'
    exit 1
fi
pass "en.lproj/Localizable.strings hợp lệ"

# ---------------------------------------------------------------------------
# 2. Đủ ngôn ngữ, cùng một bộ key, không giá trị rỗng.
# ---------------------------------------------------------------------------
report=$(LANGUAGES="$LANGUAGES" STRINGS_DIR="$STRINGS_DIR" python3 <<'PYEOF'
import os, plistlib, subprocess

langs = os.environ["LANGUAGES"].split()
root = os.environ["STRINGS_DIR"]

def load(lang):
    path = f"{root}/{lang}.lproj/Localizable.strings"
    if not os.path.exists(path):
        return None, f"thiếu file {path}"
    try:
        raw = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", path],
                             capture_output=True, check=True).stdout
        return plistlib.loads(raw), None
    except subprocess.CalledProcessError:
        return None, f"{path}: sai cú pháp, CFBundle sẽ bỏ qua cả file"

source, err = load("en")
if err:
    print("PROBLEM", err)
    raise SystemExit

print("KEYS", len(source))
for lang in langs:
    if lang == "en":
        continue
    table, err = load(lang)
    if err:
        print("PROBLEM", err)
        continue
    missing = sorted(set(source) - set(table))
    extra = sorted(set(table) - set(source))
    empty = sorted(k for k, v in table.items() if not str(v).strip())
    if missing:
        print("PROBLEM", f"{lang}: thiếu {len(missing)} key — {', '.join(missing[:3])}")
    if extra:
        print("PROBLEM", f"{lang}: có key en không có — {', '.join(extra[:3])}")
    if empty:
        print("PROBLEM", f"{lang}: giá trị rỗng — {', '.join(empty[:3])}")
PYEOF
)
problems=$(sed -n 's/^PROBLEM //p' <<< "$report")
key_count=$(awk '/^KEYS /{print $2}' <<< "$report")
if [ -n "$problems" ]; then
    fail "bộ .strings không đồng bộ" "$problems"
elif [ "${key_count:-0}" -eq 0 ]; then
    printf '\033[33m–\033[0m chưa có key nào — phép kiểm "dịch đủ" chưa có gì để kiểm\n'
else
    pass "$key_count key × $(wc -w <<< "$LANGUAGES" | tr -d ' ') ngôn ngữ, không thiếu chỗ nào"
fi

keys=$(plutil -convert json -o - "$SOURCE_STRINGS" \
    | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin).keys()))")
[ -f "$BASELINE" ] && baseline=$(grep -v '^#' "$BASELINE" | grep -v '^$') || baseline=""

# ---------------------------------------------------------------------------
# 3. Ratchet: chuỗi user-facing mới phải đi qua bảng dịch.
#    `verbatim:` được miễn — đó là cách nói tường minh "chuỗi này không dịch".
# ---------------------------------------------------------------------------
literals=$(
    {
        code_grep '(Text|Button|Label|navigationTitle|confirmationDialog|alert)\((verbatim: )?"[^"]+"' Features DesignSystem \
            | grep -oE '(Text|Button|Label|navigationTitle|confirmationDialog|alert)\((verbatim: )?"[^"]+"' \
            | grep -v 'verbatim: ' | sed -E 's/^[A-Za-z]+\("//; s/"$//'
        # Copy của alert và toast do ViewModel dựng cũng là text người dùng đọc.
        # `logger.*` thì không — log không phải UI, và dịch log là biến việc grep log
        # production thành bài tập đa ngữ.
        code_grep '(title|message):[[:space:]]*"[^"]+"' Features \
            | grep -oE '(title|message):[[:space:]]*"[^"]+"' \
            | sed -E 's/^[a-z]+:[[:space:]]*"//; s/"$//'
        code_grep '\.(success|error|info|warning)\("[^"]+"\)' Features \
            | grep -v 'logger\.' | grep -oE '\.(success|error|info|warning)\("[^"]+"\)' \
            | sed -E 's/^\.[a-z]+\("//; s/"\)$//'
    } | sort -u
)

unlocalized=""
while IFS= read -r literal; do
    [ -n "$literal" ] || continue
    grep -qxF "$literal" <<< "$keys" && continue
    grep -qxF "$literal" <<< "$baseline" && continue
    unlocalized="$unlocalized$literal"$'\n'
done <<< "$literals"

if [ -n "$unlocalized" ]; then
    fail "chuỗi user-facing chưa qua bảng dịch" "$unlocalized" \
        "thêm vào cả $(wc -w <<< "$LANGUAGES" | tr -d ' ') file .lproj, rồi dùng key English trong code"
else
    pass "mọi chuỗi user-facing hoặc là key có thật, hoặc là nợ đã ghi trong baseline"
fi

# Baseline phải co lại. Một dòng không còn khớp source nào là nợ đã trả mà chưa xé giấy.
stale=""
while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    grep -qxF "$entry" <<< "$literals" || stale="$stale$entry"$'\n'
done <<< "$baseline"
if [ -n "$stale" ]; then
    fail "$BASELINE còn dòng không còn trong source" "$stale" "xoá đi — baseline chỉ được co lại"
else
    baseline_count=$(grep -c . <<< "${baseline:-}" 2>/dev/null || echo 0)
    pass "baseline còn $baseline_count chuỗi nợ, không có dòng chết"
fi

# ---------------------------------------------------------------------------
# 4. Key dùng trong code phải có thật.
#    Lỗi im lặng nhất: gõ sai key thì app hiện nguyên chữ English của key, không crash,
#    không log — chỉ người dùng thấy.
# ---------------------------------------------------------------------------
orphans=""
while IFS= read -r key; do
    [ -n "$key" ] || continue
    grep -qxF "$key" <<< "$keys" && continue
    grep -qxF "$key" <<< "$baseline" && continue
    orphans="$orphans$key"$'\n'
done < <(
    {
        # Literal của `LocalizedStringResource` ở Core/Domain: `return "..."` LÀ key.
        code_grep 'return "[^"]+"' Core Domain \
            | grep -oE 'return "[^"]+"' | sed -E 's/^return "//; s/"$//'
        code_grep 'String\(localized: "[^"]+"' Core Domain Data DI DesignSystem Features App \
            | grep -oE 'String\(localized: "[^"]+"' | sed -E 's/^String\(localized: "//; s/"$//'
    } | grep -vE '^\\\(|^$' | sort -u
)
if [ -n "$orphans" ]; then
    fail "code dùng key không có trong bảng dịch" "$orphans" \
        "app sẽ hiện nguyên key — không crash, không log, nên chỉ người dùng thấy"
else
    pass "mọi key dùng trong code đều có trong bảng dịch"
fi

# ---------------------------------------------------------------------------
# 5. `String(localized:)` chỉ được xuất hiện ở đúng một chỗ.
#    Nó resolve ngay lúc gọi theo `Locale.current` = ngôn ngữ của MÁY, nên text đi qua
#    nó đóng băng ở ngôn ngữ hệ thống. Chỗ duy nhất buộc phải ra `String` là cầu nối
#    toast trong `Core/LanguageStore.swift`, và nó tra bundle `.lproj` chứ không dùng
#    API này.
# ---------------------------------------------------------------------------
frozen=$(code_grep 'String\(localized:' Core Domain Data DI DesignSystem Features App \
    | grep -v '^Core/LanguageStore.swift' || true)
if [ -n "$frozen" ]; then
    fail "String(localized:) ngoài cầu nối được phép" "$frozen" \
        "text sẽ đứng yên ở ngôn ngữ máy — dùng LocalizedStringResource và để View resolve"
else
    pass "không có text nào bị đóng băng bằng String(localized:)"
fi

# ---------------------------------------------------------------------------
# 6. Danh sách ngôn ngữ trong picker khớp danh sách app khai.
#    Một ngôn ngữ có trong `AppLanguage` mà không có `.lproj` = người dùng chọn xong rồi
#    thấy toàn tiếng Anh; ngược lại = dịch xong mà không ai chọn được.
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
# 7. Trong View: format số/ngày bằng `Text(value, format:)`.
#    `.formatted()` dựng chuỗi ngay lúc gọi bằng `Locale.current` = ngôn ngữ của MÁY.
#    Đã thấy tận mắt: cùng một đơn hàng, list (`Text(value, format:)`) hiện `đ250,000`
#    sau khi đổi sang tiếng Nhật, còn màn chi tiết (`.formatted()`) vẫn `250.000 đ`.
# ---------------------------------------------------------------------------
formatted_hits=$(code_grep '\.formatted\(' Features DesignSystem)
if [ -n "$formatted_hits" ]; then
    fail "View dùng .formatted() thay vì Text(value, format:)" "$formatted_hits" \
        "chuỗi dựng bằng .formatted() giữ nguyên ngôn ngữ của máy sau khi đổi ngôn ngữ trong app"
else
    pass "View format số/ngày qua Text(value, format:)"
fi

echo
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d vấn đề localization.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mLocalization OK.\033[0m\n'
