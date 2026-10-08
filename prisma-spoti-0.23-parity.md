# Prisma independent feature implementation backlog

## Instructions for implementing agents

Implement the user-visible behavior below independently in Prisma. This is a requirements inventory, not an instruction to port another project's implementation. Historical comparisons in this report are context, not verified acceptance results or a source-code dependency.

- Read `AGENTS.md` and `docs/tweaks.md` first. Use this working tree, its existing helpers, local Spotify view trees/binary evidence, and official platform or provider documentation as implementation inputs.
- Do not clone, fetch, download, browse, or inspect the original project's repository, history, raw files, patches, release binaries, mirrors, or source archives. Do not search for its implementation through code search or ask another agent to retrieve it. Do not copy, translate, or adapt its later code or assets.
- Reuse code already present in Prisma while preserving its GPL v3 license, copyright, and upstream attribution. This restriction concerns retrieving additional original-project material; it does not require rewriting the existing fork.
- Treat feature names and descriptions as behavioral requirements. Choose Prisma's implementation from local evidence and platform APIs. When an API contract, Spotify selector, model, or required asset cannot be established from permitted inputs, report the missing evidence rather than guessing or consulting original-project code.
- Keep the Native/Redesigned separation, preference compatibility, Prisma branding and release URLs. Retain the iOS 26 redesign gate required by `AGENTS.md`; the older-iOS opt-in mentioned below is a deferred product decision, not authorization to change that gate.
- For parallel agent work, assign bounded feature groups with explicit file ownership. Give every agent these restrictions. Coordinate player/navbar, settings, packaging and audio edits through one integration owner; do not let agents overwrite each other's work.
- Complete each assigned feature with its settings, lifecycle/failure handling and relevant runnable checks. Record what was implemented, what was tested, and what remains blocked. Windows cannot validate the iOS build; compilation and device parity remain macOS/iPhone checks.

The backlog covers all listed gaps, but optional policy changes and unverified Sing prerequisites must be reported separately from completed features. Do not claim exact parity from source review alone.

**Remaining implementation backlog**

