#!/usr/bin/env bash
#
# Fails the build on the layering rules the compiler cannot express.
#
# The dependency graph in Package.swift already stops a feature from *linking*
# against Data. What it cannot stop is a file importing something its layer
# should not know about, or a colour literal appearing in a screen. Those are
# the rules below. A rule that is not checked here rots — this repo exists
# partly because a rule file that disagreed with its own source tree is how the
# previous base project drifted.
#
# Usage:  ./tools/check-arch.sh
# Exit 0 = clean, 1 = at least one violation.

set -uo pipefail
cd "$(dirname "$0")/.."

SRC="Packages/AppModules/Sources"
failures=0

fail() {
  printf '\033[31m✗\033[0m %s\n' "$1"
  shift
  printf '    %s\n' "$@"
  failures=$((failures + 1))
}

pass() {
  printf '\033[32m✓\033[0m %s\n' "$1"
}

# Prints matching "file:line: text" for a pattern over a path, or nothing.
scan() {
  local pattern="$1" path="$2"
  [ -d "$path" ] || return 0
  grep -rnE "$pattern" --include="*.swift" "$path" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 1. Domain is pure Swift.
#    The moment Domain imports SwiftUI or a networking package, "the business
#    rules do not depend on delivery" stops being true and the tests get slow.
# ---------------------------------------------------------------------------
hits=$(scan '^import (SwiftUI|UIKit|KVNetworkit|KVRouterKit|KVRouterCore|KVDIKit|KVToastKit)' "$SRC/Domain")
if [ -n "$hits" ]; then
  fail "Domain imports a delivery framework" "$hits"
else
  pass "Domain imports nothing but Foundation"
fi

# ---------------------------------------------------------------------------
# 2. Features never see Data.
#    A feature that reaches for a concrete repository has skipped the protocol
#    that makes it testable, and has coupled a screen to a wire format.
# ---------------------------------------------------------------------------
hits=$(scan '^import Data$' "$SRC/FeatureOrder" "$SRC/FeatureAuth")
for dir in "$SRC"/Feature*; do
  hits="$hits$(scan '^import Data$' "$dir")"
done
if [ -n "$hits" ]; then
  fail "A feature imports Data" "$hits"
else
  pass "No feature imports Data"
fi

# ---------------------------------------------------------------------------
# 3. ViewModels do not push views.
#    `pushView { }` lives on KVViewRouting, which only KVRouterKit exposes.
#    A ViewModel that builds a view cannot be unit-tested against KVRouterSpy
#    and has moved a presentation decision into the model layer.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if grep -qE '^import KVRouterKit$' "$file"; then
    hits="$hits$file: imports KVRouterKit (use KVRouterCore)\n"
  fi
  if grep -qE '(^|[^A-Za-z])pushView\(' "$file"; then
    hits="$hits$file: calls pushView (that belongs in the View)\n"
  fi
done < <(find "$SRC" -name "*ViewModel.swift" 2>/dev/null)
if [ -n "$hits" ]; then
  fail "ViewModel reaches into the view layer" "$(printf "$hits")"
else
  pass "ViewModels use KVRouterCore only"
fi

# ---------------------------------------------------------------------------
# 4. No colour literals outside DesignSystem.
#    A hard-coded colour cannot be restyled, has no dark variant, and is
#    invisible to whoever regenerates tokens from Figma.
# ---------------------------------------------------------------------------
hits=""
for dir in "$SRC"/Feature* App; do
  hits="$hits$(scan 'Color\((red:|#colorLiteral|hex:)' "$dir")"
done
if [ -n "$hits" ]; then
  fail "Colour literal outside DesignSystem" "$hits"
else
  pass "All colours come from DesignSystem"
fi

# ---------------------------------------------------------------------------
# 5. KVAPIClientError does not escape Data.
#    It is mapped to AppError at the repository boundary. A ViewModel switching
#    on a transport error is a ViewModel that breaks when the transport changes.
# ---------------------------------------------------------------------------
hits=""
for dir in "$SRC"/Feature* "$SRC/Domain" App; do
  hits="$hits$(scan 'KVAPIClientError' "$dir")"
done
if [ -n "$hits" ]; then
  fail "KVAPIClientError leaked out of Data" "$hits"
else
  pass "Only AppError crosses layer boundaries"
fi

# ---------------------------------------------------------------------------
# 6. Child views take values, not the ViewModel.
#    On iOS 16 `ObservableObject` invalidates per object, so a child holding the
#    ViewModel re-renders on every unrelated change. Passing a value lets
#    SwiftUI skip the subtree — this is the whole iOS 16 performance strategy.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  case "$(basename "$file")" in
    *ViewModel.swift) continue ;;
  esac
  # A screen owns its ViewModel with @StateObject — that is the allowed case.
  # Anything else holding one (@ObservedObject, or a plain stored property) is a
  # child view that should have been handed values instead.
  found=$(grep -nE '(@ObservedObject|(let|var) +[a-zA-Z]+ *: *[A-Z][A-Za-z]*ViewModel)' "$file" \
    | grep -v '@StateObject' || true)
  [ -n "$found" ] && hits="$hits$file:\n$found\n"
done < <(find "$SRC" -name "*.swift" 2>/dev/null)
if [ -n "$hits" ]; then
  fail "A child view holds a ViewModel instead of values" "$(printf "$hits")"
else
  pass "Child views take values, not ViewModels"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf '\033[31m%d architecture rule(s) violated.\033[0m\n' "$failures"
  exit 1
fi
printf '\033[32mArchitecture rules OK.\033[0m\n'
