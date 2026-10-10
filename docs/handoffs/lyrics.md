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

## L01 - Validate the independent provider client

- Changed files: `harness/audio-lyrics/check.py`.
- Result: The existing Spicy Lyrics client remains unchanged. The focused regression now verifies its publishable-key and rejection guards, redirect and 2 MiB response limits, stale-key suppression, 429/5xx exponential backoff with Retry-After, no URL cache, and the shared bounded 24-hour lyrics cache.
- Checks: `git fetch origin && git merge origin/main` (already up to date); `python harness/audio-lyrics/check.py` (passed Spicy request lifecycle, source extraction and compatibility guards on Windows); `python -m py_compile harness/audio-lyrics/check.py` (passed); `git diff --check` (passed).
- Remaining blocker: the Objective-C parser assertions and NSURLSession behavior require macOS/Foundation and have not run on this Windows host.
- Required macOS and device checks: run `python3 harness/audio-lyrics/check.py` on macOS; on device, test valid, rejected and missing keys; malformed/oversize and 429/offline responses; then replace a track during a request and verify only that track's lyrics and linked credits appear.

## L02 - Validate provider ordering and credit propagation

- Changed files: `harness/audio-lyrics/check.py`; `docs/parity-checklist.md`; `docs/handoffs/lyrics.md`.
- Result: Existing provider-order normalization rejects unknown and duplicate keys, preserves enabled ordering for the walk, and keeps the winning linked attribution through the bounded cache and karaoke lines. Credits that require links remain withheld from Lock Screen and Live Activity, which cannot display them.
- Checks: `python harness/audio-lyrics/check.py` (passed source extraction, provider-order/attribution and compatibility guards on Windows); `python -m py_compile harness/audio-lyrics/check.py` (passed); `git diff --check` (passed).
- Blockers: Objective-C runtime assertions require macOS/Foundation; source checks do not prove the UI presentation or provider network behavior.
- Required macOS and device checks: run `python3 harness/audio-lyrics/check.py` on macOS; on device, reorder/disable sources and verify the winning provider's linked credit in Native and Redesigned lyrics, while Lock Screen and Live Activity show no restricted lyrics.
- Integration request: none.

## L03 - Validate linked credits in both lyrics looks

- Changed files: `docs/parity-checklist.md`; `docs/handoffs/lyrics.md`; `.lane-commit-msg`.
- Result: No production change was needed. Native's `SGLyricsCreditView` and Redesigned's `SGRKaraokeView` both render the winning attributed credit in selectable `UITextView`s, preserving provider, catalogue and contributor links. The sole external linked-credit producer rejects malformed contributor data and allows only HTTPS URLs without credentials. Spicy Lyrics' current attribution terms require the provider and, for community syncs, linked uploader and maker wherever lyrics appear; Prisma's in-memory cache is within its 30-day maximum. Unrelated community/donation links remain absent.
- Checks: `python harness/audio-lyrics/check.py` (passed source extraction, attribution propagation and compatibility guards on Windows); `python -m py_compile harness/audio-lyrics/check.py` (passed); `git diff --check` (passed).
- Blockers: none for the source-level validation. The Windows checks cannot exercise UIKit link activation or VoiceOver.
- Required macOS and device checks: run `python3 harness/audio-lyrics/check.py` on macOS; on an iOS device, verify provider, catalogue, uploader and optional maker links are visible, open their HTTPS destinations and are announced/actionable by VoiceOver in Native lyrics card/full screen and Redesigned karaoke. Also verify missing/malformed provider credits show no empty or unsafe link.
- Integration request: none.

## F02 - Retry lyrics after a background track change

- Changed files: `tweak/Sources/Shared/Lyrics/KaraokeSource.x`; `harness/audio-lyrics/check.py`; `docs/parity-checklist.md`; `docs/handoffs/lyrics.md`; `.lane-commit-msg`.
- Result: On foregrounding (and refreshed Spotify authorization), the karaoke observer now reads the player's current state before the last published state, so a background A-to-B change requests B rather than stale A. Empty successful Spotify lyrics replies clear their request marker, allowing that foreground pass to retry; in-flight/current-track guards still prevent duplicate A-to-B-to-A requests.
- Checks: `python harness/audio-lyrics/check.py` (passed source extraction and foreground/empty-reply guards on Windows); `python -m py_compile harness/audio-lyrics/check.py` (passed); `git diff --check` (passed).
- Blockers: Windows cannot execute the Objective-C runtime assertions or build the tweak.
- Required macOS and device checks: run `python3 harness/audio-lyrics/check.py` on macOS; on device, background during A-to-B, foreground and verify only B is requested/displayed; repeat A-to-B-to-A rapidly and verify no duplicate observers or stale lyric display; return an empty successful lyrics response, foreground, and verify one retry.
- Integration request: none.
