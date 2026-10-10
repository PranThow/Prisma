# Prisma parity tasks for agents

This is the consolidated parity backlog, split into bounded assignments for agents.
Read [the implementation status](parity-implementation.md) before claiming work: much of this
already has source code. Every task begins with checking the current implementation against its
acceptance criteria. Fix only what is missing; otherwise deliver validation and remaining limits.
All tasks start **unclaimed and unverified**, not necessarily unimplemented.

## Instructions to include with every assignment

- Read [AGENTS.md](../AGENTS.md), [docs/tweaks.md](tweaks.md) and the implementation status.
  These instructions apply to every task below.
- Treat these tasks as user-visible behavioral requirements, not instructions to port another
  project. Historical comparisons are context, not verified acceptance results.
- Implement independently from existing Prisma code, local Spotify trees/binary evidence and
  official platform/provider documentation. Do not retrieve or inspect the original project's
  repository, history, source, patches, binaries, mirrors or assets, including through another agent.
- Preserve GPL v3, attribution, Prisma branding/release URLs, existing identifiers and persisted
  preference compatibility. Keep Native and Redesigned separate and retain the iOS 26 redesign gate.
  Removal of upstream donations, reporting, certificate-sales prompts and unrelated community links
  is intentional; CLA automation is governance, not app parity. Do not restore those features.
- Paths below are relative to the repository; source paths are relative to `tweak/Sources/` unless
  they start with `harness/`, `scripts/`, `docs/`, `plist/` or `.github/`. A named directory is an
  ownership boundary, not permission to rewrite all its files. New files stay inside that boundary.
- Before editing, reserve the exact files and relevant harness files with the integration owner.
  A shared directory/file or harness cannot have two active writers. Read-only work can run in parallel.
  If a caller, declaration, build input or fixture outside your reservation needs a change, request
  that file from the integration owner; include the required integration in your handoff.
- Dependencies mean the predecessor's interface or result must be accepted before dependent edits.
  A blocked prerequisite stays blocked. Policy tasks produce a recommendation; they do not authorize
  changing defaults, weakening validation, or enabling the redesign below iOS 26.
- Complete feature settings, cancellation/stale-result handling and relevant checks. Reuse existing
  harnesses; add a small regression for new nontrivial logic. Do not invent unproven Spotify selectors.
- Record executed checks separately from planned/device checks. Windows cannot compile the iOS tweak
  or run Apple SDK harnesses. Mocked/source checks do not prove device parity.
- Handoff: task ID, exact changed files, resulting behavior, executed commands/results, remaining
  blockers and required device checks. Only the integration owner updates the central status document.

## Lanes: what each agent does

Work runs in six lanes, one agent per lane, plus the integration owner. A lane owns its files for
the whole run, so lanes never edit the same file and can run at the same time. **Find your lane
below and do its tasks in the listed order.** Ignore tasks outside your lane.

| Lane | Agent | Tasks, in order |
| --- | --- | --- |
| 1 | Lyrics | F01, F03, L01, L02, L03 (Native), L03 (Redesigned), F02 |
| 2 | Player | F06, F07, F08, U01, U02, U03, B01, B02, B03, V01, V02, V03, M01, M02 |
| 3 | Artwork and album | A01, A02, A03, A04, A05, H01, H02, H03, E01, E02, E03 |
| 4 | Navbar | N01, N02, N03, N05, F09 (Redesigned), N04, F09 (Native), F10, F05 |
| 5 | Audio and Connect | D01, D02, D03, D04, C01, C03 |
| 6 | Updates and evidence | R01, R02, R03, S01, S02, P01, P02, P03, P04 |
| - | Integration owner | F04, I01, I02, C02, T01, T02, all cross-lane wiring, then Q01-Q03 |

S03-S06 are not assigned. They start only after S01 and S02 clear their gates.

The integration owner alone edits `App/Pages.*`, `App/ModSettings.x`, `Core/SGPrefs.*`, common
declarations, build inputs, packaging/release files, the claim table below and the central status
document. A lane that needs one of those changed writes the exact change in its handoff instead.

### Rules for every lane agent

1. Work on your lane's branch. Do the tasks in order and make one commit per task.
2. Before you start each task, run `git fetch origin && git merge origin/main`, then resolve any
   conflicts. This picks up the other lanes' merged work.
3. Edit only the files on the task's **Own:** line. If a task depends on another lane's task that
   isn't on `main` yet, record it as blocked and move to your next task.
4. After each task, append its handoff to `docs/handoffs/<lane>.md` in the format given in the
   shared instructions, then stop and wait for the integration owner to merge before you continue.
5. A blocked task is a valid result. Record why it's blocked and move on. Don't guess selectors to get past a gate.

### Keeping lanes in sync (integration owner)

- Merge each lane's branch into `main` after every task, or every two at most. Small merges are
  easy to review; a week of one lane's work is not.
- After each merge, apply any wiring the handoff asks for, commit it to `main`, and update the
  claim table. The other lanes pick it up at their next `git merge origin/main`.
- If a merge conflicts, the lane has edited outside its reservation. Send it back and don't
  resolve the conflict yourself.

### Prompt to start a lane agent

```
You are the <lane name> lane agent (lane <N>) in docs/prisma-parity-tasks.md.

1. Read AGENTS.md, docs/tweaks.md, docs/parity-implementation.md, the
   "Instructions to include with every assignment" and "Lanes" sections of
   docs/prisma-parity-tasks.md, and your lane's file in docs/handoffs/.
2. Run `git fetch origin && git merge origin/main`. Pick the first task in your
   lane that the claim table and your handoff file don't already show as done
   or blocked. Do exactly one task.
3. Edit only that task's Own: files. If existing code already meets the task,
   that's a valid result: add a regression check if one is missing, otherwise
   change nothing. If it needs a file you don't own, unproven selectors, the
   Spotify binary, recorded trees or macOS, record it as blocked and stop.
4. Append the handoff to docs/handoffs/<lane>.md: task ID, exact changed files,
   resulting behavior, commands run with results, blockers, and the macOS and
   device checks still owed.
5. Commit everything on your lane branch: one commit for the task, a lowercase
   conventional prefix (fix: only for a behavior change, test: or docs:
   otherwise), and the handoff included. `git status` must be clean.
   Never push and never touch main.
6. Stop. Report only: task ID, commit hash, one line on what changed, checks
   run, checks skipped.

A report without a commit hash means the task isn't done.
```

