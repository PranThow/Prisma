# Player lane handoffs

## F06 - Preserve paused cover scale through transitions

- **Changed files:** `tweak/Sources/Redesigned/Player/PlayerArtwork.x`, `tweak/Sources/Redesigned/Player/SGRPlayerPolicy.h`, `harness/player-policy/main.c`.
- **Result:** The full-screen cover holds its scale from the start of a player open or close transition. Playback changes during the morph apply after it completes, so the cover does not jump and resumes at the correct playing scale.
- **Executed checks:** `git diff --check` passed. Source wiring check passed (`Player transition-scale wiring present`). The policy harness was not run: this Windows host has no `cc` compiler.
- **Remaining blockers and device checks:** Build and test on macOS/iOS 26 with Spotify 9.1.78: paused open/close, resume during an open or close, and interrupted interactive transitions. Confirm the cover remains stable during the morph and returns to the correct scale afterwards.
