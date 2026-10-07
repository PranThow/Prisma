<p align="center">
  <img src="docs/icon.png" width="96" alt="Prisma project icon">
</p>

<h1 align="center">Prisma</h1>

<p align="center">A fresh look for Spotify on iOS. Open source, yours to build.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Spotify-9.1.78-1ED760?style=for-the-badge&logo=spotify&logoColor=white" alt="Spotify 9.1.78">
  <img src="https://img.shields.io/badge/Native-iOS_16.1+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Native look requires iOS 16.1 or newer">
  <img src="https://img.shields.io/badge/Liquid_Glass-iOS_26+-3A95E3?style=for-the-badge&logo=apple&logoColor=white" alt="Liquid Glass redesign requires iOS 26 or newer">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL_v3-blue?style=for-the-badge" alt="GPL v3 license"></a>
</p>

<p align="center">
  <a href="https://github.com/PranThow/Prisma/releases">Releases</a> &middot;
  <a href="#build-prisma">Build Prisma</a> &middot;
  <a href="docs/tweaks.md">Development guide</a> &middot;
  <a href="https://github.com/PranThow/Prisma/issues">Issues</a>
</p>

<p align="center">
  <img src="docs/screenshots/now-playing.webp" width="16%" alt="Full-screen player with lyrics">
  <img src="docs/screenshots/album.webp" width="16%" alt="Album page">
  <img src="docs/screenshots/playlist.webp" width="16%" alt="Playlist page">
  <img src="docs/screenshots/queue.webp" width="16%" alt="Playback queue">
  <img src="docs/screenshots/live-activity.webp" width="16%" alt="Live Activity on the lock screen">
  <img src="docs/screenshots/home.webp" width="16%" alt="Home page">
</p>

Prisma is an independent, GPL v3 fork of **spoti.pw**, based on its GPL-licensed source. It brings a Liquid Glass redesign and extra customization to Spotify on iOS through an Objective-C and Logos tweak built with Theos. No jailbreak is required: build it into your own decrypted Spotify IPA, then sign and sideload it.

This fork gives that open-source foundation a new home and identity, with credit to the original project's work.

## What Prisma brings

Choose your look in **Settings > Mod Settings > Appearance**:

- **Native:** keep Spotify's own interface and customize it with glass header buttons, a Home gradient, AMOLED backgrounds, accent colors, and controls for hiding clutter.
- **Redesigned:** a Liquid Glass interface with a glass tab bar, search field and now playing bar; a redesigned player; Apple Music-style lyrics; cleaner Home, Search and Library screens; and reworked playlist, album and artist pages.

Both looks include lyrics sources, lock-screen lyrics, player gestures, blocked artists, privacy controls, feature flags, vibrations, audio effects, speed and pitch controls, and Live Activity support. Most settings require a restart; some, including vibrations and Live Activity, apply immediately.

## Compatibility

The inherited implementation targets **Spotify 9.1.78**; Prisma changes still need a full device build and verification. Use a decrypted IPA of that version. Spotify's internal classes change between releases, so other versions may build successfully but fail at runtime.

| Feature | Minimum iOS version |
|---|---|
| Native look | iOS 16.1 |
| Liquid Glass redesign | iOS 26 |
| Live Activity | iOS 17 |
| Animated lock-screen artwork (either look) | iOS 26 and supported MediaPlayer artwork keys |

Below iOS 26, Prisma uses the native look and disables the redesign switch. Live Activity also requires a build that includes its widget extension.

