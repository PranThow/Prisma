#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cc -std=c11 -Wall -Wextra -Werror -I"$ROOT/tweak/Sources" "$ROOT/harness/connect/main.c" -o "$OUT/check"
"$OUT/check"
