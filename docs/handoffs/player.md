# Player lane handoffs

## M01 - Establish the real Spotify action-menu contract

- **Changed files:** `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** Blocked without inventing action behavior. `PlayerHeader.x` proves only the More button identifier and hands it to the existing Speed/pitch observer. `SpeedPitchMenu.x` proves the context-menu controller's UIKit layout/appearance hooks and table insertion, but its comments and implementation correctly leave Spotify's opaque Swift item factories, action enumeration, cached initial rows, refresh, share and navigation behavior untouched.
- **Executed checks:** PowerShell evidence inventory passed: `rg --files trees out tweak | rg -i 'menu|context|player|spotify$|evidence'` confirmed no recorded trees or local executable are available; `rg -n 'ContextMenu|ItemFactory|HeaderElements|now-playing-minimize-button|Context menu' ...` confirmed the current hook contains no action-model selector contract. `git diff --check` passed.
- **Blockers and macOS/device checks still owed:** Supply the decrypted Spotify 9.1.78 executable matching UUID `C712370B-44CD-35C8-A058-4FBED1AD0758`, with Swift metadata/disassembly sufficient to prove action model and callback selector/type/lifetime contracts. Record the player More menu on that build from initial presentation through loading/refresh, each share/navigation action, dismissal, and a track switch while open. Then establish M02's exact actions and stale-track behavior on iOS 26.

## V03 - Verify video cover transitions and accessibility

- **Changed files:** `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** The existing player-video integration keeps the Spotify cover visible until its video surface is ready, hides only the cover and shadow while video is active, and restores them for pending, failed, stopped, paused, dismissed, foreground/power/motion-policy, and player-transition states. The video layer neither receives touches nor participates in VoiceOver; the existing artwork-list gesture attachment therefore remains available for swipe-to-skip and player controls remain exposed. Artwork layout re-applies visibility when a cover changes during video playback, so a skip cannot reveal a replacement cover under the video.
- **Executed checks:** `python harness/player-video/check-source.py` passed (ordered fallback, leased looping playback, readiness and stale/failure fallback). `python -m py_compile harness/player-video/check-source.py` and `git diff --check` passed.
- **Blockers and device checks still owed:** Run `sh harness/player-video/check.sh` and `env -u MAKELEVEL gmake -C tweak clean package` on macOS. On iOS 26 with Spotify 9.1.78, exercise player open/close and interrupted transitions, swipe-to-skip, pause/dismiss/foreground, Low Power Mode, Low Data Mode, Reduce Motion and video-autoplay changes; verify the cover always returns after pending/failure/stop, playback is paused off-policy, and VoiceOver/player controls remain usable.

## V02 - Verify looping video, provider order and fluid fallback

- **Changed files:** `harness/player-video/check-source.py`, `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** The existing player video consumer independently normalizes the Canvas/Apple order, retains the prepared-video lease, loops ready video with `AVPlayerLooper`, and only covers the fluid field after the video surface is ready. Lookup, preparation and playback failures advance to the next provider; exhausted providers leave the fluid field visible. Generation guards discard late work after track/provider changes, and Canvas consumer activation stays independent of lock-screen settings.
- **Executed checks:** `python harness/player-video/check-source.py` passed (ordered fallback, leased looping playback, readiness and stale/failure fallback). `python -m py_compile harness/player-video/check-source.py` and `git diff --check` passed.
- **Blockers and device checks still owed:** Run `sh harness/player-video/check.sh` and `env -u MAKELEVEL gmake -C tweak clean package` on macOS. On iOS 26 with Spotify 9.1.78, exercise both provider orders, lookup/preparation/player failures, rapid A-to-B-to-A changes, looping through an end boundary, and all-miss fluid fallback; verify neither provider preference changes lock-screen order.

## V01 - Verify independent visible-consumer artwork requests

- **Changed files:** `harness/canvas/resolver.m`, `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** Canvas resolution remains independent of lock-screen availability and preferences while any visible in-app consumer is registered. Removing one of two consumers now has a regression assertion proving the other still retains the result; removing the final consumer clears the result and cancels any work. Player and browsed-album Apple resolver/preparer instances remain separate, so album state cannot replace the current-track publisher state.
- **Executed checks:** PowerShell V01 source-contract check passed (Canvas consumer registration is independent of lock-screen settings; Player and Album use separate Apple resolver/preparer instances). `git diff --check` passed.
- **Blockers and device checks still owed:** Run `sh harness/canvas/check.sh`, `sh harness/apple-music-artwork/check.sh` and `env -u MAKELEVEL gmake -C tweak clean package` on macOS. On iOS 26 with Spotify 9.1.78, disable lock-screen animation while the player video is visible; verify it continues, then hide the final visible consumer and confirm cancellation. Browse album B while track A plays, including A-to-B-to-A changes, and confirm neither the player nor lock-screen publisher shows B's result.

