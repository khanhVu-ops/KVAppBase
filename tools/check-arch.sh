#!/usr/bin/env bash
#
# Enforces the layering rules on a single-target app.
#
# Why this file carries more weight here than in a multi-module setup: files in
# the same Swift module see each other with no `import` line at all. So
# "Features must not touch Data" cannot be checked by grepping imports — there is
# nothing to grep. Instead this script reads the *type names declared in each
# folder* and then looks for those names being used from folders that should not
# know them. That derives the rule from the source itself, so it keeps working as
# the code grows and never needs a hand-maintained list.
#
# Framework imports (SwiftUI, KVNetworkit, …) are still real imports, so those
# rules stay simple.
#
# Usage:  ./tools/check-arch.sh        Exit 0 = clean, 1 = at least one violation.

set -uo pipefail
cd "$(dirname "$0")/.."

failures=0

# grep, nhưng bỏ những dòng khớp mà nội dung bắt đầu bằng comment.
# Doc comment nhắc tên type là chuyện bình thường và đáng khuyến khích —
# `/// `OrderDTO` in Data is what the backend sends` không phải vi phạm.
code_grep() {
    grep -rnE "$@" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true
}

fail() { printf '\033[31m✗\033[0m %s\n' "$1"; shift; printf '    %s\n' "$@"; failures=$((failures + 1)); }
pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }

# Top-level type names declared under a folder.
declared_types() {
    code_grep '^(final |public |internal )*(struct|class|enum|protocol|actor) [A-Z][A-Za-z0-9_]*' \
        --include="*.swift" "$1" \
        | grep -oE '(struct|class|enum|protocol|actor) [A-Z][A-Za-z0-9_]*' \
        | awk '{print $NF}' | sort -u
}

# Uses of any name in $2 (newline-separated) from the folders in $3...
uses_of() {
    local names="$1"; shift
    [ -n "$names" ] || return 0
    local pattern
    pattern="\\b($(echo "$names" | paste -sd'|' -))\\b"
    code_grep "$pattern" --include="*.swift" "$@"
}

# ---------------------------------------------------------------------------
# 1. Domain and Core stay free of delivery frameworks.
#    These are real imports, so this is a plain check. The moment Domain imports
#    SwiftUI or a networking package, business rules stop being testable in
#    milliseconds and start needing a simulator.
# ---------------------------------------------------------------------------
hits=$(code_grep '^import (SwiftUI|UIKit|KVNetworkit|KVRouterKit|KVRouterCore|KVDIKit|KVToastKit|KVLoggingKit)' \
    --include="*.swift" Core Domain)
if [ -n "$hits" ]; then
    fail "Core/Domain imports a delivery framework" "$hits"
else
    pass "Core and Domain import nothing but Foundation"
fi

# ---------------------------------------------------------------------------
# 2. Domain does not know Data exists.
#    Derived from the source: every type declared under Data/ must be absent from
#    Domain/ and Core/. This is the dependency inversion the whole layering rests
#    on — Data implements Domain's protocols, never the other way round.
# ---------------------------------------------------------------------------
data_types=$(declared_types Data)
hits=$(uses_of "$data_types" Core Domain)
if [ -n "$hits" ]; then
    fail "Domain/Core references a type declared in Data" "$hits"
else
    pass "Domain does not know Data exists ($(echo "$data_types" | wc -l | tr -d ' ') types checked)"
fi

# ---------------------------------------------------------------------------
# 3. Features never touch Data.
#    A feature that reaches for a concrete repository has skipped the protocol
#    that makes it testable, and coupled a screen to a wire format.
#
#    Data/Testing is exempt as a *source* of names: stubs exist to be injected
#    into tests, and DI names them for `testValue`.
# ---------------------------------------------------------------------------
data_types_no_stubs=$(declared_types Data | grep -vE '^(Stub|InMemory)' || true)
hits=$(uses_of "$data_types_no_stubs" Features)
if [ -n "$hits" ]; then
    fail "A feature references a type declared in Data" "$hits"
