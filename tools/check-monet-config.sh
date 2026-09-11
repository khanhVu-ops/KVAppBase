#!/bin/bash
# Kiểm remote_config_defaults.plist — cấu hình VTMonetSDK cho ads và IAP.
#
#   ./tools/check-monet-config.sh
#
# Vì sao cần: `monet_sdk_config` và `iap_placement_config` là **chuỗi JSON** trong
# plist. Thiếu một dấu phẩy thì cả chuỗi parse trượt — không mất một placement, mà
# mất cả cấu hình — và tầng app không log gì. Một `name`/`placement` gõ sai thì SDK
# log rồi im: ad không hiện, paywall trắng, app vẫn chạy.
#
# App chưa cài VTMonetSDK (không có plist) → no-op, exit 0.
#
# Dữ liệu quét từ Swift đi vào Python qua **biến môi trường**, và heredoc dưới đây
# được quote (`<<'PY'`). Bản trước nội suy `$VAR` vào heredoc không quote, nên mọi
# backtick trong comment tiếng Việt của phần Python bị bash chạy như lệnh
# (`placement: command not found`). Đừng bỏ dấu quote ở `<<'PY'`.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLIST="$(find . -name 'remote_config_defaults.plist' \
    -not -path './Pods/*' -not -path './.derivedData/*' -not -path './build/*' \
    -not -path './.git/*' 2>/dev/null | head -1)"

if [ -z "$PLIST" ]; then
    echo "⚠️  chưa có remote_config_defaults.plist — app này chưa cài VTMonetSDK?"
    echo "   xem bước 0 trong .claude/skills/ads/SKILL.md"
    exit 0
fi

# ── Ads: đối số `name:` luôn là literal ──────────────────────────────────────
export MONET_ADS_USED="$(grep -rhoE '(SwiftUINativeView|SwiftUIBannerView|SwiftUIBannerScreenWrapper|SwiftUICustomNativeAd)\((name|adPointName): *"[a-z0-9_]+"|(load|reload|onPause|onResume|remove)(Native|Banner)\(name: *"[a-z0-9_]+"|tryShowInterstitialOnNavigation(Async)?\(name: *"[a-z0-9_]+"' \
    --include='*.swift' . 2>/dev/null \
    | grep -oE '"[a-z0-9_]+"' | tr -d '"' | sort -u || true)"

# ── IAP: placement gần như luôn đi qua hằng số ───────────────────────────────
# Hai mức, và sự khác nhau là có chủ đích:
#   · CHẮC  — literal, hoặc `Type.member` đứng ngay sau `placement:`. Dùng để FAIL.
#   · LỎNG  — mọi `.member` xuất hiện trong file có chữ `placement`. Bắt được cả
#             `placement: cond ? A.open : A.reopen` mà regex chắc không thấy. Chỉ
#             dùng cho dòng thông tin, vì một tên member trùng nhau là đủ để sai.
export MONET_IAP_LITERALS="$(grep -rhoE '(VTIAPScreenView|VTIAPViewModel)\(placement: *"[a-z0-9_]+"' \
    --include='*.swift' . 2>/dev/null | grep -oE '"[a-z0-9_]+"' | tr -d '"' | sort -u || true)"

export MONET_IAP_SYMBOLS="$(grep -rhoE '(VTIAPScreenView|VTIAPViewModel)\(placement: *[A-Z][A-Za-z0-9]*\.[a-zA-Z][a-zA-Z0-9]*' \
    --include='*.swift' . 2>/dev/null | sed -E 's/.*\.([a-zA-Z][a-zA-Z0-9]*)$/\1/' | sort -u || true)"

iap_files="$(grep -rlE 'placement' --include='*.swift' . 2>/dev/null || true)"
if [ -n "$iap_files" ]; then
    export MONET_IAP_MEMBERS="$(printf '%s\n' "$iap_files" \
        | tr '\n' '\0' | xargs -0 grep -hoE '[A-Z][A-Za-z0-9]*\.[a-zA-Z][a-zA-Z0-9]*' 2>/dev/null \
        | sed -E 's/.*\.([a-zA-Z][a-zA-Z0-9]*)$/\1/' | sort -u || true)"
else
    export MONET_IAP_MEMBERS=""
fi

