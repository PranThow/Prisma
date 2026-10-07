# Prisma parity implementation status

This records the independent implementation of `prisma-spoti-0.23-parity.md` on 2026-10-07.
Source changes and regression checks are present; **iOS compilation and device parity are not
established**. Three agents implemented player/artwork, navigation/entity pages, and audio/lyrics;
the integration owner handled App settings, packaging, update channels and discovery.

Inputs were existing Prisma code, public platform/provider documentation, and the user-supplied
decrypted Spotify 9.1.78 IPA. No additional original-project code, history, binaries or assets
were retrieved. The main executable reports UUID `C712370B-44CD-35C8-A058-4FBED1AD0758` and
`cryptid = 0`. Local executable/framework extractions stay under ignored `out/parity-evidence/`.
`scripts/inspect-objc.py` reads class/selector/type associations from that binary; it does not
establish Swift-only method contracts or actual screen layouts.

| Requirement | Source implementation / remaining limit |
| --- | --- |
| Fluid player background | Actual cover rendered through bounded Core Image warp/blur/color processing; live controls, preview, reset, preference migration and pause/motion/power behavior. Uses a serial renderer rather than a display link. |
| Video player background | Independent Canvas/Apple provider order, leased prepared files, looping, readiness/error fallback, cover transitions, playback/foreground/motion/power handling. Canvas registers visible consumers independently of lock-screen preferences. |
| Animated album headers | Browsed artist/album metadata uses its own resolver/preparer and player, with static fallback, offscreen stop and bounded retries. It does not overwrite current-track artwork. |
| Integrated mini-player | Optional redesigned Navbar accessory with cover/title/artist, playback, swipes, player opening and scroll minimization; first/last configured tabs flank the compact state. Touch forwarding and geometry need device checks. |
| Native system player menu | **Blocked.** The local binary exposes opaque Swift action/event models, not a verified action enumeration/refresh/presentation ABI. The real Spotify menu and Speed/pitch remain available; no guessed share/navigation actions were substituted. |
| Immersive lyrics/interactions | Four-second idle expansion, control fading, wake touch interception, playback/VoiceOver/foreground/sheet handling, thumbnail return and bounded RTL-aware tap seeking alongside drag seeking. |
| Add-tab editor | Separate Native and Redesigned name/link/icon sheets with preview and search; runtime enumeration of the locally proven Encore icon factories and a curated public SF Symbol list. |
| Entity visual finish | Coordinated reveal with a one-second loading fallback, cover main-color fields, available creator portraits and passive bottom fades. Uses existing page hooks and observed view identifiers. |
| Spicy Lyrics | User publishable key, validation/status/rejection, bounded requests, backoff, provider ordering, daily in-memory cache expiry and mandatory linked credits in both looks. Only the official documented Syllable payload is parsed; undocumented Line/Static and multiple backing-voice shapes fall through to other providers. |
| Connect/Cast discovery | System Bonjour discovers declared Connect/Cast services; a bounded mDNS socket bridge activates when imported multicast operations fail with entitlement errors. Per-socket random cookies guard private local envelopes, including descriptor reuse; replies preserve real service addresses. Cast's verified factory independently selects its system Bonjour implementation. Actual device discovery remains unverified. |
| Pitch follows speed | Default-on coupled varispeed switch; independent pitch controls disable while coupled, with separate time stretching when disabled. |
| Shared audio routing | One output lifecycle/render owner, ordered speed → effects → haptics, per-output processors/locks, bounded source pulls, source/bus changes, direct callback replacement, stop/disposal safety and local-file sample-rate correction. No Sing stage is claimed. |
| Sing vocal reduction | **Blocked.** The binary UUID is verified, but source-queue offsets/call signatures and streamed-source ownership are not. No licensed converted iOS model with verified hash/size/runtime/device budget has been established. No placeholder vocal-reduction control was added. |
| Alternate app icons | App selector, previews, three Prisma-owned eclipse variants and safe iPhone/iPad metadata/asset packaging. These are static PNG alternatives; layered Icon Composer Liquid Glass assets are not produced or validated on this Windows host. |
| Settings/compatibility | Separate Lyrics and redesigned Karaoke root entries, Albums, background controls, unsupported-Spotify notice and explicit external-lyrics compatibility setting/notice. Automatic detection of active Eevee replacement is **unverified**; enable the compatibility setting when another tweak replaces lyrics, then restart. |
| Beta updates/releases | Numeric prerelease precedence, stable/beta filtering on cached and fetched releases, channel-aware cache refresh and separate Release Please configuration on the `beta` branch. Published assets build from the created tag. No branch/release was published by this work. |

The small fixes include nondecreasing serialized lyric starts while retaining simultaneous lines,
foreground/state-driven lyrics retries, reattaching one Mod Settings row after drawer rebuilds,
rediscovering the live playlist Mix control, paused cover scale through transitions, the locally
proven Free-player units, custom-tab selection, coalesced layouts, cached layout diagnostics and
launch-time clutter preference snapshots. The settings' locked flag values still read current
preferences, so they describe what the next launch will use.