| Inventory area | Task IDs | Coordination |
| --- | --- | --- |
| Small correctness/performance fixes | F01-F10 | Lyrics, player and Navbar files overlap later tasks |
| Existing animated-artwork coverage | A01-A05, Q01 | One resolver writer; policy decisions separate |
| Fluid player background | B01-B03 | Renderer first, player consumer and settings next |
| Video player background | V01-V03 | Shared provider interface, then player consumer |
| Animated album headers | H01-H03 | Independent album lifetime; settings via integration owner |
| Mini-player and tab editor | N01-N05 | Native editor can run alongside Redesigned work |
| System player menu | M01-M02 | Evidence gate before implementation |
| Immersive lyrics/seeking | U01-U03 | Reserve player files shared with F/V/M tasks |
| Entity-page polish | E01-E03 | Kit contract first; reserve album files used by H tasks |
| Spicy Lyrics | L01-L03 | Provider, aggregation and each look's credits |
| Connect discovery | C01-C03 | Discovery owner plus packaging integration owner |
| Shared audio and pitch follows speed | D01-D04 | One audio owner; explicit stage order |
| Sing vocal reduction | S01-S06 | Prerequisites blocked until independently proven |
| Alternate icons | I01-I02 | Assets/metadata before selector validation |
| Settings and compatibility | T01-T02 | Integration owner; no older-iOS opt-in |
| Beta updates/releases | R01-R03 | Comparator before filtering; automation can be reviewed separately |
| Deferred policy choices | P01-P04 | Decision records, no behavior changes |
| Integration validation | Q01-Q03 | macOS and real device required |

The claim table below is written by the integration owner only. Lane agents report through
their handoff files.

| Task | Agent | Exact reserved files | State | Handoff/result |
| --- | --- | --- | --- | --- |
| F01 | Lyrics | `Shared/LyricsSources/LyricsHook.x` (no change needed) | Merged; macOS harness pending | `docs/handoffs/lyrics.md` |
| D04 | Audio/Connect | `Shared/Player/SpeedPitch.x`, `harness/speed/main.m` | Merged; simulator/device pending | `docs/handoffs/audio-connect.md` |
| N01 | Navbar | `Redesigned/Navbar/MiniPlayer.inc`, `harness/tabbar/main.m` | Merged; VoiceOver device check pending | `docs/handoffs/navbar.md` |
| R01/R02 | Updates/Evidence | `App/About/SGVersion.h`, `harness/update/versions.m` | Merged; macOS harness pending | `docs/handoffs/updates-evidence.md` |
| R03 | Updates/Evidence | Release Please config (review only) | Configs and workflow routing verified; non-publishing action run owed | `docs/handoffs/updates-evidence.md` |
| S01/S02 | Updates/Evidence | `docs/sing-evidence.md` | Blocked: no distributable model, streamed-source ABI unproven | `docs/sing-evidence.md` |
| P01-P04 | Updates/Evidence | - | Recommendations recorded | `docs/handoffs/updates-evidence.md` |
| F06 | Player | `Redesigned/Player/PlayerArtwork.x`, `SGRPlayerPolicy.h`, `harness/player-policy/main.c` | Merged; macOS harness and paused open/close device check pending | `docs/handoffs/player.md` |
| A01-A05, H01-H03 | Artwork/Album | - (no changes) | Source parity confirmed; macOS harnesses and device checks pending. E01-E03 not checked | `docs/handoffs/artwork-album.md` |
| F03 | Lyrics | `harness/audio-lyrics/check.py` (no source change) | Merged; device check pending. Eevee not auto-detected | `docs/handoffs/lyrics.md` |
| N02 | Navbar | `harness/tabbar/main.m` (no source change) | Merged; touch/scroll simulator check pending | `docs/handoffs/navbar.md` |
| D01-D03 | Audio/Connect | - (no change) | Reviewed; D01 blocked on `harness/audio-routing/check.sh` (macOS) | `docs/handoffs/audio-connect.md` |
| C01/C03 | Audio/Connect | `Shared/Navigation/ConnectDiscovery.x` | Merged; socket harness and real Connect/Cast devices pending | `docs/handoffs/audio-connect.md` |
| E01-E03 | Artwork/Album | - (no change) | Source parity confirmed; macOS harness and iOS 26 device pending | `docs/handoffs/artwork-album.md` |
| F07 | Player | `harness/objc-evidence/check.py` | Merged; Free-player hook metadata verified. F08 blocked on recorded Free-player trees | `docs/handoffs/player.md` |
| L01 | Lyrics | `harness/audio-lyrics/check.py` (no source change) | Merged; macOS parser and device key/network checks pending | `docs/handoffs/lyrics.md` |
| N03 | Navbar | - (no change) | Verified at source; relaunch both preference states on device | `docs/handoffs/navbar.md` |
| U01 | Player | `harness/player-policy/main.c` | Merged; macOS harness and iOS 26 idle-timer checks pending | `docs/handoffs/player.md` |
| L02 | Lyrics | `harness/audio-lyrics/check.py` (no source change) | Merged; macOS runtime assertions and device reorder/lock-screen checks pending | `docs/handoffs/lyrics.md` |
| L03 | Lyrics | - (no change) | Merged; device link activation and VoiceOver checks pending in both looks | `docs/handoffs/lyrics.md` |
| U02 | Player | `Redesigned/Player/PlayerLyrics.x` | Merged; macOS build and iOS 26 wake-touch/VoiceOver focus checks pending | `docs/handoffs/player.md` |
| U03 | Player | `Redesigned/Player/PlayerControls.x`, `SGRPlayerPolicy.h`, `harness/player-policy/main.c` | Merged; macOS policy harness and LTR/RTL tap-seek device checks pending | `docs/handoffs/player.md` |
| N05 | Navbar | `harness/tabbar/editor-check.ps1` (no source change) | Merged; macOS harness and editor device checks pending | `docs/handoffs/navbar.md` |
| F09 (Redesigned) | Navbar | `harness/tabbar/selection-check.ps1` (no source change) | Merged; device navigation checks pending. Native half not started | `docs/handoffs/navbar.md` |
| F04 | Integration | - (`App/ModSettings.x` already compliant) | Merged; macOS build and drawer rebuild device check pending | `docs/handoffs/integration.md` |
| I01 | Integration | `harness/packaging/check.py` | Merged; macOS signing and iPhone/iPad icon checks pending. Static PNGs, not layered assets | `docs/handoffs/integration.md` |
| F02 | Lyrics | `Shared/Lyrics/KaraokeSource.x`, `harness/audio-lyrics/check.py` | Merged; macOS runtime assertions and device background/foreground retry checks pending | `docs/handoffs/lyrics.md` |
| B01 | Player | `harness/player-fluid/main.m`, `check.sh`, `check-source.py` (no source change) | Merged; macOS Core Image harness and iOS 26 cover-replacement/transition checks pending | `docs/handoffs/player.md` |
| N04 | Navbar | `Native/Navbar/NavbarSettings.m`, `harness/tabbar/native-editor-check.ps1` | Merged; macOS build and editor sheet/VoiceOver/persistence device checks pending | `docs/handoffs/navbar.md` |
| I02 | Integration | - (no source change) | Blocked: needs macOS build/signing and iPhone/iPad icon switching | `docs/handoffs/integration.md` |
| B02 | Player | - (no source change) | Merged; macOS build/fluid harness and iOS 26 control/reset/migration checks pending | `docs/handoffs/player.md` |
| F09 (Native) | Navbar | `harness/tabbar/native-selection-check.ps1` (no source change) | Merged; macOS build and device navigation/reorder/remove checks pending | `docs/handoffs/navbar.md` |
| C02 | Integration | `harness/packaging/check.py` | Merged; macOS release/install signing and real Connect/Cast discovery pending | `docs/handoffs/integration.md` |
| B03 | Player | `harness/player-fluid/check-source.py` (no source change) | Merged; macOS fluid harness/build and iOS 26 lifecycle/transition performance checks pending | `docs/handoffs/player.md` |
| F10 | Navbar | `Native/Navbar/TabBarHooks.x`, `Redesigned/Navbar/TabBar.x`, `harness/tabbar/layout-coalescing-check.ps1` | Merged; macOS build and device callback counts/live editing checks pending in both looks | `docs/handoffs/navbar.md` |
| T01 | Integration | - (no source change) | Merged; macOS build and device destination/reset checks pending in both looks | `docs/handoffs/integration.md` |
| V01 | Player | `harness/canvas/resolver.m` (no source change) | Merged; macOS Canvas/Apple artwork harnesses and iOS 26 lock-screen/consumer/album-browse checks pending | `docs/handoffs/player.md` |
| F05 | Navbar | `Redesigned/Playlist/PlaylistMenu.x`, `harness/playlist/mix-control-check.ps1` | Merged; macOS build and device toolbar-replacement/absent-Mix checks pending | `docs/handoffs/navbar.md` |
| T02 | Integration | `App/ModSettings.x`, `Shared/Lyrics/LyricsSettings.m` (notice wording only) | Merged; macOS build and device unsupported-version, external-lyrics and pre-iOS 26 checks pending. Eevee not auto-detected | `docs/handoffs/integration.md` |
| V02 | Player | `harness/player-video/check-source.py` (no source change) | Merged; macOS player-video harness/build and iOS 26 provider-order/failure/looping/fluid-fallback checks pending | `docs/handoffs/player.md` |

