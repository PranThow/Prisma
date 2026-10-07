#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -framework Foundation -framework VideoToolbox -I"$ROOT/tweak/Sources" \
    "$ROOT/harness/apple-music-artwork/main.m" \
    "$ROOT/harness/apple-music-artwork/network.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AppleMusicArtwork.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AppleMusicArtworkResolver.m" -o "$OUT/check"
"$OUT/check"