Prisma retains the iOS 26 redesign gate, lock-screen animation off by default, exact-edition
precedence and bounded video/HLS validation. No older-iOS opt-in, animated alternate-edition
substitution or arbitrary clip-limit expansion was inferred from the inventory.

## Discovery and packaging

`scripts/package-metadata.py` preserves the original local-network explanation and Bonjour entries,
adds `_spotify-connect._tcp` and `_googlecast._tcp` without duplicates, and merges alternate icons
without replacing Spotify's primary icon or unrelated icon entries. It rejects name collisions and
malformed declarations. ZIP updates are atomic, keep unrelated members and run before signing in
both `pipeline.sh` and `install.sh`; the supplied IPA remains untouched.

The bridge allows at most 16 tracked sockets, 64 discovered services, eight addresses per service
and 8 KiB DNS packets. Resolution retries are bounded, with cooldown before a later query can
retry; backgrounding or losing the last consumer stops browsing. Only denied mDNS operations for
the two declared service types are bridged. Other socket calls and successful native multicast
keep their original behavior. This is source implementation, not proof of entitlement-free device
discovery, Cast pairing or playback transfer. Test permission denial, IPv4/IPv6, foreground return,
socket replacement, disappearing devices and actual speakers/receivers.
Receive return lengths follow the platform: Darwin reports copied bytes, while the Linux harness
also checks its full-datagram `MSG_TRUNC` convention, based on
[Apple's receive implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/uipc_syscalls.c).

The Cast factory's `BOOL` branch and class references were read from the supplied executable:
file offset `0x9271960` branches to `0x92719c0` for `NO`, selecting `GCKBonjourServiceBrowser`
instead of `GCKMDNSServiceBrowser`. Its runtime type encoding is checked before hooking.

Platform inputs: [Apple local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy),
[alternate icon API](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)),
[Release Please configuration](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md).
Spicy inputs: [keys](https://developers.spicylyrics.org/docs/keys) and
[lyrics response reference](https://developers.spicylyrics.org/docs/reference/get.lyrics).
Use a caller-owned publishable key with native-client access configured. Public redistribution
also needs the provider's app registration; no shared key is embedded. Required contributor links
are displayed with lyrics. Lock-screen/Live Activity lyric output suppresses restricted-provider
results because those surfaces cannot show the required links.

## Checks and remaining validation

Passed on this Windows host:

- `python harness/packaging/check.py`: metadata preservation/idempotence, atomic failure,
  unrelated IPA members, packaged icons and actual PNG decoding/CRC checks.
- `python harness/objc-evidence/check.py out/parity-evidence/Spotify`: five Free-player units,
  UIViewController inheritance and exact Cast factory/initializer metadata.
- `python harness/audio-lyrics/check.py`: source extraction and observer/compatibility guards
  only. Its Objective-C assertions do **not** execute on Windows.
- Python syntax, `scripts/check-layers.sh`, shell syntax and diff whitespace checks.

The Git bash invocation here needs its tools on PATH:
`PATH=/usr/bin:/bin:$PATH sh scripts/check-layers.sh tweak/Sources`.
Do not count the script's zero exit status as a pass if it reports missing `grep`.

The native and portable-C harness attempts stop here at missing `xcrun` or `cc`. Run on macOS:

```sh
python3 harness/packaging/check.py
python3 harness/audio-lyrics/check.py
python3 harness/connect/check-sockets.py
sh harness/connect/check.sh
sh harness/update/check.sh
sh harness/player-policy/check.sh
sh harness/player-fluid/check.sh
sh harness/player-video/check.sh
sh harness/audio-routing/check.sh
sh harness/pitch/build.sh && harness/pitch/build/pitch
sh harness/animated-artwork/check.sh
sh harness/canvas/check.sh
sh harness/artwork-video/check.sh
sh harness/apple-music-artwork/check.sh
env -u MAKELEVEL gmake -C tweak clean package
```

The socket harness uses production C wrappers, real UDP sockets, ASan/UBSan and deterministic
descriptor replacement. It covers envelope/source checks, tiny sockaddr buffers, zero-length
receives, `MSG_PEEK`/`MSG_TRUNC`, denied-send fallback and close notifications. It does not execute
UIKit/Bonjour browsing or Spotify's parser. The audio harness exercises mocked lifecycle and
ordered nested-output rendering; pitch assertions cover 44.1/48 kHz and coupled/independent modes.
Existing tabbar/playlist simulator harnesses also have accessory/cache/reveal/fallback assertions.

After compilation, exercise both looks on Spotify 9.1.78, Premium and Free player structures,
rapid track changes, paused transitions, sheets/VoiceOver/Reduce Motion, provider failure and
required credit links, both real MediaPlayer/lock-screen lyrics hook orders, icon switching,
actual Connect/Cast devices, local files at multiple rates and audio route changes. Source
inspection and mocked callbacks do not establish exact parity or real-time device performance.