## Small correctness fixes

### F01 - Keep serialized lyric starts nondecreasing

- **Own:** `Shared/LyricsSources/LyricsHook.x`; reserve its lyric regression fixture/check.
- **Do:** Inspect serialization and every caller; preserve equal starts and prevent backward starts.
- **Accept:** Inputs with equal, decreasing and already ordered timestamps serialize monotonically
  without dropping simultaneous lines. Execute the relevant lyric assertions, not just a source scan.
- **Depends:** None. Coordinate with F03 and L02, which also touch the lyrics hook.

### F02 - Retry lyrics after a background track change

- **Own:** `Shared/Lyrics/KaraokeSource.x`; relevant `harness/audio-lyrics/` check.
- **Do:** Verify player-state observation and foreground retry use the current track/generation.
- **Accept:** Background A-to-B, foreground, empty response and rapid A-to-B-to-A do not leave stale
  lyrics or duplicate observers. Device foreground fetch is recorded separately from mocked checks.
- **Depends:** None.

### F03 - Suppress competing external lyrics hooks

- **Own:** Lyrics compatibility guards in `Shared/LyricsSources/LyricsHook.x` and source-forced flags;
  coordinate shared declarations and settings with the integration owner.
- **Do:** Verify existing external-replacement setting suppresses both hooks and forced flags.
  Claim automatic Eevee detection only with independently established evidence; otherwise report it blocked.
- **Accept:** Compatibility enabled/disabled after restart changes both paths consistently, including
  when providers are enabled. A warning alone is not a passing guard.
- **Depends:** None; reserve separately from F01/L02. Notice wording belongs to T02.

### F04 - Reattach one Mod Settings drawer row

- **Own:** Integration owner only: drawer insertion in `App/ModSettings.x`.
- **Do:** Reattach the associated row after Spotify replaces drawer children; retain its action.
- **Accept:** Repeated relayout/rebuild leaves exactly one attached, working Mod Settings row.
- **Depends:** None; serialize with T01/T02.

### F05 - Find the live playlist Mix control

- **Own:** `Redesigned/Playlist/PlaylistMenu.x`; its `harness/playlist/` regression.
- **Do:** Reject detached cached toolbar/control references and rediscover the active page's control.
- **Accept:** Reload/reopen, replace the toolbar, then invoke Mix: only the attached control fires;
  absent controls fail safely.
- **Depends:** None.

### F06 - Preserve paused cover scale through transitions

- **Own:** `Redesigned/Player/PlayerArtwork.x`; reserve applicable player/morph assertions.
- **Do:** Verify open/close transitions preserve paused scale and playing scale still returns correctly.
- **Accept:** Paused open/close, resume during transition and interrupted transitions have stable cover size.
- **Depends:** None; serialize later cover visibility edits in V03.

### F07 - Verify Free-player class and selector contracts

- **Own:** Read-only `Redesigned/Player/`, local tree/binary evidence; `harness/objc-evidence/` if needed.
- **Do:** Check ReinventFree header, controls, footer and lyrics units against the local Spotify 9.1.78
  binary UUID/ABI. Produce a class/selector/evidence matrix for F08.
- **Accept:** Each proposed hook has proven inheritance/signature and evidence location, or an explicit
  missing-evidence blocker. Binary metadata is not a substitute for a recorded runtime layout.
- **Depends:** None.

### F08 - Complete verified Free-player hooks

- **Own:** Exact Free paths in `Redesigned/Player/PlayerHeader.x`, `PlayerControls.x`, `PlayerFooter.x`
  and `PlayerLyrics.x`; reserve only the required files.
- **Do:** Complete missing coverage using F07 contracts and existing helpers; leave unproven paths blocked.
- **Accept:** Free header/controls/footer/lyrics work, Premium paths retain behavior and missing optional
  classes are safe. Run hook checks and list remaining Free-account device checks.
