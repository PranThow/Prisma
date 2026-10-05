#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -framework Foundation -I"$ROOT/tweak/Sources" \
    "$ROOT/harness/animated-artwork/main.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AnimatedArtwork.m" -o "$OUT/check"
"$OUT/check"
sed '/^#import/d; /^%hook/,$d' \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AnimatedArtworkPublisher.x" > "$OUT/publisher.inc"
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics -I"$ROOT/tweak/Sources" -I"$OUT" \
    "$ROOT/harness/animated-artwork/publisher.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/AnimatedArtwork.m" \
    "$ROOT/tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvas.m" \
    "$ROOT/tweak/Sources/Shared/Lyrics/Protobuf.m" -o "$OUT/publisher"
"$OUT/publisher"
