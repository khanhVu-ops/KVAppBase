#!/bin/bash
# Nạp monet_sdk_config.test.json (toàn bộ ad unit là ID test của Google) vào
# remote_config_defaults.plist để chạy ads trên máy khi chưa có placement chuẩn.
#
#   tools/ads-test-config.sh            # nạp config test
#   tools/ads-test-config.sh --restore  # trả lại bản trước
#
# Plist được tự tìm trong repo; chưa có thì script tạo cạnh `Resources/Info.plist`.
# Bản cũ giữ ở <plist>.bak, `--restore` đưa nó về.
#
# KHÔNG commit kết quả lên nhánh release: một build mang ID test chạy đúng, hiện ad
# đủ, và không có doanh thu — nó chỉ lộ ra ở báo cáo cuối tháng.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON="$ROOT/tools/ads-test-config.json"

cd "$ROOT"

# Tìm plist đang có. `-not -path` bỏ Pods và build cache: một bản copy trong
# DerivedData trông giống hệt bản thật và ghi vào đó thì không có tác dụng gì.
PLIST="$(find . -name 'remote_config_defaults.plist' \
    -not -path './Pods/*' -not -path './.derivedData/*' -not -path './build/*' \
    -not -path './.git/*' 2>/dev/null | head -1)"

if [ "${1:-}" = "--restore" ]; then
    [ -n "$PLIST" ] || { echo "❌ không tìm thấy remote_config_defaults.plist"; exit 1; }
    [ -f "$PLIST.bak" ] || { echo "❌ không có $PLIST.bak để trả lại"; exit 1; }
    mv "$PLIST.bak" "$PLIST"
    echo "✅ đã trả lại $PLIST"
    exit 0
fi

[ -f "$JSON" ] || { echo "❌ không thấy $JSON"; exit 1; }

CREATED=0
if [ -z "$PLIST" ]; then
    # Chưa có plist — repo vừa init-base thì đúng là chưa có. Đặt cạnh Info.plist
    # của app để nó nằm trong cùng nhóm Resources mà project đã biết.
    INFO="$(find . -path '*/Resources/Info.plist' \
        -not -path './Pods/*' -not -path './.git/*' 2>/dev/null | head -1)"
    [ -n "$INFO" ] || { echo "❌ không tìm thấy */Resources/Info.plist để đặt plist cạnh"; exit 1; }
    PLIST="$(dirname "$INFO")/remote_config_defaults.plist"
    /usr/bin/python3 -c "import plistlib,sys;plistlib.dump({}, open(sys.argv[1],'wb'))" "$PLIST"
    CREATED=1
fi

# `/usr/bin/python3`, không phải `/usr/bin/python3`: bản Homebrew trên một số máy có
# plistlib hỏng (pyexpat lệch libexpat) và lỗi trả về nhìn như file plist sai.
/usr/bin/python3 - "$PLIST" "$JSON" <<'PY'
import json, plistlib, shutil, sys

plist_path, json_path = sys.argv[1], sys.argv[2]

with open(json_path) as f:
    config = json.load(f)
config.pop("_comment", None)

with open(plist_path, "rb") as f:
    defaults = plistlib.load(f)

shutil.copyfile(plist_path, plist_path + ".bak")
defaults["monet_sdk_config"] = json.dumps(config, indent=2, ensure_ascii=False)

with open(plist_path, "wb") as f:
    plistlib.dump(defaults, f)

native = [s["name"] for s in config["ads_native"]["spaces"]]
banner = [s["name"] for s in config["ads_banner"]["spaces"]]
inter = [s["name"] for s in config["ads_inter"]["spaces"]]
print(f"✅ đã nạp: {len(native)} native · {len(banner)} banner · {len(inter)} inter space")
print(f"   {plist_path}")
print(f"   backup: {plist_path}.bak")
PY

if [ "$CREATED" = "1" ]; then
    echo "⚠️  plist vừa được tạo mới — kiểm lại nó đã nằm trong target chưa"
    echo "   (XcodeGen: chạy lại xcodegen; Xcode: Build Phases → Copy Bundle Resources)"
fi
echo "⚠️  toàn bộ ad unit là ID test của Google — đừng build release bằng config này"
