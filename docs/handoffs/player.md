# Player lane handoffs

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