| Area | What parity requires | Where it belongs / existing foundation |
|---|---|---|
| Fluid player background | Warp and blur the actual cover, with live speed, warp, blur, saturation, brightness controls, preview, reset, pause behavior, and migration from the old moving-background preferences. Prisma currently animates extracted colors through `SGRFlow`, which is visibly different. | Prisma `Redesigned/Player/PlayerField.x`, `Redesigned/Kit/SGRField.*`, `Redesigned/NowPlayingBar/NowPlayingBarSettings.m`. Implement a cover-based renderer and its settings independently. |
| Video player background | Loop Canvas or Apple Music artwork behind the redesigned player; independent provider ordering; fluid fallback when unavailable; hide/restore the cover with transitions; keep swipes and accessibility working; pause/lifecycle and Low Power/Reduce Motion behavior. | Reuse Prisma `SGCanvasCurrentResult`, `SGAppleMusicArtworkResolver`, `SGArtworkVideoPreparer`. Add a redesigned player consumer. Coordinate artwork, lyrics and player transition integration. |
| Animated album headers | Resolve Apple Music motion artwork for the album being browsed, play it in the hero header, retain the static fallback, stop it when offscreen, respect motion/power/data constraints, and expose Albums settings. | Prisma `Redesigned/Album/AlbumHeader.x`, `AlbumField.x`; reuse its artist/album resolver and video preparer. Add album settings. This must work independently of the currently playing track. |
| Apple Music-style integrated mini-player | Optional tab-bar accessory with artwork, title/artist, play/pause, swipe-to-skip, tap-to-open, scroll minimization, and first/last configured Navbar tabs alongside the compact player. | Prisma `Redesigned/Navbar/TabBar.x`, `NavbarSettings.m`, `Redesigned/NowPlayingBar/`. Implement the accessory independently. Existing separate glass now-playing bar is not this feature. |
| Redesigned player's system menu | Final beta behavior uses a native system menu, populated from Spotify's real actions, with cached initial rows, refreshed actions, correct share/navigation behavior, and Speed/pitch popover. | Prisma player header and shared speed/pitch menu are integration points. Implement the native system-menu behavior described here. |
| Immersive lyrics and player interactions | After four seconds of untouched playback, expand lyrics and fade controls; first touch restores controls without also seeking; pausing, VoiceOver, foreground state, and sheets affect this behavior. Tapping the lyrics thumbnail returns to artwork. Tapping the progress bar seeks without breaking dragging. | `Redesigned/Player/PlayerLyrics.x`, `PlayerControls.x`, `Redesigned/Lyrics/SGRKaraokeView.*`. Existing karaoke rendering is already present. |
| Add-tab editor | Name/link/icon sheet with a searchable Spotify glyph / SF Symbols picker, icon preview and SF Symbol rendering. Existing custom tabs already work, but use the older editor and typed icon names. | Both `Native/Navbar/` and `Redesigned/Navbar/` need their respective UI changes. Use platform symbol APIs or an independently sourced symbol catalogue. |
| Entity-page visual finish | Album/playlist/artist page content appears together with bounded loading fallback; background follows the cover's main color; creator/artist faces appear beside names; bottom content fades beneath the bars. | `Redesigned/Kit/SGRPalette.*`, `SGRHeaderInfo.*`, page header/field/row hooks. Implement coordinated reveal and action-row changes using local page lifecycles. |
| Spicy Lyrics developer-platform provider | User-supplied publishable key, validation/status/rejection handling, request/response parsing, caching/backoff, provider ordering, and linked catalogue/community attribution in both native and redesigned lyrics. | Prisma removed the old provider before its fork point. Add an independent provider and richer credit data with native lyrics attribution. Integrate with existing providers; restoring the earlier token-sharing implementation would not match beta. |
| Connect discovery for sideloaded installs | Discover nearby Spotify Connect/Cast services without the multicast entitlement; bridge replies safely; preserve Bonjour declarations and local-network usage text in the injected IPA. | Prisma lacks this discovery feature. Integrate discovery with `scripts/pipeline.sh`, `scripts/install.sh`, and `plist/liquid-glass.plist`, including safe Info.plist merging. A hook alone is insufficient. |
| Pitch follows speed | User switch, enabled by default in the target, coupling pitch to rate through varispeed; hide/disable independent pitch while coupled; retain independent time stretching when disabled. | Prisma `Shared/Player/SGTimePitch.*`, `SpeedPitch.*`, `SpeedPitchMenu.x`. Speed and independent pitch already exist. |
| Robust shared audio routing | Single owner for input/output processing; defined ordering for Sing, speed/pitch, effects and haptics; format/route changes, disposal safety, bounded pulls and per-output tracking. The local-file sample-rate correction is part of this work. | Design a single audio-processing owner from local evidence and platform APIs; integrate `AudioEffects.x`, `MusicHaptics.x`, and `SpeedPitch.x`. Prisma still has separate rebinding/render hooks. Do not replace the already-present effects algorithms. |
| Sing vocal reduction | On-device stem separation, vocal-level control/status, model download/resume/cancel/remove/validation, streamed audio integration, latency-aware lyrics/lock-screen timing, seek/pause/track transitions, and CPU/GPU lifecycle behavior. | Entire `Shared/Sing/` and redesigned Sing control/settings are absent. This is separate from existing word-timed karaoke. Model availability, licensing, size, supported OS/device and runtime compatibility must be established independently. Validate source-queue inspection against the locally supplied Spotify 9.1.78 binary UUID/ABI. These prerequisites are not verified by this inventory. |
| Alternate app icons | An App icon selector plus packaged alternate icon assets, previews, and Info.plist entries. Target enables these Liquid Glass icons on iOS 26+. | Prisma About settings, icon assets and packaging scripts. Create Prisma-owned icon variants and their packaging integration. |
| Settings and compatibility behavior | Separate Lyrics and Karaoke root entries, Albums page, player background controls, unsupported Spotify/Eevee notices, and an explicit warning/opt-in for redesign below iOS 26. | `App/ModSettings.x`, `App/Pages.*`, `Core/SGUIMode.*`, onboarding. Prisma currently hard-disables redesign below iOS 26. That is a product difference; the beta opt-in does not establish that older systems work reliably. |
| Beta releases and update selection | Beta-aware version comparison, beta builds accepting prereleases, stable builds excluding them, appropriate cached-release filtering, and beta release automation. | Prisma `App/About/Update.m` currently rejects all prereleases. Extend Prisma Release Please configuration/manifests and `.github/workflows/release.yml`. Keep Prisma's own release URLs. |

**Small fixes worth doing before the larger features**

These gaps are verified against the current Prisma code, not merely inferred from missing commit hashes. Runtime symptoms have not been reproduced here.