- **Depends:** F07. Serialize with M/U tasks on these files.

### F09 - Keep custom destinations selected in each Navbar

- **Own:** Separate reservations for `Native/Navbar/` and `Redesigned/Navbar/` navigation-selection files.
- **Do:** Verify selection follows each custom destination until navigation changes, using each look's
  own state/names. Assign one look per agent; do not merge their implementations.
- **Accept:** Open custom link, navigate deeper/back, then change tab; the selected item is correct in
  both looks and a removed/reordered custom tab leaves no stale selection.
- **Depends:** None. Serialize Redesigned changes with N01-N03.

### F10 - Remove repeated startup and tab-layout work

- **Own:** `Shared/Privacy/Clutter.m` and the exact layout/diagnostic files in each Navbar; reserve each
  look as a separate follow-up if the files overlap active tasks.
- **Do:** Check launch-time preference snapshots, diagnostic caching and coalescing of repeated item layout.
- **Accept:** Repeated layout calls coalesce; live tab editing still works, and settings describe next-launch
  locked flags correctly. Report measured calls/work before and after any change.
- **Depends:** None; do not broaden this into unrelated optimization.

## Existing animated-artwork coverage

### A01 - Validate supported HEVC selection

- **Own:** Codec selection in `Shared/AnimatedArtwork/AppleMusicArtwork.m` and its Apple artwork harness.
- **Do:** Inspect existing hardware-supported HEVC support before adding anything; retain SDR/size checks.
- **Accept:** Supported HEVC and AVC select correctly; unsupported codecs/hardware, HDR and oversize variants
  reject/fall back. Separate macOS parser results from hardware/device decoding.
- **Depends:** None.

### A02 - Validate collaborative artist matching

- **Own:** Matching in `Shared/AnimatedArtwork/AppleMusicArtwork.m`; its matching fixtures.
- **Do:** Verify complete normalized credited-artist sets rather than lead-artist substring matches.
- **Accept:** Reordered explicit collaborators match; missing/extra artists, same-name albums and partial
  substrings do not. Preserve exact-edition precedence.
- **Depends:** None; serialize with A01/A03 in the same file.

### A03 - Lock down edition and clip-validation behavior

- **Own:** Relevant Apple artwork and `ArtworkVideo.m` validation fixtures; production edits only for bugs.
- **Do:** Verify current exact-edition precedence, allowed suffix matching and bounded URL/HLS/clip checks.
- **Accept:** Exact no-motion edition stays a miss; unrelated live/remix/subtitle editions stay distinct;
  malformed/off-CDN/oversize resources fail safely. No relaxed bounds or edition substitution added.
- **Depends:** None. Proposed policy changes belong to P02/P03.

### A04 - Verify provider failure, cancellation and cache leases

- **Own:** `Shared/AnimatedArtwork/` resolver/preparer regression files, reserving production files only
  if a demonstrated failure needs fixing.
- **Do:** Reuse `harness/canvas/`, `harness/apple-music-artwork/` and `harness/artwork-video/` checks.
- **Accept:** Provider disable/reorder, empty order, late metadata, A-to-B-to-A, auth failure, retry budgets,
  URL invalidation and protected-cache exhaustion preserve fallback without stale media or leaked leases.
- **Depends:** None; coordinate shared resolver edits with V01/H01.

### A05 - Verify publisher and lyrics metadata coexistence

- **Own:** `Shared/AnimatedArtwork/AnimatedArtworkPublisher.x`, related `harness/animated-artwork/` checks;
  coordinate real lyrics-hook changes with the lyrics owner.
- **Do:** Check metadata identity, ownership and clock handling, including readiness while paused/seeking.
- **Accept:** Preserve Spotify fields/animated assets; reject ambiguous identity; lyric/artist restoration
  keeps elapsed time. Mocked calls are recorded as mocks; both real hook orders remain Q01 device checks.
- **Depends:** None.

## Fluid player background

### B01 - Verify the cover-based fluid renderer

- **Own:** `Redesigned/Kit/SGRField.*`, `SGRFlow.*`; `harness/player-fluid/`.
- **Do:** Verify actual cover warp/blur/color processing, bounded work and stale-cover cancellation.
- **Accept:** Output depends on the supplied cover, parameters stay valid and rapid replacement cannot
  publish an old frame. Reuse the serial renderer; do not add a 60 Hz display-link bottleneck.
- **Depends:** None; reserve Kit files shared by page backgrounds.

### B02 - Complete fluid controls, preview, reset and migration

- **Own:** Background settings in `Redesigned/NowPlayingBar/NowPlayingBarSettings.m` and its feature header;
  integration owner handles any `Core/SGPrefs.*` migration or App wiring.
- **Do:** Verify speed, warp, blur, saturation and brightness controls, live preview, reset and old-key migration.
- **Accept:** All controls affect preview/player; invalid persisted values are bounded; reset is predictable;
  migration preserves existing settings without repeatedly overwriting new ones.
- **Depends:** B01's parameter contract.

### B03 - Verify fluid player lifecycle

- **Own:** `Redesigned/Player/PlayerField.x`; applicable fluid/player checks.
- **Do:** Verify track cover updates, pause/foreground behavior, Reduce Motion and Low Power handling.
- **Accept:** No stale cover or renderer work after dismissal/background; pause and motion/power changes
  leave a valid background and restart correctly. Check transition performance on device.
- **Depends:** B01; serialize with video fallback wiring in V02.

## Video player background

### V01 - Verify independent visible-consumer artwork requests

- **Own:** Visible-consumer interfaces in `Shared/AnimatedArtwork/SpotifyCanvas.*`, `SpotifyCanvasResolver.x`
  and Apple resolver/preparer; integration owner reviews shared declarations.
- **Do:** Ensure player/album consumers can request artwork independently of lock-screen enablement/order.
- **Accept:** Disabling lock-screen animation does not disable an active player consumer; removing the last
  consumer cancels work. Browsed album state never replaces current-track publisher state.
- **Depends:** None; agree the interface with H01 before either consumer changes it.

### V02 - Verify looping video, provider order and fluid fallback

- **Own:** `Redesigned/Player/PlayerVideo.x`, `SGRPlayerVideoPolicy.h`; `harness/player-video/`;
  reserve background provider settings separately through B02's owner.
- **Do:** Check independent order, leased prepared files, readiness, playback failures and looping.
- **Accept:** Ordered fallback works on lookup/preparation/player failure; all misses show fluid; rapid
  track changes ignore late results. Provider preferences do not alter lock-screen order.
