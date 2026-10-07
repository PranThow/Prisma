#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -I"$ROOT/tweak/Sources" "$ROOT/harness/update/versions.m" -framework Foundation -o "$OUT/versions"
"$OUT/versions"