| Fix | Current evidence | Acceptance check |
|---|---|---|
| Prevent crashes from decreasing lyric timestamps | `Shared/LyricsSources/LyricsHook.x:130` emits each start independently; it does not enforce a nondecreasing sequence when serializing Spotify's page. Preserve simultaneous lines while preventing backward starts. | Simultaneous lines stay simultaneous; decreasing starts serialize without moving backwards. |
| Resume/fetch lyrics after background track changes | `Shared/Lyrics/KaraokeSource.x` lacks a player-state watcher and foreground retry observer. Its artwork authorization notifications serve a different purpose. | Change tracks in the background, foreground the app, and confirm lyrics resume/fetch. |
| Avoid competing Eevee lyrics hooks | `LyricsHook.x` and source-forced flags are gated by `SGLyricsEnabled()`, with no Eevee replacement check. The compatibility warning alone does not fix this. | With Eevee lyrics replacement active, Prisma does not install competing hooks/forced flags. |
| Restore Mod Settings after drawer relayout | `App/ModSettings.x` skips a row once it has an associated object, rather than ensuring it is attached after Spotify rebuilds the collection's children. | Rebuild drawer children and confirm exactly one attached Mod Settings row. |
| Refresh playlist Mix control after reload | `Redesigned/Playlist/PlaylistMenu.x:305` returns any cached toolbar, including one no longer in the window. Rediscover the live row before firing Mix. | Reload the playlist and confirm Mix invokes the currently attached control. |
| Keep paused cover size stable during transitions | `Redesigned/Player/PlayerArtwork.x` forces scale to identity while the player transitions. Retain the paused scale through transitions. | Open/close the paused player and confirm cover size stays stable. |
| Support the Spotify Free player structure | Prisma's player hooks lack the additional ReinventFree units described in the inventory in header, controls, footer and lyrics. | Prove Free-account classes/selectors locally; verify header, controls, footer and lyrics. |
| Keep custom tabs selected while their page is open | Existing navigation works, but selection tracking is needed for the mod's own destinations. | Open a custom tab and confirm its selected state persists until navigation changes. |
| Reduce startup/tab layout work | Cache launch-time clutter preferences, avoid repeatedly rebuilding layout diagnostics, and coalesce tab-bar item layout work. | Confirm launch-only preference reads and coalesced layout preserve tab behavior. |

**Animated artwork: finish coverage, do not start over**

Prisma's current implementation already includes ordered fallback, provider disabling/cancellation, video preparation/cache, stale-track checks, Canvas metadata/service handling, Apple lookup, and bounded failure recovery. Its uncommitted fixes were included in this assessment. Both Apple's request session and the video downloader already disable constrained-network access, so Low Data handling is not wholly missing.

Remaining differences recorded by the earlier comparison; confirm Prisma behavior locally:

- HEVC: Prisma's HLS selector accepts AVC (`avc1`) SDR variants; the requested coverage includes HEVC. Add supported HEVC handling and validation to reach the same catalogue coverage.
- Collaborative artist credits: Prisma requires exact normalized artist equality; broader matching could cover collaborations. Implement deliberate collaboration matching with false-positive checks.
- Alternate editions: Prisma stops at an exact edition even if it has no motion artwork; the requested option can fall back to another edition with animation. This is a policy choice as well as a coverage difference.
- Clip limits: Prisma caps downloads and relevant HLS byte ranges at 32 MiB and has stricter playlist/URL validation. Some catalogue clips may be rejected. Broaden only the necessary cases while keeping bounded resource use.
- Default: animated lock-screen artwork is off by default in Prisma, the comparison target defaults it on.
- Player and album consumers remain absent. Reuse the resolvers/preparer but maintain independent state, lifetimes and settings for each consumer; a browsed album must not overwrite the current track's lock-screen artwork.
- Evidence of code completion is not evidence of device parity. Existing macOS artwork harness execution, iOS compilation, real metadata/API responses, and lock-screen rendering still need verification. The publisher harness currently stubs the lyrics integration calls, so it does not establish both real hook orders.

**Deliberate fork differences**

Prisma branding, GitHub release links, GPL license display, and removal of upstream donations, usage reporting, certificate sales prompts, and upstream community links are intentional fork changes. They do not need reimplementation for playback/UI parity. Literal equivalence would include those differences too; the inventory records them. CLA automation is repository governance, not an app feature.

Likewise, older-iOS opt-in, artwork enabled by default, looser album matching, and alternate-edition fallback should be explicit decisions. Preserving Prisma's stricter choices is reasonable, but should not be described as exact beta behavior.

**Suggested implementation order**

1. Land the small correctness fixes above and validate the existing artwork implementation. They improve the current app without depending on new UI or model infrastructure.
2. Reuse artwork services for album headers and video player backgrounds; implement the fluid renderer and corresponding settings together.
3. Add the mini-player, final system menu, immersive lyrics, seeking, entity-page polish and tab editor. Coordinate edits to the same player/navbar files through the integration owner.
4. Add the Spicy provider/attribution and Connect discovery with their UI/packaging integration.
5. Implement the audio pipeline and varispeed with a runnable check covering multiple sample-rate output chains. Add Sing after that foundation, including model lifecycle and latency/seek correctness.
6. Finish alternate icons, optional older-iOS behavior, settings layout and beta-release automation.

Before calling a future implementation equivalent, build on macOS and exercise Spotify 9.1.78 in both Native and Redesigned modes. Test rapid track changes, background/foreground transitions, local files at different sample rates, lyrics/provider failures, Free-account player paths, actual Connect/Cast devices, and artwork/lyrics hook ordering. Sing additionally needs a supported model/device/OS combination as defined by that implementation. No device check is needed merely to review this report.