- **Depends:** V01 and B01; player-field wiring requires B03's file reservation to finish.

### V03 - Verify video cover transitions and accessibility

- **Own:** Exact integration points in `Redesigned/Player/PlayerVideo.x`, `PlayerArtwork.x`, `PlayerGestures.x`.
- **Do:** Verify cover hide/restore, pause/dismissal, foreground, Low Power/Low Data and Reduce Motion behavior.
- **Accept:** Pending/failed/stopped video restores the cover; swipe-to-skip, tap targets and VoiceOver remain
  usable. Interrupted transitions and policy changes neither strand hidden artwork nor leak playback.
- **Depends:** V02, F06; device transitions required.

## Animated album headers

### H01 - Resolve motion for the browsed album

- **Own:** Lookup/state in `Redesigned/Album/AlbumMotion.inc` and album header integration.
- **Do:** Use that page's artist/album identity and independent resolver/preparer lifetime.
- **Accept:** Browsing album B while track A plays requests B; late result after navigation is discarded;
  current-track player/lock-screen artwork remains A.
- **Depends:** V01's consumer contract.

### H02 - Verify album hero playback and static fallback

- **Own:** Playback in `Redesigned/Album/AlbumMotion.inc`, `AlbumHeader.x`, `AlbumField.x` as needed.
- **Do:** Check looping, readiness/error handling, visibility, leases and power/motion/data constraints.
- **Accept:** Offscreen/background stops playback; return resumes appropriately; failure or unsupported
  animation retains the static hero. Navigation/reuse cannot show another album's clip.
- **Depends:** H01; serialize with E02 album edits.

### H03 - Complete Albums motion settings

- **Own:** `Redesigned/Album/AlbumSettings.m`, `Album.h`; integration owner wires the Albums page.
- **Do:** Verify settings and availability explanations use the album consumer's own preferences.
- **Accept:** Albums settings are reachable in Redesigned mode, absent from Native-only composition where
  appropriate, preserve defaults/reset semantics and accurately describe application/restart behavior.
- **Depends:** H02 and integration owner availability; no edits to Native album settings.

## Navbar accessory and tab editors

### N01 - Verify mini-player accessory content and actions

- **Own:** `Redesigned/Navbar/MiniPlayer.inc`, accessory integration in `TabBar.x`.
- **Do:** Check artwork/title/artist updates, play/pause, swipe skipping and tap-to-open through existing actions.
- **Accept:** Empty/late metadata is safe; track changes update content; each gesture triggers once;
  VoiceOver labels/actions work and the existing separate bar is handled consistently.
- **Depends:** None; one writer for `TabBar.x`.

### N02 - Verify compact accessory layout and minimization

- **Own:** Accessory layout in `Redesigned/Navbar/MiniPlayer.inc`, `TabBar.x`, `NavbarLayout.m`;
  relevant `harness/tabbar/` checks.
- **Do:** Verify scroll minimization with first/last configured visible tabs flanking the compact player.
- **Accept:** Reordered/hidden/custom tabs, small screens, safe areas and interrupted scroll transitions
  keep correct endpoints and touch forwarding. Real hit testing still needs device validation.
- **Depends:** N01; coordinate F09/F10.

### N03 - Complete mini-player preference and mode switching

- **Own:** `Redesigned/Navbar/NavbarSettings.m`, `Navbar.h`; exact separate-bar integration files by reservation.
- **Do:** Verify optional accessory preference and consistent switching between accessory and separate bar.
- **Accept:** Enabled/disabled launches show the intended player once, without duplicate gestures,
  subscriptions or stranded spacing; Native mode retains its own behavior.
- **Depends:** N02; integration owner handles composed settings links.

### N04 - Verify Native add-tab sheet and icon picker

- **Own:** `Native/Navbar/TabEditor.inc`, `NavbarSettings.m`; Native editor checks/fixtures.
- **Do:** Check name/link validation, searchable proven Encore glyphs and SF Symbols, preview and rendering.
- **Accept:** Add/edit/cancel and invalid link/icon paths behave safely; glyph/SF choices persist and render;
  search, keyboard and VoiceOver work. Preserve Native keys and selection behavior.
- **Depends:** None; reserve settings file separately from F09/F10 Native work.

### N05 - Verify Redesigned add-tab sheet and icon picker

- **Own:** `Redesigned/Navbar/TabEditor.inc`, `NavbarSettings.m`; Redesigned editor checks/fixtures.
- **Do:** Check the same editor behavior as N04 using this look's own symbols, settings and implementation.
- **Accept:** Name/link/icon preview and search work, persisted icons render and invalid input is safe;
  switching looks does not overwrite Native configuration.
- **Depends:** None; serialize with N03. No import from or shared editor with Native.

## Redesigned system player menu

### M01 - Establish the real Spotify action-menu contract

- **Own:** Read-only local trees/binary and `Redesigned/Player/PlayerHeader.x`, `Shared/Player/SpeedPitchMenu.x`.
- **Do:** Document action enumeration, cached initial rows, refresh, presentation, share and navigation contracts.
  The current status records opaque Swift models as blocked; check permitted evidence for a real contract.
- **Accept:** Proven selectors/type encodings/lifetimes for M02 or a precise blocker/evidence request.
  No guessed menu actions or implementation from the original project.
- **Depends:** None. A blocked evidence result does not authorize M02.

### M02 - Present the verified actions in a system menu

- **Own:** `Redesigned/Player/PlayerHeader.x`; coordinated `Shared/Player/SpeedPitchMenu.x` integration.
- **Do:** Use M01's proven actions for initial cached rows and refresh; integrate the Speed/pitch popover.
- **Accept:** Real actions, share/navigation, empty/error refresh and presentation/dismissal work;
  stale track actions cannot fire. Keep existing functional menu until the replacement is validated.
- **Depends:** M01 must establish the complete contract; coordinate D04 menu edits.

## Lyrics and player interactions

### U01 - Verify four-second immersive lyrics eligibility

- **Own:** Immersion logic in `Redesigned/Player/PlayerLyrics.x`, `SGRPlayerPolicy.h`; `harness/player-policy/`.
- **Do:** Check idle timing and eligibility for playing, paused, VoiceOver, foreground and presented sheets.
- **Accept:** Eligible untouched playback expands at four seconds; every disqualifying state cancels/restores
  appropriately; repeated changes do not create competing timers or stale callbacks.
- **Depends:** None; reserve after F08 if the same player file is needed.

### U02 - Verify wake-touch consumption and thumbnail return