else
    pass "No feature touches Data"
fi

# ---------------------------------------------------------------------------
# 4. ViewModels do not reach into the view layer.
#    `pushView` needs KVViewRouting, which only KVRouterKit exposes. A ViewModel
#    that builds a view cannot be tested against KVRouterSpy, and has moved a
#    presentation decision into the model layer.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
    [ -n "$file" ] || continue
    # Strip trailing comments first. A line like
    #   import KVRouterCore   // no SwiftUI here, so `pushView` is unreachable
    # is prose about the rule, not a violation of it — and the first version of
    # this check flagged exactly that, in this repo's own source.
    code="$(sed 's|//.*||' "$file")"
    grep -qE '^import (KVRouterKit|SwiftUI)[[:space:]]*$' <<<"$code" \
        && hits="$hits$file: imports KVRouterKit/SwiftUI (use KVRouterCore)"$'\n'
    # `\bpushView\b`, not `pushView\(`: the common spelling is a trailing
    # closure — `router.pushView { DetailView() }` — which has no paren at all.
    # The paren-only pattern silently passed that, which the self-test caught.
    grep -qE '\bpushView\b' <<<"$code" \
        && hits="$hits$file: calls pushView (that belongs in the View)"$'\n'
done < <(find Core Domain Data DI Features App -name "*ViewModel.swift" 2>/dev/null)
if [ -n "$hits" ]; then
    fail "ViewModel reaches into the view layer" "$hits"
else
    pass "ViewModels stay on KVRouterCore"
fi

# ---------------------------------------------------------------------------
# 5. Transport errors do not escape Data.
#    They are mapped to AppError at the repository boundary. A ViewModel
#    switching on a status code breaks the day the transport changes.
# ---------------------------------------------------------------------------
hits=$(code_grep '\bKVAPIClientError\b|\bKVAPIEndpointProtocol\b|\bJSONDecoder\b' \
    --include="*.swift" Core Domain Features)
if [ -n "$hits" ]; then
    fail "A transport type leaked out of Data" "$hits"
else
    pass "Only AppError crosses layer boundaries"
fi

# ---------------------------------------------------------------------------
# 6. No colour literals outside DesignSystem.
#    A hard-coded colour cannot be restyled, has no dark variant, and is
#    invisible to whoever regenerates tokens from Figma.
# ---------------------------------------------------------------------------
hits=$(code_grep 'Color\((red:|hex:)|#colorLiteral' --include="*.swift" Features App Domain Data)
if [ -n "$hits" ]; then
    fail "Colour literal outside DesignSystem" "$hits"
else
    pass "All colours come from DesignSystem"
fi

# ---------------------------------------------------------------------------
# 7. Child views take values, not the ViewModel.
#    On iOS 16 `ObservableObject` invalidates per object, so a child holding the
#    ViewModel re-renders on every unrelated change. Handing it a value lets
#    SwiftUI skip the subtree — this is the whole iOS 16 performance strategy.
#    A screen owning its ViewModel with @StateObject is the allowed case.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
    [ -n "$file" ] || continue
    case "$(basename "$file")" in *ViewModel.swift) continue ;; esac
    found=$(grep -nE '(let|var) +[a-zA-Z]+ *: *[A-Z][A-Za-z]*ViewModel' "$file" \
        | grep -v '@StateObject' || true)
    [ -n "$found" ] && hits="$hits$file:"$'\n'"$found"$'\n'
done < <(find Features App DesignSystem -name "*.swift" 2>/dev/null)
if [ -n "$hits" ]; then
    fail "A child view holds a ViewModel instead of values" "$hits"
else
    pass "Child views take values, not ViewModels"
fi

# ---------------------------------------------------------------------------
# 8. Dependency keys live in DI only.
#    Features read keys; only the composition root writes them. A key declared
#    inside a feature is a feature deciding its own wiring, which is how two
#    screens end up with two different instances of the same repository.
# ---------------------------------------------------------------------------
hits=$(code_grep 'KVDependencyKey' --include="*.swift" Core Domain Data Features App)
if [ -n "$hits" ]; then
    fail "A dependency key is declared outside DI/" "$hits"
