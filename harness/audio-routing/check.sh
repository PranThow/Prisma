#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
xcrun clang -fobjc-arc -fblocks -I../../tweak/Sources -framework Foundation -framework AudioToolbox \
    main.m ../../tweak/Sources/Core/SGAudioRouting.m -o build/check
build/check
