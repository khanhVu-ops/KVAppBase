#!/usr/bin/env bash
#
# Sinh lại project khi có file Swift MỚI, và chỉ khi đó.
#
# Đây là cái bẫy hay gặp nhất của layout một app target: file mới ở bất kỳ folder
# nào cũng không có trong project cho tới khi `xcodegen generate` chạy lại, và
# triệu chứng là "code có đó mà compiler bảo không tìm thấy" — một câu đố tốn vài
# phút mỗi lần, lặp lại mãi. Sửa bằng hạ tầng thì không phải nhớ nữa.
#
# Dùng như PostToolUse hook cho Write|Edit (xem .claude/settings.json): nhận JSON
# của hook trên stdin. Cũng chạy tay được để thử: ./tools/xcodegen-if-needed.sh <path>
#
# Im lặng và exit 0 ở mọi nhánh "không cần làm gì". Một hook ồn ào sẽ bị tắt, và
# một hook làm hỏng tool call thì tệ hơn cái bẫy nó chống.

set -uo pipefail

if [ "$#" -gt 0 ]; then
    file="$1"
else
    # perl thay vì jq: jq không có sẵn trên macOS, perl thì luôn có.
    file="$(perl -0ne 'print $1 if /"file_path"\s*:\s*"((?:[^"\\]|\\.)*)"/' | perl -pe 's/\\(.)/$1/g')"
fi

case "$file" in
    *.swift) ;;
    *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" 2>/dev/null || exit 0
[ -f project.yml ] || exit 0

project="$(ls -d ./*.xcodeproj 2>/dev/null | head -1)"

# File đã nằm trong project rồi thì đây là một lần sửa, không phải file mới —
# generate lại chẳng đổi gì mà tốn một giây mỗi lần Edit.
if [ -n "$project" ] && grep -qF "$(basename "$file")" "$project/project.pbxproj" 2>/dev/null; then
    exit 0
fi

command -v xcodegen >/dev/null || {
    printf '{"systemMessage":"%s có file Swift mới nhưng chưa cài xcodegen — brew install xcodegen rồi chạy xcodegen generate"}\n' \
        "$(basename "$file")"
    exit 0
}

if xcodegen generate --quiet 2>/dev/null; then
    printf '{"systemMessage":"xcodegen generate: %s đã vào project"}\n' "$(basename "$file")"
else
    printf '{"systemMessage":"xcodegen generate thất bại sau khi thêm %s — chạy tay để xem lỗi"}\n' \
        "$(basename "$file")"
fi