## B03 - Verify fluid player lifecycle

- **Changed files:** `harness/player-fluid/check-source.py`, `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** The existing Player field keeps a track URI with its settled cover, updates from published now-playing artwork, and holds motion for paused playback or video. The shared field lifecycle already stops renderer motion off-window, inactive, in player transitions, Reduce Motion, or Low Power Mode, then resumes when eligible. The source regression now locks those contracts down.
- **Executed checks:** `python harness/player-fluid/check-source.py` passed (`Fluid source: serial renderer, stale-cover rejection and lifecycle gating passed`). `git diff --check` passed.
- **Blockers and device checks still owed:** Run `sh harness/player-fluid/check.sh` and `env -u MAKELEVEL gmake -C tweak clean package` on macOS. On iOS 26 with Spotify 9.1.78, verify rapid cover changes, pause/resume, background/foreground, Reduce Motion and Low Power transitions, then dismiss/reopen the player; confirm the last valid background remains visible, renderer work stops while ineligible, and it resumes without stale frames or transition jank.

## B02 - Complete fluid controls, preview, reset and migration

- **Changed files:** `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** The existing Player background page already exposes bounded Speed, Warp, Blur, Saturation and Brightness controls. Its always-flowing current-cover preview and the full player refresh their render settings after defaults changes; reset removes exactly those overrides. The existing launch migration moves the legacy moving-background key only when Fluid cover has no stored value, preserving a user's newer setting.
- **Executed checks:** PowerShell B02 source-contract check passed. `python harness/player-fluid/check-source.py` passed (`Fluid source: serial renderer and stale-cover rejection passed`). `git diff --check` passed.
- **Blockers and device checks still owed:** Build with `env -u MAKELEVEL gmake -C tweak clean package` and run `sh harness/player-fluid/check.sh` on macOS. On iOS 26 with Spotify 9.1.78, change each control and reset it while the page and full player are visible; confirm immediate preview/player updates, bounded malformed stored values, and legacy-key migration without overwriting a newer Fluid-cover choice.

## U03 - Verify tap-to-seek alongside dragging

