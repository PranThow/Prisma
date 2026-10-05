# Prisma

Prisma is an independent GPL v3 fork of spoti.pw, maintained in `PranThow/Prisma`. It is a Theos
tweak (Objective-C + Logos) injected into a decrypted Spotify 9.1.78 iOS app. The full guide is
`docs/tweaks.md`; read it before changing code.

## Project identity

- Use **Prisma** in new project-facing documentation and links. The repository is
  `https://github.com/PranThow/Prisma`; releases and issues belong there.
- Preserve the GPL v3 license and existing copyright and upstream attribution notices.
- The code and build pipeline still carry upstream names: `spotifyglass.` preference keys,
  `[spotifyglass]` logs, `SG` / `SGR` symbols, and the `com.spotipw` package identifier.
  Keep documentation accurate to the current implementation. Renaming persisted keys or identifiers
  requires checking compatibility and migrations; a branding edit alone should not rename them.

## Two looks, never both

**Redesigned UI** (Mod Settings → Appearance) picks one of two looks, read once at launch:

- **Native**: Spotify's own screens with the mod's tweaks on them (hide switches, glass header buttons,
  Home gradient, AMOLED switch, accent colour...).
- **Redesigned**: the mod's own Liquid Glass look, from a clean sheet. It includes the glass tab bar,
  search field and now playing bar, the redesigned player and lyrics page with Apple Music style lyrics
  always on, a decluttered Home, Search's categories on tinted glass, a Library with one large title, the
  playlist, album and artist pages the way the Music app lays them out with one pinned ⋯ over each, black
  throughout, and its own accent colour. No native tweak runs.

Anything that doesn't draw on Spotify's screens works the same under both: privacy, lyrics
sources, gestures, blocked artists, flags, Vibrations, Speed and pitch, and the Live Activity. Those
last three were the redesign's until they moved to `Shared/`, so their keys lost the `.redesign.` and
`Core/SGPrefs.h`'s `SGMigrateKey` carries the old ones over at launch.

**The redesign needs iOS 26.** It is Liquid Glass, which the system draws from 26 on and no older OS
can be given, so `SGRedesignAvailable()` (`Core/SGUIMode.h`) holds it there: below 26 both
`SGRedesignedUI()` and `SGRedesignedUIStored()` answer NO whatever is stored, the switch becomes a
"Needs iOS 26" row and the tour greys its card out. The native look's floor is iOS 16.1, which is
Spotify 9.1.78's own.

## Where code goes (`tweak/Sources/`)

| Layer | What | Gate at the top of every `%ctor` |
|---|---|---|
| `Shared/` | behaviour and data, either look | none |
| `Native/` | Spotify's screens tweaked | `if (!SGNativeUI()) return;` |
| `Redesigned/` | the redesign (`Kit/` + parts) | `if (!SGRedesignedUI()) return;` |
| `App/` | Mod Settings root and combined pages, Mod page, tour | none |
| `Core/`, `Settings/`, `Headers/`, `Diagnostics/` | infrastructure | none |

Rules:

- Imports run one way: `Core <- Settings <- Shared <- Native | Redesigned <- App`. Native and
  Redesigned never import each other. `scripts/check-layers.sh` runs before every build and fails on a
  violation. Don't work around it.
- Change one look without touching the other. When both need the same thing, each side keeps its own
  copy under its own names (`SG…` native, `SGR…` redesign) and its own keys. Examples are the tab bar
  composition and editor, AMOLED and the accent colour. Don't merge copies back into
  a shared file.
- A lower layer that needs something from a higher one gets it through a registry in `Core`
  (forced flags: `Core/SGFlagForce.h`) or a function declared low and defined high.
- Settings: each layer builds its own rows and sections. `App/Pages.m` and `App/ModSettings.x`
  decide what to show from `SGRedesignedUIStored()`, so native-only pages disappear in the redesign.
- Keys start with `spotifyglass.` (redesign-only ones with `spotifyglass.redesign.`). Switches are
  read at launch, so a change needs a restart.

## Working on it

- Build: `make install` (signs and pushes to the phone), `make release` (IPA only). Tweak only:
  `env -u MAKELEVEL gmake -C tweak clean package`.
- Local builds require macOS and the tools described in `README.md`. On Windows, documentation
  edits can be checked locally, but the iOS build cannot be validated there. Report that limit.
- `make release` writes `out/Prisma-<version>.ipa`; `make install` writes `out/Prisma-dev.ipa`.
  Local installs use the Prisma display name; `DEV_NAME` can override it.
- Look at Spotify's views through recorded trees (`make session` records clean ones into
  `trees/clean/`) before hooking anything. Prove every class and selector against the tree or the binary.
- Device log: `make log` (`[spotifyglass]` lines).
- Releases: Release Please (`.github/workflows/release.yml`). Commit as `feat:` / `fix:` (they bump
  `version.txt` and fill `CHANGELOG.md`; `chore:`, `refactor:` and `docs:` stay out). Merging its
  release PR tags `vX.Y.Z` and attaches the `.deb`. Never edit `version.txt` by hand.
- Keep the existing commit style: a lowercase conventional prefix followed by a plain description
  of the resulting change. Use `docs:` for documentation; add a body when the reason or validation
  needs explaining.
- Known traps: anything pushed onto Spotify's nav stack must conform to `SPTPageController`
  (`Settings/SGPage.m`). Setting `hidden` on views inside Spotify's `OverflowStackView` or its Encore
  stacks crashes, so use alpha. A `CADisplayLink` capped at 60 Hz drags the player's 120 Hz
  transitions down with it. Glass takes the appearance it inherits, and outside Spotify's navigation
  stacks (the tab bar, the now playing bar, the player) that is the system's: set every pane of the
  mod's to `overrideUserInterfaceStyle = UIUserInterfaceStyleDark`, or it goes light in light mode.
