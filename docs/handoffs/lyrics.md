## F01 — Keep serialized lyric starts nondecreasing

- Changed files: none. The implementation and focused regression already landed in `2032933`.
- Result: `pageBody` retains equal starts and clamps every later start to its predecessor, so serialized lyric starts cannot move backward.
- Checks: `git fetch origin && git merge origin/main` (already up to date); `python harness/audio-lyrics/check.py` (passed source extraction and serialization guard on Windows).
- Remaining blocker: the Objective-C serialization assertions in that harness require macOS/Foundation and have not run on this Windows host.
- Required device checks: none for this serialization-only fix; macOS runtime harness execution remains required before treating it as runtime-verified.

## F03 — Suppress competing external lyrics hooks

- Changed files: `harness/audio-lyrics/check.py`.
- Result: `spotifyglass.externalLyricsReplacement`, read at launch by `SGLyricsEnabled()`, prevents the reply/donor/metadata hooks from initializing and makes the lyrics flag forcer return no override. The shared karaoke observer remains available for Spotify's own lyrics when the redesign or lock-screen lyrics needs it.
- Checks: `git fetch origin && git merge origin/main` (already up to date); `python harness/audio-lyrics/check.py` (passed source extraction and compatibility guard checks on Windows).
- Remaining blocker: automatic Eevee detection has no independent evidence and remains intentionally unsupported; users must enable the compatibility setting and restart.
- Required device checks: restart with sources enabled, then with compatibility enabled; verify the external tweak's lyrics and the normal Spotify flag/card behavior are untouched in both looks.