else
    pass "All dependency keys live in DI/"
fi

# ---------------------------------------------------------------------------
# 9. No empty folders.
#    A folder left behind after its contents moved is a claim about the
#    architecture that is no longer true. `Domain/Errors/` survived here for a
#    while after AppError moved to Core/, and it read as "domain errors live
#    here" to anyone opening the tree.
# ---------------------------------------------------------------------------
hits=$(find Core Domain Data DI DesignSystem Features App Tests -type d -empty 2>/dev/null)
if [ -n "$hits" ]; then
    fail "Folder rỗng — dọn hoặc dùng đi" "$hits"
else
    pass "Không có folder rỗng"
fi

# ---------------------------------------------------------------------------
# 10. README.md tells the truth — about the tree, and about this script.
#     This is the drift that matters most, and the one nothing usually catches:
#     a rule file describing a layout the source no longer has teaches everyone
#     who reads it — human or agent — the wrong thing, before they ever look at
#     the code.
#
#     Two claims, because checking only the first one certifies the rest of the
#     sentence for free: README said "8 luật" for a while after rules 9 and 10
#     landed, and this very rule stayed green through it.
# ---------------------------------------------------------------------------
documented=$(grep -oE '^[A-Z][A-Za-z]*/' README.md | tr -d '/' | sort -u)
# Chỉ so folder *tầng*. Bỏ dot-dir (.git, .claude, .agents) và những folder không
# phải tầng (tools, config, docs). Nếu không, một repo vừa init-base — mang theo
# .claude và config của kit — fail ngay ở lệnh verify đầu tiên của nó.
actual=$(find . -maxdepth 1 -type d \
    -not -name '.*' -not -name 'tools' -not -name 'config' -not -name 'docs' \
    -not -name 'fastlane' -not -name 'build' -not -name '*.xcodeproj' \
    | sed 's|^\./||' | sort -u)
missing=$(comm -23 <(echo "$actual") <(echo "$documented"))
extra=$(comm -13 <(echo "$actual") <(echo "$documented"))
if [ -n "$missing" ] || [ -n "$extra" ]; then
    message=""
    [ -n "$missing" ] && message="$message"$'có trên đĩa nhưng README không nhắc: '"$(echo "$missing" | tr '\n' ' ')"$'\n'
    [ -n "$extra" ] && message="$message"$'README nhắc nhưng không có trên đĩa: '"$(echo "$extra" | tr '\n' ' ')"
    fail "README.md mô tả cấu trúc khác thực tế" "$message"
else
    pass "README.md khớp cấu trúc trên đĩa"
fi

# Số luật README hứa phải bằng số luật script thật sự có.
rule_count=$(grep -cE '^# [0-9]+\. ' "$0")
claimed=$(grep -oE '[0-9]+ luật' README.md | grep -oE '^[0-9]+' | sort -u)
if [ -n "$claimed" ] && [ "$claimed" != "$rule_count" ]; then
    fail "README.md nói sai số luật" \
        "README: $(echo "$claimed" | tr '\n' ' ')· check-arch.sh có $rule_count luật"
else
    pass "README.md nói đúng số luật ($rule_count)"
fi

# ---------------------------------------------------------------------------
# 11. Mọi View đều có `#Preview`.
#     Preview là cách rẻ nhất để nhìn thấy một màn ở trạng thái rỗng, lỗi, tên dài,
#     dark mode, và ở một ngôn ngữ khác — những trạng thái mà chạy app rất khó dựng
#     lại. Một View không có preview thì cách duy nhất để xem nó là build, chạy, đăng
#     nhập, bấm tới đúng chỗ; nên nó không được xem, nên nó hỏng lặng lẽ.
#
#     Chỉ soi file khai `struct X: View`. File chỉ có `ViewModifier` hay
#     `UIViewRepresentable` thì không tính — chúng không đứng một mình được.
# ---------------------------------------------------------------------------
missing_preview=""
for file in $(grep -rlE '^(public |internal |private |fileprivate )?struct [A-Za-z_][A-Za-z0-9_]*(<[^>]*>)? *:.*\bView\b' \
        --include="*.swift" Features DesignSystem 2>/dev/null); do
    grep -q '#Preview' "$file" || missing_preview="$missing_preview$file"$'\n'