- **Changed files:** `tweak/Sources/Redesigned/Player/PlayerControls.x`, `tweak/Sources/Redesigned/Player/SGRPlayerPolicy.h`, `harness/player-policy/main.c`, `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** Slider taps clamp and account for RTL as before; non-finite/zero durations and an in-progress slider drag now explicitly prevent seeking. The policy regression covers invalid widths, durations, fractions, and the drag guard.
- **Executed checks:** PowerShell source-wiring check passed. `git diff --check` passed. The policy harness could not run: this Windows host has no `cc` compiler.
- **Blockers and device checks still owed:** Build and run `sh harness/player-policy/check.sh` on macOS. On iOS 26 with Spotify 9.1.78, verify leading/trailing and outside-track taps in LTR/RTL, no seek for unavailable/zero duration, continuous slider dragging, and that the first immersive-lyrics wake touch does not seek.

## F06 - Preserve paused cover scale through transitions

- **Changed files:** `tweak/Sources/Redesigned/Player/PlayerArtwork.x`, `tweak/Sources/Redesigned/Player/SGRPlayerPolicy.h`, `harness/player-policy/main.c`.
- **Result:** The full-screen cover holds its scale from the start of a player open or close transition. Playback changes during the morph apply after it completes, so the cover does not jump and resumes at the correct playing scale.
- **Executed checks:** `git diff --check` passed. Source wiring check passed (`Player transition-scale wiring present`). The policy harness was not run: this Windows host has no `cc` compiler.
- **Remaining blockers and device checks:** Build and test on macOS/iOS 26 with Spotify 9.1.78: paused open/close, resume during an open or close, and interrupted interactive transitions. Confirm the cover remains stable during the morph and returns to the correct scale afterwards.

## F07 - Free-player class and selector contracts

- **Result:** The five hooked `ReinventFree` units are Objective-C subclasses of
  `UIViewController` and each implements `-viewDidLayoutSubviews` with ABI `v16@0:8` in the
  supplied decrypted Spotify 9.1.78 executable (UUID
  `C712370B-44CD-35C8-A058-4FBED1AD0758`).

  | Hooked area | Class | Proven selector | Runtime layout evidence |
  | --- | --- | --- | --- |
  | Header | `ReinventFreeNavigationBarUnitViewController` | `-viewDidLayoutSubviews` (`v16@0:8`) | Missing |
  | Controls | `ReinventFreePlaybackControlsElementsUnit` | `-viewDidLayoutSubviews` (`v16@0:8`) | Missing |
  | Footer | `ReinventFreeFooterElementsUnit` | `-viewDidLayoutSubviews` (`v16@0:8`) | Missing |
  | Lyrics information | `ReinventFreeInformationElementsUnit` | `-viewDidLayoutSubviews` (`v16@0:8`) | Missing |
  | Lyrics duration | `DurationElementsUnit` | `-viewDidLayoutSubviews` (`v16@0:8`) | Missing |

- **Changed file:** `harness/objc-evidence/check.py` now checks the layout selector and its type
  encoding for every listed Free unit, instead of only the duration unit.
- **Evidence command:** `python harness/objc-evidence/check.py out/parity-evidence/Spotify`.
  It passed when the supplied executable was available; the ignored `out/parity-evidence/` file
  is not present in this checkout, so it could not be rerun here.
- **Blocker for F08:** Binary metadata proves these hooks can safely call UIKit's layout callback.
  It cannot prove the Free view hierarchy or the identifiers consumed by the shared styling helpers.
  Record a Spotify 9.1.78 Free-player tree for each row before changing the four Player hook files;
  otherwise F08 remains blocked.

## U01 - Verify four-second immersive lyrics eligibility

- **Changed files:** `harness/player-policy/main.c`.
- **Result:** Immersive lyrics already use one invalidated idle timer and remain ineligible while playback is paused, the app is inactive, VoiceOver is running, a sheet is presented, or a player transition is active. The policy regression now also rejects a non-finite last-touch timestamp.
- **Executed checks:** `git diff --check` passed. PowerShell source wiring check passed (`U01 source wiring check passed`). `sh harness/player-policy/check.sh` could not run because this Windows host has no `sh` command.
- **Remaining blockers and device checks:** Build and run `sh harness/player-policy/check.sh` on macOS. On iOS 26 with Spotify 9.1.78, verify four-second expansion during untouched playback; cancellation and restoration for pause, VoiceOver, app background/foreground, presented sheets, and player transitions; and rapid state changes for duplicate timers or stale callbacks.

## U02 - Verify wake-touch consumption and thumbnail return

- **Changed files:** `tweak/Sources/Redesigned/Player/PlayerLyrics.x`, `docs/parity-checklist.md`, `docs/handoffs/player.md`.
- **Result:** The existing wake recognizer consumes the first touch only while immersive lyrics are active, restoring the faded controls before it can activate a lyric or control. The thumbnail already closes lyrics; once its close transition restores Spotify's cover, VoiceOver is now moved to that restored artwork rather than the removed thumbnail.
- **Executed checks:** `git diff --check` passed. PowerShell source wiring check passed: the wake recognizer records the immersive state before restoring controls, cancels/delays touches, and the close completion restores the cover before posting a layout change to it.
- **Remaining blockers and device checks:** Build on macOS, then on iOS 26 with Spotify 9.1.78 verify the first touch during immersive lyrics only wakes controls; a subsequent lyric/control gesture works; thumbnail return restores artwork and VoiceOver focus; and taps/drags remain safe while immersion begins or ends.

## B01 - Verify the cover-based fluid renderer

- **Changed files:** `harness/player-fluid/main.m`, `harness/player-fluid/check.sh`, `harness/player-fluid/check-source.py`, `docs/parity-checklist.md`, `docs/handoffs/player.md`, `.lane-commit-msg`.
- **Result:** The existing renderer remains the bounded 160×160 Core Image cover warp/blur/color pipeline on one serial queue. It clamps every persisted parameter, retains the last frame while paused, and rejects superseded generations before publishing. Regressions now prove the frame changes with a different supplied cover and assert the serial-queue/stale-generation source contract.
- **Executed checks:** `python harness/player-fluid/check-source.py` passed (`Fluid source: serial renderer and stale-cover rejection passed`). `git diff --check` passed.
- **Remaining blockers and device checks:** Run `sh harness/player-fluid/check.sh` and `env -u MAKELEVEL gmake -C tweak clean package` on macOS. On iOS 26 with Spotify 9.1.78, exercise rapid A→B→A cover replacement, pause/resume, Reduce Motion and Low Power Mode; confirm no stale frame is published and that transitions stay smooth.
