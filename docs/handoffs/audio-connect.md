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

## D01 — blocked on macOS validation (2026-10-10)

- Selected D01 first in lane order: the claim table and previous handoff record a review, not completed harness acceptance. No later lane task was undertaken.
- Exact changed file: `docs/handoffs/audio-connect.md`. Production behavior is unchanged; no new regression is needed before running the existing ordered-stage and nested-output assertions in `harness/audio-routing/main.m`.
- Commands/results: initial `git fetch origin` failed because the sandbox cannot write external worktree metadata; the authorized elevated retry of `git fetch origin` followed by `git merge origin/main` succeeded (`Already up to date`). `git branch --show-current` confirmed `emdash/audio-connect-mopam`; initial `git status --short` was clean. Read the required instructions/status/handoff and the audio-routing harness. `rg -n SGAudioRegister` across Core, Shared Player, AudioEffects and Haptics identifies the existing speed/effects/haptics registrations. `[bool](Get-Command xcrun -ErrorAction SilentlyContinue)` returned `False`; an earlier `Test-Path` probe failed on the absent command's null path. `git diff --check` passed before commit.
- Blocker: `harness/audio-routing/check.sh` invokes `xcrun clang` and links Foundation/AudioToolbox. This Windows host cannot execute that Apple SDK harness or establish D01 acceptance. Stop here under the assignment's macOS blocker rule; no production files reserved or edited.
- macOS checks owed: `sh harness/audio-routing/check.sh`, then `env -u MAKELEVEL gmake -C tweak clean package`. Confirm stage ordering, separate output state, nested rendering and bounded source pulls; do not treat the prior source review as execution evidence.
- Device checks owed (Q03): Spotify 9.1.78 in both looks, local files at 44.1/48 kHz, multiple outputs/routes and speed/effects/haptics combinations; verify no duplicate processing and record latency/performance. No Sing stage is claimed.
