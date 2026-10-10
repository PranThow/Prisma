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