# `static let iconApp = "icon_app"` → `iconApp=icon_app`
export MONET_CONSTANTS="$(grep -rhoE 'static let [a-zA-Z][a-zA-Z0-9]* *= *"[a-z0-9_]+"' \
    --include='*.swift' . 2>/dev/null \
    | sed -E 's/static let ([a-zA-Z][a-zA-Z0-9]*) *= *"([a-z0-9_]+)"/\1=\2/' | sort -u || true)"

# `screen_code` đã đăng ký: literal, hoặc `VTIAPScreenCode.iapN` → `IAPN`
export MONET_SCREEN_CODES="$(grep -rhoE 'register(IAPView)?\(screenCode: *("[A-Za-z0-9]+"|VTIAPScreenCode\.iap[0-9]+)' \
    --include='*.swift' . 2>/dev/null \
    | sed -E 's/.*VTIAPScreenCode\.iap([0-9]+)/IAP\1/; s/.*"([A-Za-z0-9]+)"/\1/' \
    | tr '[:lower:]' '[:upper:]' | sort -u || true)"

export MONET_PLIST="$PLIST"

/usr/bin/python3 - <<'PY'
import json, os, plistlib, re, sys

def words(key):
    return [w for w in os.environ.get(key, "").split() if w]

plist_path   = os.environ["MONET_PLIST"]
ads_used     = words("MONET_ADS_USED")
iap_literals = words("MONET_IAP_LITERALS")
iap_symbols  = words("MONET_IAP_SYMBOLS")
iap_members  = words("MONET_IAP_MEMBERS")
screen_codes = set(words("MONET_SCREEN_CODES"))
constants    = dict(p.split("=", 1) for p in words("MONET_CONSTANTS") if "=" in p)

NATIVE_TYPES = {
    "360x90_cta_right", "360x140_cta_bot", "360x176_cta_right", "360x230_cta_bot",
    "360x250_cta_bot", "360x360_cta_bot", "full",
    "native_collapsible_360x140", "native_collapsible_360x176",
    "native_collapsible_close_360x360",
}
BANNER_TYPES = {
    "banner_adaptive", "banner_inline",
    "banner_collapsible_top", "banner_collapsible_bottom",
}

fails, notes = [], []

with open(plist_path, "rb") as f:
    defaults = plistlib.load(f)

print("plist: %s" % plist_path)

# ── monet_sdk_config (ads) ───────────────────────────────────────────────────
raw = defaults.get("monet_sdk_config")
if not raw:
    fails.append("plist không có key monet_sdk_config")
else:
    try:
        cfg = json.loads(raw)
    except json.JSONDecodeError as e:
        print("❌ monet_sdk_config không phải JSON hợp lệ: %s" % e)
        print("   cả cấu hình ads bị bỏ, không chỉ một placement")
        sys.exit(1)

    native = cfg.get("ads_native", {}).get("spaces", [])
    banner = cfg.get("ads_banner", {}).get("spaces", [])
    inter  = cfg.get("ads_inter", {}).get("spaces", [])
    nat_names = [s.get("name", "") for s in native]
    ban_names = [s.get("name", "") for s in banner]
    int_names = [s.get("name", "") for s in inter]

    for label, names in (("native", nat_names), ("banner", ban_names), ("inter", int_names)):
        dup = sorted({n for n in names if names.count(n) > 1})
        if dup:
            fails.append("%s space khai trùng tên: %s" % (label, ", ".join(dup)))

    for s in native:
        if s.get("type") not in NATIVE_TYPES:
            fails.append("native %r có type không hợp lệ: %r" % (s.get("name"), s.get("type")))
    for s in banner:
        if s.get("type") not in BANNER_TYPES:
            fails.append("banner %r có type không hợp lệ: %r" % (s.get("name"), s.get("type")))
        if s.get("banner_position", "bottom") not in ("top", "bottom"):
            fails.append("banner %r có banner_position không hợp lệ: %r"
                         % (s.get("name"), s.get("banner_position")))

    declared = {n for n in nat_names + ban_names + int_names if n}
    missing = sorted(n for n in ads_used if n not in declared)
    if missing:
        fails.append("code dùng ad name chưa khai trong plist: " + ", ".join(missing))

    bad = sorted(n for n in declared if not re.fullmatch(r"[a-z][a-z0-9_]{0,39}", n))
    if bad:
        fails.append("ad name không hợp luật event Firebase: " + ", ".join(bad))

    print("ads:   %d native · %d banner · %d inter | code dùng %d"
          % (len(nat_names), len(ban_names), len(int_names), len(ads_used)))
    orphan = sorted(n for n in declared if n not in ads_used)
    if orphan:
        # Space intro do SDK tự gọi (splash, language, onboarding) không xuất hiện
        # trong code app — nên đây là thông tin, không phải lỗi.
        notes.append("ad name khai mà code app không gọi (SDK tự gọi, hoặc tên chết):\n   "
                     + ", ".join(orphan))

