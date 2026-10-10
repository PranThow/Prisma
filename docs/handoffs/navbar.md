## N01 - Verify mini-player accessory content and actions

- **Changed:** `tweak/Sources/Redesigned/Navbar/MiniPlayer.inc`; `harness/tabbar/main.m`.
- **Behavior:** The integrated mini-player is a VoiceOver button that opens the player on activation and exposes Previous track and Next track custom actions. Existing metadata updates, playback toggling, swipe skips, and normal touch handling are unchanged.
- **Checks:** `git diff --check` passed before commit. The tab-bar harness now asserts the mini-player is an accessibility button with both actions.
- **Remaining:** Windows has no Apple SDK, simulator, or device, so `harness/tabbar/build.sh` and the device checks were not run. On device, verify VoiceOver activation/custom actions, late metadata/artwork, one skip per swipe, and behavior while the separate now-playing bar is present.

## N02 - Verify compact accessory layout and minimization

- **Changed:** `harness/tabbar/main.m`.
- **Behavior:** The existing compact layout keeps the first and last visible-tab targets at the mini-player's edges, with the cover, text and playback target between them. The regression now checks its three controls and their non-overlap at 320 pt wide.
- **Checks:** `git diff --check`; source inspection of `MiniPlayer.inc` and `TabBar.x`. The Apple SDK harness cannot run on Windows.
- **Remaining:** Run `harness/tabbar/build.sh` and exercise reordered, hidden and custom tabs, interrupted scroll minimization, safe-area changes, and real touch forwarding on a simulator/device.

## N03 - Complete mini-player preference and mode switching

- **Changed:** `docs/handoffs/navbar.md`.
- **Behavior:** No source change was needed. `NavbarSettings.m` persists the optional integrated-player preference, while `MiniPlayer.inc` and `NowPlayingBar.x` each snapshot it once at launch. An enabled launch presents the accessory and suppresses the separate bar; a disabled launch retains the separate bar. Native mode remains separate behind its own UI gate.
- **Checks:** `git fetch origin && git merge origin/main` (already up to date); PowerShell source-contract check for the preference plus both launch-time `dispatch_once` readers (passed); `git diff --check` (passed).
- **Blockers:** None in the owned files. The separate-bar integration is already present but outside this task's reservation, so it was inspected only.
- **Remaining:** Windows cannot run `harness/tabbar/build.sh`, compile the iOS tweak, or validate device behavior. On macOS/iPhone, relaunch with the preference enabled and disabled; verify one player surface, no duplicate gestures/subscriptions or blank spacing, then verify Native mode remains unchanged.