- **Own:** Touch/thumbnail paths in `Redesigned/Player/PlayerLyrics.x` and exact control integration files.
- **Do:** Ensure first touch restores faded controls without also seeking; thumbnail returns to artwork.
- **Accept:** First wake touch performs no hidden control action; subsequent gestures work; thumbnail return
  restores layout and accessibility focus. Test taps/drags while immersion begins or ends.
- **Depends:** U01; reserve karaoke-view edits only if the existing interface is insufficient.

### U03 - Verify tap-to-seek alongside dragging

- **Own:** Seeking in `Redesigned/Player/PlayerControls.x`, `SGRPlayerPolicy.h`; player-policy regressions.
- **Do:** Check fraction clamping, RTL, valid duration and gesture coordination with existing drag seeking.
- **Accept:** Edge/outside taps clamp; invalid width/duration does not seek; RTL maps correctly; dragging
  remains continuous and wake touches from U02 do not seek.
- **Depends:** U02's touch contract; serialize with F08 controls edits.

## Entity-page visual finish

### E01 - Verify bounded content reveal and cover palette

- **Own:** `Redesigned/Kit/SGRPalette.*`, `SGRHeaderInfo.*` and the existing reveal helpers found there.
- **Do:** Check reusable page reveal/color contracts, bounded loading fallback and stale-page cancellation.
- **Accept:** Header/body appear together when ready; missing content reveals by the existing bounded timeout;
  old cover results cannot tint a new page. Test missing/slow/error cases.
- **Depends:** None; coordinate Kit reservations with B01.

### E02 - Validate reveal and color on each entity page

- **Own:** Exact `Redesigned/Album/`, `Playlist/` and `Artist/` header/field/row hooks; assign one page per agent.
- **Do:** Apply/verify E01 contracts without merging each page's hook implementation.
- **Accept:** Each page handles cached/slow/missing artwork and reload/reuse; content reveals together with
  bounded fallback and the field follows the correct cover. Record one result per page.
- **Depends:** E01; album edits wait for H01/H02 file handoff.

### E03 - Validate creator portraits and bottom fades

- **Own:** `Redesigned/Kit/SGRHeaderInfo.*` and exact entity action-row/fade consumers; reserve one page at a time.
- **Do:** Verify available creator/artist portraits beside names and passive fades beneath bottom bars.
- **Accept:** Missing images leave usable labels/actions; reused rows do not show stale faces; fades track
  insets, intercept no touches and work with accessory/separate now-playing bars.
- **Depends:** E01/E02; use alpha rather than hiding views inside Spotify's stack containers.

## Spicy Lyrics provider

### L01 - Validate the independent provider client

- **Own:** `Shared/LyricsSources/SpicyLyrics.m`; provider parsing/network fixtures.
- **Do:** Verify caller-owned publishable key, documented response parsing, rejection/status, cancellation,
  bounded cache and backoff. Confirm API contracts from official provider documentation when implementing.
- **Accept:** Valid/rejected/missing keys, malformed/oversize responses, 429/offline and track replacement
  are safe. Unsupported payloads fall through; no shared key or token logging.
- **Depends:** None; do not infer undocumented Line/Static/backing-voice shapes.

### L02 - Validate provider ordering and credit propagation

- **Own:** `Shared/LyricsSources/LyricsSources.*`, `LyricsSourcesPage.m` and exact hook integration by reservation.
- **Do:** Verify priority/disable behavior, credit metadata and restrictions on surfaces lacking linked attribution.
- **Accept:** Enabled/disabled/reordered provider selection works; richer credits reach both UI consumers;
  restricted lyrics do not leak to lock-screen/Live Activity surfaces without required links.
- **Depends:** L01; serialize lyrics-hook changes with F01/F03/A05.

### L03 - Validate linked credits in both lyrics looks

- **Own:** `Native/Lyrics/LyricsCredit.x` and exact `Redesigned/Lyrics/` credit consumers; assign one look per agent.
- **Do:** Display provider catalogue/community/contributor links from L02 metadata with validated destinations.
- **Accept:** Credits are visible, actionable and accessible in both looks; missing/malformed credit fields
  fail safely. Confirm registration/attribution obligations before redistribution; record unmet requirements.
- **Depends:** L02. Preserve intentional removal of unrelated upstream community/donation links.

## Connect discovery

### C01 - Verify bounded discovery without multicast entitlement

- **Own:** `Shared/Navigation/ConnectDiscovery.*`; discovery checks in `harness/connect/`.
- **Do:** Check Bonjour Connect/Cast browsing, independently proven Cast selection, denied-multicast bridge,
  lifecycle, retry limits and packet/service/address bounds.
- **Accept:** Successful native networking stays native; only denied supported-service operations bridge;
  permission denied/background/no consumers cancel safely. Real speakers/receivers remain C03 checks.
- **Depends:** None; no guessed Cast ABI.

### C02 - Preserve local-network metadata through packaging

- **Own:** Integration owner: `scripts/package-metadata.py`, `pipeline.sh`, `install.sh`,
  `plist/liquid-glass.plist`; relevant `harness/packaging/check.py` cases.
- **Do:** Verify safe merging of Bonjour declarations and local-network usage text before signing.
- **Accept:** Original text/services/unrelated ZIP members survive; additions are idempotent; malformed data
  fails atomically without modifying the supplied IPA. Both release/install pipelines exercise the merge.
- **Depends:** C01 service-name contract; coordinate icon metadata in I01.

### C03 - Validate bridge socket safety and device discovery

- **Own:** `harness/connect/` checks; production bridge edits only for reproduced failures, then reserve them.
- **Do:** Run production-wrapper socket checks for cookies, descriptor reuse, source addresses and receive
  semantics; test permission denial, IPv4/IPv6, disappeared devices and foreground return on iPhone.
- **Accept:** Stale/forged envelopes reject, addresses remain real and sockets stay bounded; actual Connect
  transfer/Cast pairing works without multicast entitlement. Record parser/device limitations explicitly.
- **Depends:** C01/C02; macOS/compiler and actual devices for full acceptance.

## Audio ownership and speed/pitch

### D01 - Verify the single audio owner and stage contract

- **Own:** `Core/SGAudioRouting.*`; `harness/audio-routing/`.
- **Do:** Inspect callers/rebindings; define input/output ownership, stage ordering and per-output state.
  Current pipeline is speed, effects, haptics; do not claim a Sing stage until S prerequisites pass.
- **Accept:** No competing processing owner or shared mutable processor across outputs; nested output chains
  process in defined order and source pulls are bounded. Preserve validation/error handling.
