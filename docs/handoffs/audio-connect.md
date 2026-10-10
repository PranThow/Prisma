# Audio and Connect handoffs

## D04 — preserve independent pitch across coupled toggles

- Changed `tweak/Sources/Shared/Player/SpeedPitch.x` and `harness/speed/main.m`.
- Enabling **Pitch follows speed** now leaves the independent pitch value intact. The coupled path still applies zero semitones; disabling the setting restores the prior independent value.
- `python harness/packaging/check.py` passed. `git diff --check` passed.
- `python harness/connect/check-sockets.py` could not run because this Windows host has no POSIX C compiler. The iOS simulator speed harness also requires macOS/Xcode; run `THEOS=$HOME/theos sh harness/speed/build.sh` and launch it on a booted simulator.

## D01-D03 and C01/C03 — routing and discovery review

- Confirmed the only `SGAudioRegister` users occupy the defined speed, effects and haptics stages; the lifecycle owner keeps separate output slots and render locks. No production routing change was needed.
- Kept Bonjour's eight-address bound, but now skips a malformed address and continues to later valid addresses for that service. The previous loop stopped at the first short address, which could hide an otherwise valid Connect or Cast device.
- `git diff --check` and Python syntax compilation for the socket harness passed. This Windows host has neither a POSIX shell nor C compiler, so `harness/connect/check.sh`, `harness/connect/check-sockets.py` and the macOS audio-routing harness remain pending.
