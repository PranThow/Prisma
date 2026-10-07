#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cc -std=c11 -Wall -Wextra -I"$ROOT/tweak/Sources" "$ROOT/harness/player-policy/main.c" -lm -o "$OUT/check"
"$OUT/check"
