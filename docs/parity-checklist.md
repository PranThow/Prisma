# Parity checklist

Every task in `docs/prisma-parity-tasks.md`, grouped by lane. The lane agent that owns a section
updates only its own section, in the same commit as the task:

- `- [x]` done as far as this Windows host allows; macOS and device checks owed are in the lane's handoff.
- `- [ ] ... — blocked: <reason>` can't progress without what the reason names.
- `- [ ]` with no reason is still to do.

The parity run stops once no item is left to do. Blocked items are the macOS session's list; Q01-Q03
close parity on a real device.

## Lyrics <!-- lane: lyrics -->

- [x] **F01** Keep serialized lyric starts nondecreasing
- [x] **F03** Suppress competing external lyrics hooks
- [x] **L01** Validate the independent provider client
- [x] **L02** Validate provider ordering and credit propagation
- [ ] **L03** Validate linked credits in both lyrics looks
- [ ] **F02** Retry lyrics after a background track change

## Player <!-- lane: player -->

- [x] **F06** Preserve paused cover scale through transitions
- [x] **F07** Verify Free-player class and selector contracts
- [ ] **F08** Complete verified Free-player hooks — blocked: needs recorded Free-player trees (`make session`) and the Spotify binary
- [x] **U01** Verify four-second immersive lyrics eligibility
- [ ] **U02** Verify wake-touch consumption and thumbnail return
- [ ] **U03** Verify tap-to-seek alongside dragging
- [ ] **B01** Verify the cover-based fluid renderer
- [ ] **B02** Complete fluid controls, preview, reset and migration
- [ ] **B03** Verify fluid player lifecycle
- [ ] **V01** Verify independent visible-consumer artwork requests
- [ ] **V02** Verify looping video, provider order and fluid fallback
- [ ] **V03** Verify video cover transitions and accessibility
- [ ] **M01** Establish the real Spotify action-menu contract
- [ ] **M02** Present the verified actions in a system menu

## Artwork and album <!-- lane: artwork-album -->

- [x] **A01** Validate supported HEVC selection
- [x] **A02** Validate collaborative artist matching
- [x] **A03** Lock down edition and clip-validation behavior
- [x] **A04** Verify provider failure, cancellation and cache leases
- [x] **A05** Verify publisher and lyrics metadata coexistence
- [x] **H01** Resolve motion for the browsed album
- [x] **H02** Verify album hero playback and static fallback
- [x] **H03** Complete Albums motion settings
- [x] **E01** Verify bounded content reveal and cover palette
- [x] **E02** Validate reveal and color on each entity page
- [x] **E03** Validate creator portraits and bottom fades

## Navbar <!-- lane: navbar -->

- [x] **N01** Verify mini-player accessory content and actions
- [x] **N02** Verify compact accessory layout and minimization
- [x] **N03** Complete mini-player preference and mode switching
- [ ] **N05** Verify Redesigned add-tab sheet and icon picker
- [ ] **F09** Keep custom destinations selected in each Navbar
- [ ] **N04** Verify Native add-tab sheet and icon picker
- [ ] **F10** Remove repeated startup and tab-layout work
- [ ] **F05** Find the live playlist Mix control

## Audio and Connect <!-- lane: audio-connect -->

- [ ] **D01** Verify the single audio owner and stage contract — blocked: needs `harness/audio-routing/check.sh` on macOS
- [ ] **D02** Verify route, format and disposal safety — blocked: needs the macOS audio-routing harness (reviewed with D01)
- [ ] **D03** Verify effects and haptics use the owner once — blocked: needs the macOS audio-routing harness (reviewed with D01)
- [x] **D04** Verify pitch follows speed and its controls
- [x] **C01** Verify bounded discovery without multicast entitlement
- [x] **C03** Validate bridge socket safety and device discovery

## Updates and evidence <!-- lane: updates-evidence -->

- [x] **R01** Verify numeric prerelease version precedence
- [x] **R02** Verify stable/beta filtering of fetched and cached releases
- [x] **R03** Verify beta Release Please automation
- [ ] **S01** Establish a distributable on-device model — blocked: no redistributable, benchmarked model
- [ ] **S02** Prove Spotify streamed-source ownership and ABI — blocked: no reproducible streamed-audio queue/ABI evidence
- [ ] **S03** Implement validated model download lifecycle — blocked: depends on S01/S02
- [ ] **S04** Implement bounded inference with pass-through fallback — blocked: depends on S01/S02
- [ ] **S05** Integrate Sing and compensate timing — blocked: depends on S01/S02
- [ ] **S06** Add Sing settings and redesigned vocal control — blocked: depends on S01/S02
- [x] **P01** Record the older-iOS redesign decision
- [x] **P02** Record alternate-edition and looser-matching choices
- [x] **P03** Record bounded clip-coverage choices
- [x] **P04** Record artwork default and icon fidelity choices

## Integration owner <!-- lane: integration -->

- [ ] **F04** Reattach one Mod Settings drawer row
- [ ] **I01** Verify Prisma icon assets and safe packaging
- [ ] **I02** Verify alternate icon selection and availability
- [ ] **C02** Preserve local-network metadata through packaging
- [ ] **T01** Verify the composed settings destinations
- [ ] **T02** Verify compatibility notices and preserve OS gates
- [ ] **Q01** Run artwork harnesses and real hook-order checks — blocked: needs macOS and a device
- [ ] **Q02** Compile and validate both UI looks — blocked: needs macOS and a device
- [ ] **Q03** Validate real audio routes and nearby devices — blocked: needs macOS and a device
