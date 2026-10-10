# Integration handoffs

## F04 — reattach one Mod Settings drawer row

- Changed files: `docs/parity-checklist.md`, `docs/handoffs/integration.md`. `tweak/Sources/App/ModSettings.x` already contained the required implementation.
- Behavior: the drawer keeps one associated `SGModSettingsRow`; every drawer layout reattaches that same row if Spotify has removed its child views, lays it out above the first item, and preserves its existing open action.
- Commands/results: F04 PowerShell source-contract check passed (drawer hook, associated-row reuse, drawer mode, reattachment, placement, and action). `PATH=/usr/bin:/bin:$PATH sh scripts/check-layers.sh tweak/Sources` passed through Git Bash. `git diff --check` passed.
- Blockers: no source blocker. Runtime acceptance needs Spotify's real drawer rebuild behavior.
- macOS and device checks owed: compile the tweak on macOS, then on Spotify 9.1.78 repeatedly open/rebuild the side drawer and verify exactly one working Mod Settings row remains.