- **Depends:** None; one audio integration owner for D01-D04 and later S audio wiring.

### D02 - Verify route, format and disposal safety

- **Own:** Lifecycle/format handling in `Core/SGAudioRouting.*`, `Shared/Player/SGTimePitch.*`; routing regressions.
- **Do:** Check callback/source-bus replacement, rate/channel changes, local-file sample-rate correction,
  stop/disposal and concurrent render teardown.
- **Accept:** 44.1/48 kHz and multiple output chains render correctly; replacement/disposal cannot access
  freed state; limits hold on oversized pulls. Device route changes remain Q03 checks.
- **Depends:** D01.

### D03 - Verify effects and haptics use the owner once

- **Own:** `Shared/AudioEffects/AudioEffects.x`, `Shared/Haptics/MusicHaptics.x`; their routing integration checks.
- **Do:** Verify registration/cleanup with D01, remove competing ownership if present and retain DSP algorithms.
- **Accept:** Effects/haptics each observe/process once in the defined order, with per-output state, safe
  enable/disable and teardown. No render-thread allocations/blocking introduced by integration.
- **Depends:** D01/D02; engine algorithm changes are outside scope.

### D04 - Verify pitch follows speed and its controls

- **Own:** `Shared/Player/SGTimePitch.*`, `SpeedPitch.*`, `SpeedPitchMenu.x`; pitch/speed harness cases.
- **Do:** Check default-on coupled varispeed, disabled independent pitch while coupled and time stretching
  when uncoupled. Preserve migrated keys and both UI looks' access to shared controls.
- **Accept:** Coupled/independent/reset/invalid preference cases work at 44.1/48 kHz; toggling does not lose
  saved independent pitch or break playback. UI disabled state agrees with actual audio behavior.
- **Depends:** D01/D02; serialize menu edits with M02.

## Sing: evidence gates before implementation

### S01 - Establish a distributable on-device model

- **Own:** A new Sing evidence note under `docs/`; no downloaded model in source control.
- **Do:** Independently identify licensing/distribution permission, source, verified hash/size, conversion,
  runtime, supported OS/devices and measured CPU/GPU/memory/latency budget.
- **Accept:** Reproducible model provenance and runnable compatibility evidence, or a precise blocker.
  A model name/link alone is not approval to advertise Sing or ship a placeholder control.
- **Depends:** None; currently blocked prerequisites in the status document must be resolved.

### S02 - Prove Spotify streamed-source ownership and ABI

- **Own:** Read-only local Spotify binary/tree evidence; source-queue contract in the Sing evidence note.
- **Do:** Verify binary UUID, queue offsets/signatures, ownership, buffering and seek/track-transition contract.
- **Accept:** Locally reproducible evidence for every intercepted field/call, or explicit missing evidence.
  Objective-C class metadata alone cannot establish opaque source-queue/Swift contracts.
- **Depends:** None; serialize edits to the S01 evidence note or supply handoff text.

### S03 - Implement validated model download lifecycle

- **Own:** New model-management files in `Shared/Sing/` and their focused harness.
- **Do:** After S01 approval, implement bounded download/resume/cancel/remove, hash/size validation and
  atomic install using existing download patterns where suitable.
- **Accept:** Interrupted/corrupt/oversize downloads never become usable models; cancellation/removal and
  low-disk failures leave consistent state. No inference or player UI in this task.
- **Depends:** S01 proves model license/runtime/artifact contract.

### S04 - Implement bounded inference with pass-through fallback

- **Own:** New inference/runtime files in `Shared/Sing/`; synthetic audio/model harness.
- **Do:** Use S01's verified model for stem separation and vocal-level control with bounded buffering,
  worker execution and CPU/GPU lifecycle outside the render thread.
- **Accept:** Silence/short blocks/runtime failure/disable produce safe output; memory and latency meet
  the established budget. Failed initialization retains ordinary playback.
- **Depends:** S01/S03 and D01's processor contract.

### S05 - Integrate Sing and compensate timing

- **Own:** Exact Sing processor integration plus audio owner, player clock, lyrics and lock-screen callers
  reserved through their owners; new Sing timing regressions.
- **Do:** Insert Sing in an explicitly agreed audio stage order and account for measured inference latency.
  Implement seek/pause/track discontinuity resets using S02's proven source ownership.
- **Accept:** No old vocals/blocks after seek or A-to-B-to-A; lyrics/lock-screen timing follows audible audio;
  stop/disposal/route changes remain safe with Sing enabled and disabled.
- **Depends:** S02/S04 and D01-D03. No guessed streamed-source hooks.

### S06 - Add Sing settings and redesigned vocal control

- **Own:** New Shared Sing settings and exact Redesigned player control files; integration owner wires App pages.
- **Do:** Expose supported-device/model availability, vocal level and model lifecycle/status from S03-S05.
- **Accept:** Missing/downloading/invalid model and unsupported device show accurate states; controls do not
  imply working inference until ready; download/cancel/remove and accessibility work on device.
- **Depends:** S05, with S01's support matrix; no placeholder shipped while prerequisites are blocked.

## Alternate icons and composed settings

### I01 - Verify Prisma icon assets and safe packaging

- **Own:** Integration owner: `scripts/generate-icons.py`, icon portions of `package-metadata.py`,
  `docs/app-icons/`, icon packaging regressions.
- **Do:** Verify Prisma-owned PNG previews/variants, dimensions, iPhone/iPad entries and asset inclusion.
- **Accept:** PNGs decode, entries match packaged assets, primary/unrelated icons survive, collisions and
  malformed entries fail safely. Static PNG variants are not claimed as layered Liquid Glass assets.
- **Depends:** None; serialize shared metadata helper/checks with C02.

### I02 - Verify alternate icon selection and availability

- **Own:** `App/About/AppIcons.m`, `AboutSettings.m`, `About.h`; integration owner reserves these.
- **Do:** Verify previews, current selection, iOS availability and platform API completion/error handling.
- **Accept:** Switch each packaged icon, restore default, handle unsupported/failed requests and relaunch;
  settings reflect actual selection. Device icon switching is required for completion.
- **Depends:** I01. Layered icon tooling/appearance remains an explicit limitation.

### T01 - Verify the composed settings destinations

- **Own:** Integration owner: `App/Pages.*`, `App/ModSettings.x`; feature settings stay with feature owners.
- **Do:** Verify separate Lyrics/Karaoke root entries, Albums and player background destinations.
- **Accept:** Each available destination opens an `SPTPageController`-compatible page, each look shows only
  its applicable pages, migrated/reset settings remain correct and no dangling links exist.
