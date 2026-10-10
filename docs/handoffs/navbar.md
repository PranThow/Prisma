## N01 - Verify mini-player accessory content and actions

- **Changed:** `tweak/Sources/Redesigned/Navbar/MiniPlayer.inc`; `harness/tabbar/main.m`.
- **Behavior:** The integrated mini-player is a VoiceOver button that opens the player on activation and exposes Previous track and Next track custom actions. Existing metadata updates, playback toggling, swipe skips, and normal touch handling are unchanged.
- **Checks:** `git diff --check` passed before commit. The tab-bar harness now asserts the mini-player is an accessibility button with both actions.
- **Remaining:** Windows has no Apple SDK, simulator, or device, so `harness/tabbar/build.sh` and the device checks were not run. On device, verify VoiceOver activation/custom actions, late metadata/artwork, one skip per swipe, and behavior while the separate now-playing bar is present.
