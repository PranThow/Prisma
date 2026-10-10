## F01 — Keep serialized lyric starts nondecreasing

- Changed files: none. The implementation and focused regression already landed in `2032933`.
- Result: `pageBody` retains equal starts and clamps every later start to its predecessor, so serialized lyric starts cannot move backward.
- Checks: `git fetch origin && git merge origin/main` (already up to date); `python harness/audio-lyrics/check.py` (passed source extraction and serialization guard on Windows).
- Remaining blocker: the Objective-C serialization assertions in that harness require macOS/Foundation and have not run on this Windows host.
- Required device checks: none for this serialization-only fix; macOS runtime harness execution remains required before treating it as runtime-verified.
