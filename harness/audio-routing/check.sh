#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
# The macOS mock uses RemoteIO's 'rio ' subtype, which its SDK does not declare.
xcrun clang -fobjc-arc -fblocks -I../../tweak/Sources -framework Foundation -framework AudioToolbox \
    -DkAudioUnitSubType_RemoteIO=0x72696f20 \
    main.m ../../tweak/Sources/Core/SGAudioRouting.m -o build/check
build/check
