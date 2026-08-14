#!/usr/bin/env bash
#
# A test for the tests: proves each rule in check-arch.sh actually fails when
# violated.
#
# A layering check that quietly stops matching is worse than no check, because
# the green tick then certifies the opposite of what it claims. This introduces
# one real violation per rule, asserts the check fails, and restores the file.
#
# Run it whenever check-arch.sh changes. It is cheap — a few seconds.

set -uo pipefail
cd "$(dirname "$0")/.."

pass_count=0 fail_count=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

skip_count=0

# Probe dựng file của chính nó rồi xoá đi, không sửa file có sẵn.
#
# Bản đầu append vào `Domain/Entities/Order.swift`, `Features/Order/…` — tức là
# vào demo. Điều đó chỉ đúng trong template: một app tạo bằng `init-base` không
# có demo, và cả tám probe đầu tiên báo đỏ vì `No such file or directory` —
# self-test đỏ trong một repo hoàn toàn sạch. Probe phải tự mang theo vi phạm
# của nó thì mới chạy được ở mọi repo dùng bộ luật này.
#
# probe_file <rule name> <path> <nội dung file>
probe_file() {
    local name="$1" file="$2" body="$3"
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$body" > "$file"
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m %s — vi phạm KHÔNG bị bắt\n' "$name"
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    fi
    rm -f "$file"
}

# Vài luật suy tên type từ chính source (2, 3): không có tầng Data thì không có
# gì để vi phạm, và một probe luôn xanh ở đó là một lời chứng nhận rỗng. Bỏ qua
# **có nêu lý do** — cùng bài học của doctor.sh: một phép kiểm báo xanh (hay đỏ)
# cho trạng thái không liên quan sẽ dạy người ta bỏ qua màu của nó.
skip() {
    printf '\033[33m–\033[0m %s — bỏ qua: %s\n' "$1" "$2"
    skip_count=$((skip_count + 1))
}

echo "Kiểm tra check-arch.sh có thật sự bắt được vi phạm:"
echo

# Baseline: phải sạch trước khi thử, nếu không kết quả vô nghĩa.
if ! ./tools/check-arch.sh >/dev/null 2>&1; then
    echo "Repo đang có vi phạm sẵn — sửa trước rồi chạy lại self-test."
    exit 1
fi

probe_file "1 · Domain import framework" \
    Domain/__Probe.swift "import SwiftUI"

# Luật 2 và 3 đọc tên type khai trong Data/ rồi tìm chúng ở nơi không được biết.
# Nên probe phải dựng cả hai đầu: một type trong Data, và một chỗ dùng nó.
if [ -d Data ]; then
    printf 'struct ZZProbeDTO { let id: String }\n' > Data/ZZProbeDTO.swift

    probe_file "2 · Domain dùng type của Data" \
        Domain/__Probe.swift "func __probe() { _ = ZZProbeDTO.self }"

    probe_file "3 · Feature dùng type của Data" \
        Features/__Probe.swift "func __probe() { _ = ZZProbeDTO.self }"

    rm -f Data/ZZProbeDTO.swift
else
    skip "2 · Domain dùng type của Data" "app không có tầng Data"
    skip "3 · Feature dùng type của Data" "app không có tầng Data"
fi

# Probe phải là code thật, không phải comment — luật 4 cố tình bỏ qua comment.
probe_file "4 · ViewModel gọi pushView" \
    Features/__ProbeViewModel.swift "func __probe() { router.pushView { } }"

probe_file "5 · Transport type lọt ra Feature" \
    Features/__Probe.swift "func __probe() -> KVAPIClientError? { nil }"

probe_file "6 · Color literal trong Feature" \
    Features/__Probe.swift "let __probe = Color(red: 1, green: 0, blue: 0)"

# `#Preview` trong chính probe là có chủ đích: thiếu nó thì luật 11 cũng đỏ, và
# probe này sẽ xanh vì lý do của luật khác — đúng kiểu chứng nhận rỗng mà cả file
# này sinh ra để chặn.
probe_file "7 · View con giữ ViewModel" Features/__Probe.swift \
"import SwiftUI
struct __Probe: View { let viewModel: ZZProbeViewModel; var body: some View { EmptyView() } }
#Preview { EmptyView() }"

probe_file "8 · Dependency key ngoài DI/" Features/__Probe.swift \
    "enum __ProbeKey: KVDependencyKey { static let liveValue = 0 }"

# Luật 9 và 10 không kiểm được bằng cách thêm một dòng vào file Swift: một cái là
# folder, hai cái còn lại là câu README nói về chính cây source và chính script này.
probe_dir() {
    mkdir -p Domain/__probe
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m 9 · Folder rỗng — vi phạm KHÔNG bị bắt\n'
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m 9 · Folder rỗng\n'
        pass_count=$((pass_count + 1))
    fi
    rmdir Domain/__probe
}
probe_dir

probe_readme() {
    cp README.md "$tmp/readme"
    mkdir -p __ProbeLayer && touch __ProbeLayer/keep.swift
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m 10 · README lệch đĩa — vi phạm KHÔNG bị bắt\n'
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m 10 · README lệch đĩa\n'
        pass_count=$((pass_count + 1))
    fi
    rm -rf __ProbeLayer
    cp "$tmp/readme" README.md
}
probe_readme

probe_readme_count() {
    cp README.md "$tmp/readme"
    perl -pi -e 's/\b\d+ luật/999 luật/' README.md
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m 10b · README nói sai số luật — KHÔNG bị bắt\n'
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m 10b · README nói sai số luật\n'
        pass_count=$((pass_count + 1))
    fi
    cp "$tmp/readme" README.md
}
probe_readme_count

# Luật 11 cũng không kiểm được bằng cách thêm một dòng: phải có một View KHÔNG preview.
probe_preview() {
    cat > DesignSystem/Components/__ProbeView.swift <<'SWIFT'
import SwiftUI
struct __ProbeView: View { var body: some View { EmptyView() } }
SWIFT
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m 11 · View thiếu #Preview — vi phạm KHÔNG bị bắt\n'
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m 11 · View thiếu #Preview\n'
        pass_count=$((pass_count + 1))
    fi
    rm -f DesignSystem/Components/__ProbeView.swift
}
probe_preview

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d phép kiểm không bắt được vi phạm.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d phép kiểm đều bắt được vi phạm.\033[0m\n' "$pass_count"
[ "$skip_count" -gt 0 ] && printf '\033[33m%d phép kiểm bỏ qua vì app không có tầng tương ứng.\033[0m\n' "$skip_count"
exit 0