# ── iap_placement_config ────────────────────────────────────────────────────
raw = defaults.get("iap_placement_config")
if raw is None:
    print("iap:   không khai (app không có IAP)")
else:
    try:
        entries = json.loads(raw)
    except json.JSONDecodeError as e:
        print("❌ iap_placement_config không phải JSON hợp lệ: %s" % e)
        print("   mọi paywall sẽ rỗng, không chỉ một placement")
        sys.exit(1)

    if not isinstance(entries, list):
        fails.append("iap_placement_config phải là một JSON array")
        entries = []
    entries = [e for e in entries if isinstance(e, dict)]

    if any("placement" not in e for e in entries):
        # placement là key duy nhất bắt buộc: thiếu nó thì decode cả mảng throw,
        # và app mất toàn bộ paywall chứ không mất một cái.
        fails.append("có entry IAP thiếu key bắt buộc 'placement' — cả mảng sẽ decode trượt")

    names = [e["placement"] for e in entries if e.get("placement")]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        fails.append("placement IAP khai trùng: " + ", ".join(dup))

    known = set(names)
    aliases = set()
    # Placement là đích của một alias funnel thì không bao giờ được present trực
    # tiếp — nó chỉ giữ gói và screen_code cho những placement trỏ vào nó.
    alias_targets = {e["funnel"] for e in entries if e.get("funnel")}
    for e in entries:
        name = e.get("placement", "?")
        funnel = e.get("funnel")
        if funnel:
            aliases.add(name)
            # funnel là alias trỏ sang config của placement khác. Trỏ vào chỗ
            # không tồn tại thì entry này giữ config rỗng của chính nó -> paywall trắng.
            if funnel not in known:
                fails.append("placement %r có funnel %r không tồn tại" % (name, funnel))
            continue
        if not e.get("product_ids"):
            fails.append("placement %r không có product_ids và cũng không có funnel "
                         "→ paywall không có gói nào" % name)
        code = str(e.get("screen_code", "IAP1")).strip().upper()
        if screen_codes and code not in screen_codes:
            fails.append("placement %r dùng screen_code %r chưa registerIAPView" % (name, code))

    # Chắc: literal + symbol đứng ngay sau `placement:` → dùng để fail.
    used_sure = set(iap_literals)
    for m in iap_symbols:
        if m in constants:
            used_sure.add(constants[m])
    unknown = sorted(u for u in used_sure if u not in known)
    if unknown:
        fails.append("code mở placement IAP chưa khai trong plist: " + ", ".join(unknown))

    # Lỏng: mọi member dùng trong file có chữ placement → chỉ cho dòng thông tin.
    used_loose = set(used_sure)
    for m in iap_members:
        if m in constants and constants[m] in known:
            used_loose.add(constants[m])

    print("iap:   %d placement (%d alias funnel) | code mở %d | screen_code đã đăng ký: %s"
          % (len(names), len(aliases), len(used_loose),
             ", ".join(sorted(screen_codes)) or "không thấy"))

    unopened = sorted(n for n in known
                      if n not in used_loose and n not in aliases and n not in alias_targets)
    if unopened:
        notes.append("placement IAP khai mà chưa có điểm mở (kịch bản chưa dựng):\n   "
                     + ", ".join(unopened))
    alias_unopened = sorted(n for n in aliases if n not in used_loose)
    if alias_unopened:
        notes.append("alias funnel chưa có điểm mở:\n   " + ", ".join(alias_unopened))

for f_ in fails:
    print("❌ %s" % f_)
for n in notes:
    print("ℹ️  %s" % n)
sys.exit(1 if fails else 0)
PY