- **Depends:** B02/H03/N03/L02 interfaces; serialize F04 drawer edits.

### T02 - Verify compatibility notices and preserve OS gates

- **Own:** Integration owner: App compatibility notices/onboarding; `Core/SGUIMode.*` read-only unless
  fixing a demonstrated gate bug.
- **Do:** Check unsupported Spotify notice, external-lyrics setting/notice and iOS 26 unavailability text.
- **Accept:** Spotify support warning is accurate; external-lyrics notice distinguishes manual compatibility
  from unverified Eevee auto-detection; below 26 both redesign queries return NO and no redesign hooks run.
- **Depends:** F03's actual guard behavior. No older-iOS opt-in authorized; see P01.

## Beta updates and releases

### R01 - Verify numeric prerelease version precedence

- **Own:** `App/About/Update.m`, `SGVersion.h`; `harness/update/versions.m` and comparator checks.
- **Do:** Inspect all comparator callers; check numeric release and prerelease components with malformed input.
- **Accept:** beta.2 sorts before beta.10, prerelease before its stable version and newer major/minor correctly;
  malformed/unsupported tags cannot become spurious updates. Run comparator regressions.
- **Depends:** None.

### R02 - Verify stable/beta filtering of fetched and cached releases

- **Own:** Release selection/cache paths in `App/About/Update.m` and required UpdatePage/Notice callers;
  channel/cache fixtures in `harness/update/`.
- **Do:** Verify build channel filtering, channel-aware cache refresh and unchanged Prisma release URLs.
- **Accept:** Stable excludes prereleases, beta accepts appropriate newer prereleases/stable releases;
  switching channel or reading stale cache cannot bypass filtering. Handle empty/failure responses.
- **Depends:** R01; one writer for Update.m.

### R03 - Verify beta Release Please automation

- **Own:** Integration owner: `release-please-config.json`, `release-please-beta-config.json`,
  `.release-please-manifest.json`, `.github/workflows/release.yml` and relevant build inputs.
- **Do:** Review beta branch config, tag/channel propagation and build-from-created-tag asset selection.
- **Accept:** Config parses; stable/beta routes are distinct and build intended tags/assets; Prisma URLs
  remain correct. Never hand-edit version.txt or publish/create releases to validate this task.
- **Depends:** R02's build-channel contract; actual hosted automation is a separate authorized release run.

## Deferred product decisions: reports only

### P01 - Record the older-iOS redesign decision

- **Own:** Decision handoff to the integration owner; read-only `Core/SGUIMode.*` and onboarding.
- **Do:** Explain iOS 26 Liquid Glass dependency, existing older-OS crash risk and current unavailable behavior.
- **Accept:** Record retain-gate recommendation and evidence needed for any future product reconsideration.
  No opt-in switch, gate change or older-iOS support claim.
- **Depends:** None; current AGENTS.md gate remains binding.

### P02 - Record alternate-edition and looser-matching choices

- **Own:** Decision handoff; read-only Apple matching/resolver and A02/A03 results.
- **Do:** Compare exact precedence with animated-edition substitution and any broader artist matching;
  identify wrong-album/artist risks and concrete fixtures before proposing changes.
- **Accept:** Explicit recommendation, current behavior and examples are documented; no relaxed matching
  or substituted edition shipped without a separate authorized implementation task.
- **Depends:** A02/A03 evidence.

### P03 - Record bounded clip-coverage choices

- **Own:** Decision handoff; read-only HLS/video validation and A03/A04 results.
- **Do:** Identify permitted real clips rejected by existing limits/formats and the minimum safe extension.
- **Accept:** Each proposal names evidence, resource bounds and required validation; preserve current
  security/URL/resource checks. No arbitrary size increase or unsupported playlist acceptance.
- **Depends:** A03/A04 evidence; no access to original-project release clips.

### P04 - Record artwork default and icon fidelity choices

- **Own:** Decision handoff; read-only artwork settings and I01/I02 results.
- **Do:** Record off-by-default animation versus requested default-on behavior, and static PNG icons versus
  layered Liquid Glass variants/tooling. Identify power/data and platform/toolchain requirements.
- **Accept:** Keep current defaults/assets unless a separate task is authorized; document deliberate
  differences without calling them exact beta parity. No upstream donation/reporting/CLA restoration.
- **Depends:** I01/I02 for icon evidence; artwork default decision can be recorded independently.

## Integration validation

### Q01 - Run artwork harnesses and real hook-order checks

- **Own:** Validation results handed to the integration owner; reserve production files only for failed checks.
- **Do:** On macOS run `harness/animated-artwork/check.sh`, `canvas/check.sh`, `artwork-video/check.sh` and
  `apple-music-artwork/check.sh` using `sh` and the full `harness/` prefix. Exercise both real
  MediaPlayer/lock-screen lyrics hook orders on an iOS 26 iPhone.
- **Accept:** Record exact commands/results, supported shapes, failure/motion/power cases, missing identity,
  rapid changes and protected-file/lease behavior. Source-only and stubbed checks remain labelled as such.
- **Depends:** A01-A05 and any relevant consumer fixes; blocked without macOS/iPhone access.

### Q02 - Compile and validate both UI looks

- **Own:** Integration owner plus validation agent; status updates applied centrally.
- **Do:** Run layers/relevant harnesses, then `env -u MAKELEVEL gmake -C tweak clean package` on macOS.
  Build/install with documented setup and verify Native/Redesigned on Spotify 9.1.78, Free and Premium.
- **Accept:** Record build output and player/Navbar/entity/lyrics/settings/icon results, including transitions,
  VoiceOver, Reduce Motion, sheets and provider failures. No exact-parity claim while M/S remain blocked.
- **Depends:** Integrated nonblocked UI tasks; record blocked tasks separately rather than waiting for Sing.

### Q03 - Validate real audio routes and nearby devices

- **Own:** Audio/discovery validation results; integration owner updates the status document.
- **Do:** Run routing/pitch/effects/haptics and Connect socket harnesses, then test local files at 44.1/48 kHz,
  multiple outputs/routes, speed/pitch/effects/haptics combinations and real Connect/Cast devices.
- **Accept:** No duplicate processing, stale/disposed callbacks or broken transfer; record latency/performance,
  permission/foreground/network changes and actual device details. Sing adds its own S05/S06 device checks
  only after prerequisites pass.
- **Depends:** C01-C03/D01-D04; iPhone and suitable receivers/routes required for device completion.
