#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -framework Foundation -framework AVFoundation -framework CoreGraphics \
    -framework CoreVideo -framework CoreMedia -framework ImageIO -I"$ROOT/tweak/Sources" \
    "$ROOT/harness/artwork-video/main.m" -o "$OUT/check"
"$OUT/check"
