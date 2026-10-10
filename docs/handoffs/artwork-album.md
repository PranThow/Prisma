# Artwork and album handoff

## Checked tasks

- **A01:** `AppleMusicArtwork.m` selects HEVC only when `VTIsHardwareDecodeSupported` reports support; AVC remains accepted and HDR, malformed codecs, and oversize variants are rejected.
- **A02:** credited artists are normalized and compared as complete sorted sets; the existing fixture covers reordered collaborators and rejects missing, extra, duplicate, and partial credits.
- **A03:** exact-edition precedence, constrained edition suffixes, CDN-only URLs, bounded HLS parsing, and clip limits are present in the existing implementation and fixtures.
- **A04:** existing resolver/preparer code retains cancellation, generation guards, provider ordering, constrained-network requests, and cache leases. Full mocked execution requires macOS.
- **A05:** the existing publisher harness covers metadata preservation and animated-artwork preference behavior; full execution requires macOS.
- **H01:** `AlbumMotion.inc` owns an independent Apple resolver/preparer, artist/album identity, and generation counter. A browsed album cannot replace current-track artwork.
- **H02:** the album hero pauses and hides offscreen, in background, Low Power Mode, or Reduce Motion; it keeps the static hero while motion is unavailable and releases stale results on identity changes.
- **H03:** the Redesigned Albums page exposes the separate `spotifyglass.redesign.album.animatedArtwork` setting. `App/Pages.m` selects it only in Redesigned mode.

`E01`–`E03` were not checked in this handoff.

## Entity-page follow-up

- **E01:** `SGRArtworkField` increments a generation for every palette request and drops stale completions. `SGRFinishEntityPage` keeps header and body hidden until both content and artwork are available, then reveals them together; its one-second fallback handles missing or slow content.
- **E02 (album):** `AlbumHeader.x` follows the live cover image, including a late image after the first layout pass, and passes that same image to the field. The album reveal uses `SGRHeaderInfo` content readiness plus the header artwork check. Reused list/footer cells restore their normal state in `prepareForReuse`.
- **E03:** Creator portraits are copied only from available circular images and are refreshed through the current creator control, so a reused header cannot retain an old portrait. The entity fade is noninteractive, inaccessible, and sized from the current safe-area bottom inset.

No production change was needed: the existing implementation meets the source-level criteria. The seven focused source-contract assertions and `scripts/check-layers.sh tweak/Sources` passed on Windows. The macOS album harness and iOS 26 device checks remain required for timing, real reuse, scrolling, and safe-area behavior.

## Commands run

```text
git fetch origin && git merge origin/main
# Result: Already up to date.

git diff --check
# Result: passed.

scripts/check-layers.sh tweak/Sources
# Run through C:\Program Files\Git\bin\bash.exe; result: passed (no output).

Artwork and album source invariants PowerShell check
# Result: passed.

harness/apple-music-artwork/check.sh
harness/animated-artwork/check.sh
harness/artwork-video/check.sh
# Run through Git Bash; each stopped before compilation: xcrun: command not found.
```

## Device and macOS checks still needed

- Run `harness/animated-artwork/check.sh`, `harness/canvas/check.sh`, `harness/artwork-video/check.sh`, and `harness/apple-music-artwork/check.sh` on macOS.
- Build the album simulator harness (`harness/album/build.sh`) and verify the static fallback, delayed artwork, reuse/navigation, and footer/header layout.
- On Spotify 9.1.78 with Redesigned UI on iOS 26, verify album B motion while track A remains current, background/offscreen return, Low Power/Low Data/Reduce Motion behavior, provider failure, and rapid album navigation.
