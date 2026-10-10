# Integration handoffs

## F04 — reattach one Mod Settings drawer row

- Changed files: `docs/parity-checklist.md`, `docs/handoffs/integration.md`. `tweak/Sources/App/ModSettings.x` already contained the required implementation.
- Behavior: the drawer keeps one associated `SGModSettingsRow`; every drawer layout reattaches that same row if Spotify has removed its child views, lays it out above the first item, and preserves its existing open action.
- Commands/results: F04 PowerShell source-contract check passed (drawer hook, associated-row reuse, drawer mode, reattachment, placement, and action). `PATH=/usr/bin:/bin:$PATH sh scripts/check-layers.sh tweak/Sources` passed through Git Bash. `git diff --check` passed.
- Blockers: no source blocker. Runtime acceptance needs Spotify's real drawer rebuild behavior.
- macOS and device checks owed: compile the tweak on macOS, then on Spotify 9.1.78 repeatedly open/rebuild the side drawer and verify exactly one working Mod Settings row remains.

## I01 - verify Prisma icon assets and safe packaging

- Changed files: `harness/packaging/check.py`, `docs/parity-checklist.md`, `docs/handoffs/integration.md`, `.lane-commit-msg`.
- Behavior: the packaging regression now verifies all twelve Prisma-owned icon assets after IPA packaging: iPhone `@2x`/`@3x` and iPad/iPad Pro variants decode with their declared dimensions. It also asserts the generated iPhone and iPad alternate-icon entries name the matching asset families. Existing metadata merging keeps Spotify's primary and unrelated alternate icons, rejects collisions/malformed data, and writes atomically.
- Commands/results: `python harness/packaging/check.py` passed (`metadata preservation, atomic packaging and icon decoding passed`); `python -m py_compile scripts/generate-icons.py scripts/package-metadata.py harness/packaging/check.py` passed; `C:\\Program Files\\Git\\bin\\bash.exe -lc 'PATH=/usr/bin:/bin:$PATH; sh scripts/check-layers.sh tweak/Sources'` passed; `git diff --check` passed.
- Blockers: no source blocker. These are static PNG alternates, not layered Liquid Glass/Icon Composer assets.
- macOS and device checks owed: package/sign on macOS, then on an iPhone and iPad verify each alternate icon is available, switches correctly, and restores the default icon after relaunch.

## I02 - verify alternate icon selection and availability

- Changed files: `docs/parity-checklist.md`, `docs/handoffs/integration.md`, `.lane-commit-msg`. No production source change was made.
- Behavior: source inspection confirms the existing App icon page previews the packaged default and three Prisma variants, derives its checkmark from `alternateIconName`, gates the entry on iOS availability, `supportsAlternateIcons`, and packaged metadata, and handles completion errors before reloading the actual selection.
- Commands/results: I02 PowerShell source-contract check passed (availability, metadata, selection, completion, and error handling). `python harness/packaging/check.py` passed (`metadata preservation, atomic packaging and icon decoding passed`). `C:\\Program Files\\Git\\bin\\bash.exe -lc 'PATH=/usr/bin:/bin:$PATH; sh scripts/check-layers.sh tweak/Sources'` passed. `git diff --check` passed.
- Blockers: Windows cannot build/sign the Prisma IPA or invoke UIKit's alternate-icon API. Device switching is required for task completion.
- macOS and device checks owed: package/sign on macOS, then on an iPhone and iPad select Violet, Emerald, and Pearl; restore Default; verify the Home Screen result, error/unsupported handling, and the selected row after each relaunch.

## C02 - preserve local-network metadata through packaging

- Changed files: `harness/packaging/check.py`, `docs/parity-checklist.md`, `docs/handoffs/integration.md`, `.lane-commit-msg`.
- Behavior: before signing, both release (`pipeline.sh`) and local-install (`install.sh`) paths use the same atomic package merge. It preserves Spotify's nonempty local-network explanation and Bonjour services, adds the Connect and Cast service types without duplicates, keeps unrelated IPA members, and rejects malformed declarations without changing the supplied IPA.
- Commands/results: `python harness/packaging/check.py` passed (`metadata preservation, atomic packaging and icon decoding passed`); `python -m py_compile scripts/package-metadata.py harness/packaging/check.py` passed. The new regression proves malformed `NSBonjourServices` fails while an in-place input IPA remains byte-for-byte unchanged.
- Blockers: no source blocker. Windows cannot execute the macOS release/install signing paths.
- macOS and device checks owed: run `make release` and `make install` on macOS with a disposable decrypted IPA, then confirm the post-signing app requests local-network access with Spotify's original explanation and discovers a Connect device and Cast receiver.

## T01 - verify the composed settings destinations

- Changed files: `docs/parity-checklist.md`, `docs/handoffs/integration.md`, `.lane-commit-msg`. No production source change was needed.
- Behavior: the existing root keeps separate Lyrics and Redesigned-only Karaoke entries; Albums opens the stored look's matching page. Player keeps Native-only Now playing bar, Queue & devices, and player-screen rows separate from Redesigned Now playing, while Home & Library remains Native-only. All composed destinations are `SGModPage`-compatible or existing page-controller factories, with no dangling function reference found.
- Commands/results: T01 PowerShell source-contract check passed (root destinations, look gates, shared/native Lyrics rows, Karaoke `SGModPage`, Albums selection, and Player destination selection). `C:\\Program Files\\Git\\bin\\bash.exe -lc 'PATH=/usr/bin:/bin:$PATH; sh scripts/check-layers.sh tweak/Sources'` passed. `git diff --check` passed.
- Blockers: no source blocker. Windows cannot compile the Objective-C tweak or exercise Spotify navigation/reset behavior.
- macOS and device checks owed: compile on macOS, then on Spotify 9.1.78 open every root destination in both looks; switch looks and restart; confirm the correct look-only rows, lyrics/Karaoke separation, album and background pages, and persisted/reset settings with no dead links.

## T02 - verify compatibility notices and preserve OS gates

- Changed files: `tweak/Sources/App/ModSettings.x`, `tweak/Sources/Shared/Lyrics/LyricsSettings.m`, `docs/parity-checklist.md`, `docs/handoffs/integration.md`, `.lane-commit-msg`.
- Behavior: unsupported Spotify versions show the installed version and accurately state that Prisma targets 9.1.78. The external-lyrics setting and its active notice now explicitly say it is a manual compatibility control and Eevee is not detected automatically; it continues to disable both source hooks and forced lyrics flags. The iOS 26 redesign gate remains unchanged: both redesign queries answer NO below iOS 26, the Appearance row says "Needs iOS 26", the tour disables its redesign card, and redesign `%ctor`s remain gated.
- Commands/results: `python harness/audio-lyrics/check.py` passed (`Spicy request lifecycle, source extraction and compatibility guards passed; Objective-C runtime checks require macOS.`). T02 PowerShell source-contract check passed (Spotify notice, manual/Eevee wording, external-lyrics guard, iOS 26 availability and both redesign-query gates). `C:\\Program Files\\Git\\bin\\bash.exe -lc 'PATH=/usr/bin:/bin:$PATH; sh scripts/check-layers.sh tweak/Sources'` passed. `git diff --check` passed.
- Blockers: Windows cannot compile the Objective-C tweak or exercise UIKit and Spotify runtime hooks.
- macOS and device checks owed: compile on macOS, then on Spotify 9.1.78 verify the unsupported-version notice, manual external-lyrics compatibility after restart, no claimed Eevee auto-detection, and on pre-iOS 26 that Native alone starts while the Appearance and tour notices remain accurate.
