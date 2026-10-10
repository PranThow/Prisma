# Audio and Connect handoffs

## D04 — preserve independent pitch across coupled toggles

- Changed `tweak/Sources/Shared/Player/SpeedPitch.x` and `harness/speed/main.m`.
- Enabling **Pitch follows speed** now leaves the independent pitch value intact. The coupled path still applies zero semitones; disabling the setting restores the prior independent value.
- `python harness/packaging/check.py` passed. `git diff --check` passed.
- `python harness/connect/check-sockets.py` could not run because this Windows host has no POSIX C compiler. The iOS simulator speed harness also requires macOS/Xcode; run `THEOS=$HOME/theos sh harness/speed/build.sh` and launch it on a booted simulator.
