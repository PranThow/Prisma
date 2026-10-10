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