done
if [ -n "$missing_preview" ]; then
    fail "View không có #Preview" "$missing_preview" \
        "thêm #Preview kèm dữ liệu mock — Fixtures.swift đã có sẵn đơn hàng và user"
else
    pass "Mọi View đều có #Preview"
fi

# ---------------------------------------------------------------------------
# 12. Sheet là `.sheet` của hệ thống, và nó phải có nền presentation.
#     Hai nửa của cùng một lỗi, và cả hai đã xảy ra thật trong repo này.
#
#     Nửa thứ nhất — `overlay { scrim + content }` thay cho `.sheet`. Nó *trông*
#     đúng và thiếu hết những gì UIKit làm sẵn: gạt xuống để đóng, đà quán tính,
#     bàn phím đẩy sheet lên, VoiceOver coi phần dưới sheet là không chạm được,
#     `Reduce Motion`. Dựng lại từng cái đó là dựng lại
#     `UISheetPresentationController`. Ba lý do từng khiến người ta tránh `.sheet`
#     đều đã có lời giải trong repo: `sheetFitHeight()` cho chiều cao,
#     `sheetDragIndicator()` cho vạch kéo, và lớp mờ thì hệ thống tự vẽ.
#
#     Nửa thứ hai — `.sheet` mà không đặt nền presentation. Detent cao bằng nội
#     dung, nhưng tấm sheet còn dải safe area dưới (home indicator) mà nội dung
#     không với tới. Không đặt nền thì dải đó là màu hệ thống, và nó lộ ra thành
#     một vệt khác màu dưới đáy — nhìn như card bị hụt. Trên iOS 16.0
#     `sheetBackground` tự hạ xuống `.background`, nên gọi nó là an toàn ở mọi bản.
#
#     Luật suy từ source, không có danh sách tay: view do UIKit sở hữu — khai
#     `UIViewControllerRepresentable` / `UIViewRepresentable` — được miễn, vì
#     `ShareSheet` và `MailComposerView` mang chrome của UIKit và ta không sơn nó.
#
#     `.fullScreenCover` **không** bị kiểm ở đây: nó phủ kín màn nên không có dải
#     nào hở. Ngoại lệ đáng biết là màn có nền bằng **ảnh** — ảnh cần một nhịp để
#     giải mã, và trong nhịp đó thứ hiện ra là nền presentation; một màn có nền
#     bằng ảnh thì nên đặt nền presentation cùng màu với ảnh.
# ---------------------------------------------------------------------------
sheet_report=$(/usr/bin/python3 - <<'PYEOF'
import io, os, re, sys

roots = [r for r in ("Features", "DesignSystem") if os.path.isdir(r)]
files = []
for root in roots:
    for dirpath, _, names in os.walk(root):
        files += [os.path.join(dirpath, n) for n in names if n.endswith(".swift")]

DECL = re.compile(
    r"^\s*(?:public |internal |private |fileprivate )?"
    r"(?:struct|final class|class) ([A-Za-z_][A-Za-z0-9_]*)(?:<[^>]*>)? *:([^{]*)"
)

app_views, uikit_owned = set(), set()
for f in files:
    for line in io.open(f, encoding="utf-8", errors="ignore"):
        m = DECL.match(line)
        if not m:
            continue
        name, conformances = m.group(1), m.group(2)
        if "Representable" in conformances:
            uikit_owned.add(name)
        elif re.search(r"\bView\b", conformances):
            app_views.add(name)
app_views -= uikit_owned

# Nền presentation đã được đặt, trực tiếp hay qua helper của DesignSystem.
BACKGROUND = re.compile(r"\.(sheetBackground|presentationBackground)\(")
# `.sheet` phải là **lời gọi** — `\.sheet\s*\(`. Bản đầu nhận cả `[({]` và nó
# khớp `switch viewModel.state.sheet {`, tức một property tên `sheet` trong
# `switch`, rồi báo `CreateVideoView` vi phạm trong khi màn đó dùng `.bottomSheet`
# đúng chuẩn. `.overlay` thì cả hai dạng đều là lời gọi thật.
PRESENT = re.compile(r"\.sheet\s*\(|\.overlay\s*[({]")

def strip_comments(lines):
    """Comment thành dòng rỗng — giữ nguyên số dòng để báo đúng vị trí.

    Luật này từng đỏ vì một **ví dụ trong doc comment** của chính
    View+SheetFitHeight.swift: khối swift trong docstring có một lời gọi sheet,
    và nó được đọc như code thật. Luật 4 đã bỏ qua comment từ đầu; luật này thì
    quên, và nó chỉ lộ ra ở repo mà tên View trong ví dụ có thật.

    (Docstring này cố tình không có dấu backtick: cả khối Python nằm trong một
    $(...) của bash, nên một backtick lẻ làm bash đi tìm dấu đóng và báo
    "unexpected EOF".)
    """
    out, in_block = [], False
    for line in lines:
        s = line.strip()
        if in_block:
            out.append("")
            if "*/" in s:
                in_block = False
            continue
        if s.startswith("/*"):
            out.append("")
            if "*/" not in s:
                in_block = True
            continue
        out.append("" if s.startswith("//") else line)
    return out


def block_after(lines, i):
    """Chuỗi từ dòng i tới khi ngoặc của modifier đó đóng lại."""
    depth, out = 0, []
    started = False
    for line in lines[i:]:
        out.append(line)
        for ch in line:
            if ch in "({":
                depth += 1
                started = True
            elif ch in ")}":
                depth -= 1
        if started and depth <= 0:
            break
    return "\n".join(out)

problems = []
for f in files:
    lines = strip_comments(io.open(f, encoding="utf-8", errors="ignore").read().split("\n"))
    for i, line in enumerate(lines):
        m = PRESENT.search(line)
        if not m:
            continue
        kind = "overlay" if ".overlay" in m.group(0) else "sheet"
        block = block_after(lines, i)
        used = {n for n in app_views if re.search(r"\b%s\s*\(" % re.escape(n), block)}
        sheets = {n for n in used if n.endswith("Sheet")}
        if kind == "overlay":
            if sheets:
                problems.append("%s:%d — %s dựng trong .overlay, phải qua .sheet/bottomSheet"
                                % (f, i + 1, ", ".join(sorted(sheets))))
        elif used and not BACKGROUND.search(block) and ".sheetFitHeight()" not in block:
            # Không có nền, và cũng không phải một sheet đã đo chiều cao — tức là
            # chưa đi qua bộ modifier nào của repo.
            problems.append("%s:%d — .sheet dựng %s mà không đặt nền presentation"
                            % (f, i + 1, ", ".join(sorted(used))))
        elif used and not BACKGROUND.search(block):
            problems.append("%s:%d — .sheet dựng %s có sheetFitHeight nhưng thiếu sheetBackground"
                            % (f, i + 1, ", ".join(sorted(used))))

print("\n".join(problems))
PYEOF
)
if [ -n "$sheet_report" ]; then
    fail "Sheet không đi qua .sheet, hoặc thiếu nền presentation" "$sheet_report" \
        "dùng .bottomSheet(isPresented:onDismiss:) — nó đã gắn sẵn cả bộ" \
        "hoặc tự xếp: .fixedSize → .sheetFitHeight() → .sheetDragIndicator() → .sheetBackground(...)"
else
    pass "Sheet đi qua .sheet và có nền presentation"
fi

echo
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d architecture rule(s) violated.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mArchitecture rules OK.\033[0m\n'