Animated artwork is off by default. Open **Mod Settings > Player > Lock screen widget**, enable
**Animated artwork**, then use **Artwork providers** to toggle providers and drag their priority.
Spotify Canvas comes before Apple Music by default; unavailable or failed clips fall through to the
next enabled provider. Artwork settings apply immediately. Apple Music uses album motion artwork
from the US catalog, with an undocumented guest authorization route that can stop working.
The system controls whether animation plays; static artwork remains when no usable clip is found.
See the [requirements, provider behavior and validation limits](docs/tweaks.md#animated-lock-screen-artwork).

## Known CI failures (2026-10-07)

The checks for commit `2032933` reported **four failures, six successes and one skipped job**.
These issues remain unfixed; the full iOS build and device behavior are still unverified.

| Failed check | Error from the logs | Follow-up |
|---|---|---|
| `apple-music-artwork` | The local `decimal` helper conflicts with the macOS SDK's `decimal` typedef after importing VideoToolbox. | Rename the helper and its callers, then rerun the harness. |
| `audio-routing` | `kAudioUnitSubType_RemoteIO` is unavailable in the macOS SDK used to compile the mocked iOS audio test. | Make the test's RemoteIO subtype available without changing production iOS behavior. |
| `player-video` | `assert` interprets commas in Objective-C array literals as extra macro arguments. | Add parentheses around the affected assertion expressions, then rerun the harness. |
| `release-please` | Release automation stopped with `other side closed` while fetching commit history. | Retry the workflow before changing release configuration; the log indicates a closed network connection. |

See the [repository-check logs](https://github.com/PranThow/Prisma/actions/runs/37631984617)
and [release log](https://github.com/PranThow/Prisma/actions/runs/37631984745).
The `.deb` job was skipped because Release Please failed before creating a release; no package
build ran in that job. After addressing the three compile errors, rerun CI and review any further
test failures before treating the implementation as validated.

## Build Prisma

This repository does not distribute Spotify IPAs. Supply your own decrypted **Spotify 9.1.78** IPA and sign the resulting build with your own certificate or sideloading tool.

### With GitHub Actions

1. Fork [PranThow/Prisma](https://github.com/PranThow/Prisma) and enable GitHub Actions in your fork.
2. Open **Actions > Build IPA from your own Spotify IPA > Run workflow**.
3. Enter a direct download link to your decrypted IPA.
4. Choose **artifacts** as the upload method, then download the built IPA from the completed workflow run.
5. Sign and sideload the IPA.

No Mac is needed for this workflow. It also offers a Filebin upload option if you choose to upload the result there.

### On a Mac

Install Theos in `~/theos` and select Xcode with an iPhoneOS 26 or newer SDK using `xcode-select`. A standalone SDK in `~/theos/sdks` can build the tweak, but without the Live Activity extension.

Install the build tools:

```sh
brew install make ldid dpkg zsign ideviceinstaller libimobiledevice
uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"
```

Place your decrypted IPA in `ipa/`, then run:

```sh
make release    # Unsigned IPA in out/Prisma-<version>.ipa
make install    # Sign and install over USB; output is out/Prisma-dev.ipa
```

For `make install`, copy `.signing.env.example` to `.signing.env` and set `SIGN_P12`, `SIGN_PROFILE`, and `SIGN_P12_PASSWORD`. Local installs use Prisma as the display name; set `DEV_NAME` to override it.

The first build extracts Spotify's feature flags from your IPA. Run `make flags` to regenerate them.

### Signing and installation

Sign with a bundle identifier matching your certificate's App ID. A mismatch can prevent lock-screen player taps from opening the app; the mod shows a warning on first launch with the identifier to use.

In Feather, enter the App ID in **Identifier** and leave **PPQ protection** off. You can also sign with tools such as SideStore, AltStore, or Sideloadly.

The build retains Spotify's bundle identifier before signing. Installing it with that identifier replaces the existing Spotify app.

## Contributing

Bug reports and contributions belong in [Prisma's issues](https://github.com/PranThow/Prisma/issues) and pull requests. For a bug report, include your iOS version, Spotify version, Prisma build version, chosen look, and steps to reproduce it.

Read the [development guide](docs/tweaks.md) before changing code. It covers the source layers, view-tree inspection, build targets, and known pitfalls. Native and redesigned UI changes belong in their respective layers; behavior shared by both belongs in `Shared/`.

Useful development commands:

```sh
make install FLEX=1    # Install with the view inspector
make session           # Record clean Spotify view trees
make log               # Stream the tweak's device logs
```

## Implementation status

The animated-artwork implementation and fixes below are present. Checked items mean code is
written, not that the iOS build or device behavior is verified.

- [x] Spotify Canvas resolver and Spotify authorization capture.
- [x] Apple Music album lookup, authorization, HLS resolution, and provider fallback.
- [x] Video downloading, cancellation, bounded caching, rotation/cropping, and preview generation.
- [x] iOS 26 MediaPlayer integration for both Native and Redesigned modes.
- [x] Animated-artwork switch and provider enable/disable/order settings.
- [x] Remove the temporary reset of the already-announced update preference.
- [ ] Complete macOS harness execution, iOS build validation, and iPhone integration testing.

### Artwork bug fixes

The six findings from the 2026-10-05 source review have code fixes and regression checks.
Native harness execution and device reproduction remain pending.

- [x] **Correct Canvas metadata keys (P1).**
  [SpotifyCanvas.m](tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvas.m) reads `canvas.url` and
  `canvas.type`. Fixtures cover video and image types; the resolver check covers late metadata
  canceling an in-flight service result. Real Spotify metadata still needs device validation.
- [x] **Preserve Spotify's animated artwork when Prisma artwork is disabled (P2).**
  [AnimatedArtwork.m](tweak/Sources/Shared/AnimatedArtwork/AnimatedArtwork.m) tracks Prisma objects
  by identity and removes only those objects, including stale objects from previous tracks.
  Incoming Spotify objects remain intact; the harness covers disabled mode with existing artwork.
- [x] **Withhold ambiguous clips for tracks sharing a title (P2).**
  [AnimatedArtworkPublisher.x](tweak/Sources/Shared/AnimatedArtwork/AnimatedArtworkPublisher.x)
  requires the external content identifier to match the current track URI as well as the title.
  Without that identifier, Prisma withholds its clip. Checks cover metadata arriving before player
  state, missing identifiers, and old metadata after player state changes.
- [x] **Allow bounded recovery after transient Canvas failures (P2).**
  [SpotifyCanvasResolver.x](tweak/Sources/Shared/AnimatedArtwork/SpotifyCanvasResolver.x) retries
  network errors, 429 and server failures at most twice with unchanged credentials, after two and
  four seconds. Confirmed misses remain suppressed; changed credentials can start a fresh attempt.
- [x] **Invalidate failed cached Apple clip URLs (P2).**
  [AppleMusicArtworkResolver.m](tweak/Sources/Shared/AnimatedArtwork/AppleMusicArtworkResolver.m)
  evicts the current cached clip after preparation fails. The publisher allows one refreshed
  lookup before continuing fallback; successful cached clips remain reusable.
- [x] **Recover an exhausted provider chain on the same track (P2).**
  [AnimatedArtworkPublisher.x](tweak/Sources/Shared/AnimatedArtwork/AnimatedArtworkPublisher.x)
  retries failed chains at most twice, after five and thirty seconds or Apple's longer cooldown.
  Pending requests, successful artwork and confirmed misses stay unchanged. Input changes reset
  the retry budget and invalidate old callbacks.

### Remaining upstream parity differences

These are current limitations or product choices, separate from the bugs above.

- [ ] **HEVC artwork:** HLS selection currently accepts AVC only; upstream prefers HEVC. HEVC-only
  motion artwork is unavailable until supported variants can be selected and validated.
- [ ] **Collaborative-artist matching:** exact normalized artist equality can miss albums where
  Spotify names one artist and Apple credits several. Add matching that recognizes those credits
  without accepting unrelated artists.
- **Alternate editions:** Prisma deliberately stops at an exact edition without motion artwork;
  upstream can use another edition that has animation. Decide whether to keep this stricter behavior.
- **Clip size:** Prisma's 32 MiB download cap excludes some clips upstream accepts. Adjust only if
  needed, keeping bounded downloads and cache usage.
- **Default:** artwork is off by default in Prisma and on by default upstream.

### Verification still required

- [ ] Run `sh harness/animated-artwork/check.sh`, `sh harness/canvas/check.sh`,
  `sh harness/artwork-video/check.sh`, and `sh harness/apple-music-artwork/check.sh` on macOS.
  All four stop at `xcrun: command not found` in the reviewed Windows workspace.
- [ ] Exercise the real lock-screen lyrics integration in both MediaPlayer hook orders. The
  publisher harness currently stubs both lyrics integration functions to return `NO`.
- [x] Add all four native artwork harnesses to the macOS job in
  [repository checks](.github/workflows/checks.yml). CI execution is still pending.
- [ ] Complete the [iPhone integration checklist](docs/tweaks.md#animated-lock-screen-artwork-device-checks),
  including rapid skips, offline recovery, provider changes, and lock-screen rendering.

Layer checks, shell syntax checks for all four new harnesses, and `git diff --check` passed during
review. Native compilation and execution remain unverified.

## AI disclosure

AI tools are used to help write documentation, review code, and implement changes in Prisma. This includes the fork's initial documentation, branding, and removal of donation prompts and upstream usage reporting. The inherited implementation and screenshots come from the original project; they are not presented as new work by Prisma.

AI assistance does not establish correctness. Build and device testing are still needed, and the maintainer is responsible for the changes shipped in each release.

## Credits and license

Prisma builds on the GPL v3 version of [spoti.pw](https://github.com/skopevoj/spoti.pw) by skopevoj and its contributors. The original implementation and screenshots are inherited from that project.

- [Theos](https://theos.dev) builds the tweak.
- [cyan](https://github.com/asdfzxcvbn/pyzule-rw) injects it into the IPA.
- [FLEX](https://github.com/FLEXTool/FLEX), through hopeless's AutoFLEX build in `vendor/`, provides the view inspector.
- The lyrics hook follows [EeveeSpotify Reincarnated](https://github.com/SideloadLabs/EeveeSpotifyReincarnated).
- Third-party audio components and their licenses are documented in [vendor/audio/README.md](vendor/audio/README.md).

Prisma is licensed under the [GNU General Public License v3](LICENSE). Existing copyright and attribution notices are retained.

Prisma is an independent project and is not affiliated with or endorsed by Spotify.
