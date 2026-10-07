#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -framework Foundation -I"$ROOT/tweak/Sources" \
    "$ROOT/harness/canvas/main.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvas.m" \
    "$ROOT/tweak/Sources/Shared/Lyrics/Protobuf.m" -o "$OUT/check"
"$OUT/check"
sed '/^#import/d; /^static SGCanvasResolver \*sg_resolver/,$d' \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvasResolver.x" > "$OUT/resolver.inc"
xcrun clang -fobjc-arc -framework Foundation -I"$ROOT/tweak/Sources" -I"$OUT" \
    "$ROOT/harness/canvas/resolver.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AnimatedArtwork.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvas.m" \
    "$ROOT/tweak/Sources/Shared/Lyrics/Protobuf.m" -o "$OUT/resolver"
"$OUT/resolver"
