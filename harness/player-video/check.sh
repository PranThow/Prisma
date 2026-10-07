#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -framework Foundation -I"$ROOT/tweak/Sources" \
    "$ROOT/harness/player-video/main.m" -o "$OUT/check"
"$OUT/check"
