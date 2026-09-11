#!/usr/bin/env bash
#
# Kiểm luật + build + test, một lệnh.
#
# Thứ tự có lý: luật kiến trúc chạy trong một giây, build mất một phút. Fail sớm
# nhất có thể.
#
# Một điều đã học khi viết script này, giữ lại kẻo lặp:
#   `cmd | grep error: && exit 1` KHÔNG chạy dưới `set -o pipefail` — pipefail
#   trả exit code của cmd (khác 0), nên `&&` không bao giờ fire. Phải kiểm exit
#   code tường minh, như run_xcodebuild dưới đây.

set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
DD="${DD:-/tmp/$(basename "$PWD")-dd}"
FILTER='error:|Executed [0-9]+ tests|Test Case .* failed|(BUILD|TEST) (SUCCEEDED|FAILED)'

# Simulator chết trước khi test runner kịp nối — hạ tầng, không phải code. Đỏ giả
# đắt hơn với agent so với với người: nó sẽ đi sửa một bug không tồn tại. Chỉ
# đúng chữ ký này được thử lại; một test fail thật thì không bao giờ.
FLAKE='Early unexpected exit|crashed with signal kill before establishing connection|Failed to establish communication with the test runner'

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$1"; exit 1; }

run_xcodebuild() {
    local description="$1"; shift
    local log="$DD/last-xcodebuild.log"
    mkdir -p "$DD"
    local attempt
    for attempt in 1 2; do
        if xcodebuild "$@" >"$log" 2>&1; then
            grep -E "$FILTER" "$log" | sort -u | head -20
            return 0
        fi
        if [ "$attempt" -eq 1 ] && grep -qE "$FLAKE" "$log"; then
            printf '  simulator chết trước khi test kịp nối — chạy lại lần 2\n'
            continue
        fi
        grep -E "$FILTER" "$log" | sort -u | head -30
        die "$description thất bại. Log đầy đủ: $log"
    done
}

# Boot trước, đừng để xcodebuild vừa boot vừa test — đó là lúc hay đứt kết nối.
# `bootstatus -b` tự boot nếu chưa, rồi chờ tới khi xong, nên chạy lại vô hại.
boot_simulator() {
    local udid
    udid=$(xcrun simctl list devices available \
        | grep -m1 -F "$SIMULATOR (" \
        | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')
    if [ -z "$udid" ]; then
        echo "  không thấy simulator '$SIMULATOR' — để xcodebuild tự lo"
        return 0
    fi
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 \
        || echo "  boot '$SIMULATOR' không xong — vẫn thử test"
}

step "Luật kiến trúc"
./tools/check-arch.sh || die "Luật kiến trúc bị vi phạm"

step "Self-test cho check-arch"
# Một luật im lặng ngừng khớp còn tệ hơn không có luật, vì dấu tick xanh lúc đó
# chứng nhận điều ngược lại. Rẻ, nên chạy luôn.
./tools/check-arch-selftest.sh || die "check-arch.sh không còn bắt được vi phạm"

step "Localization"
./tools/check-l10n.sh || die "Localization chưa đủ"
./tools/check-l10n-selftest.sh >/dev/null || die "check-l10n.sh không còn bắt được vi phạm"
echo "  self-test cho check-l10n: OK"

step "Cấu hình VTMonetSDK (ads + IAP)"
# No-op khi app chưa cài VTMonetSDK (không có remote_config_defaults.plist). Khi có
# rồi thì đây là chỗ bắt `monet_sdk_config` parse trượt — thiếu một dấu phẩy là mất
# **cả** cấu hình ads, và tầng app không log gì cả.
./tools/check-monet-config.sh || die "Cấu hình ads/IAP sai"

step "Sinh lại project (XcodeGen)"
if command -v xcodegen >/dev/null; then
    xcodegen generate --quiet || die "xcodegen generate thất bại"
    echo "  project đã sinh lại"
else
    echo "  xcodegen chưa cài — bỏ qua (brew install xcodegen)"
fi

project="$(ls -d ./*.xcodeproj 2>/dev/null | head -1)"
[ -n "$project" ] || die "Không thấy .xcodeproj — chạy xcodegen generate"
scheme="$(basename "$project" .xcodeproj)"

step "Build + test"
boot_simulator
run_xcodebuild "Test" -project "$project" -scheme "$scheme" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO test

printf '\n\033[32m✓ Tất cả đều xanh.\033[0m\n'
printf '  App: %s\n' "$DD/Build/Products/Debug-iphonesimulator/$scheme.app"
echo "  Bước cuối: mở app trên simulator và xem đúng màn vừa sửa (skill ios-verify)."
