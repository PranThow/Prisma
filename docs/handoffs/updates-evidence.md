# Updates and evidence handoff

## R01/R02 — update versions and channels

Changed `tweak/Sources/App/About/SGVersion.h` and `harness/update/versions.m`.

Release tags now reject SemVer-invalid numeric prerelease identifiers such as
`beta.01`. Release metadata must also agree with its tag: a prerelease tag needs
GitHub's `prerelease` flag, and a stable tag cannot carry it. The same
`SGVersionAllowed` check filters both freshly fetched entries and cached entries,
so a stable build cannot surface a beta from either source. Beta builds can still
see valid stable and prerelease releases.

Executed: source inspection of every `SGVersion*` and `SGUpdate*` caller; `git
diff --check`. The Objective-C harness requires macOS/Xcode (`xcrun`) and was not
run on this Windows host. Run `sh harness/update/check.sh` on macOS.

## R03 — Release Please review

No configuration files changed because R03 is integration-owner-only. The current
workflow routes `main` to `release-please-config.json` and `beta` to
`release-please-beta-config.json`; the beta configuration declares prerelease
versioning with the `beta` type. The build checks out the tag emitted by Release
Please and uploads its `.deb` to that same tag. `Update.m` identifies beta builds
from the build version's prerelease component, which matches that configuration.

Remaining validation: parse the configuration with the pinned Release Please
action in a non-publishing workflow run; do not publish a release just to test
it.

## S01/S02 — Sing evidence

**Blocked; no Sing UI, model, downloader, or audio hook was added.** The recorded
Spotify 9.1.78 executable identity is `C712370B-44CD-35C8-A058-4FBED1AD0758`
with `cryptid = 0`, but this checkout has no local binary/tree artifact that
proves a streamed-source queue layout, callback signature, ownership rules,
buffer lifetime, or seek/track-transition contract. Objective-C metadata and the
existing output-side AudioUnit integration cannot prove those opaque contracts.

There is also no distributable model artifact with a license allowing iOS
redistribution, immutable source URL, SHA-256, exact byte size, conversion
recipe, iOS runtime, supported device/OS range, or measured CPU/GPU/memory and
latency budget. A future S01 packet must provide all of those facts and reproduce
the hash before S03 begins. A future S02 packet must include the locally supplied
binary/tree paths, UUID check, each offset/call signature and runtime traces for
start, buffering, seek, A-to-B-to-A, stop and disposal. Only then can an
interception point be selected safely.

The task-owned blocker record is also in [Sing evidence](../sing-evidence.md), so
future S01/S02 work has one reproducible checklist outside this handoff.

## P01 — iOS 26 redesign gate

Recommendation: retain the iOS 26 gate. `SGRedesignAvailable()` gates the
redesigned look, its settings row says “Needs iOS 26” below that version, and the
tour disables its card. Liquid Glass is system-rendered; the recorded reason for
the gate is an iOS 17 scene-update watchdog/layout hang. Reconsider only after a
separate prototype demonstrates a non-Liquid-Glass design on each intended older
OS, including repeated navigation/layout and accessibility testing. Do not add
an opt-in before that evidence exists.

## P02/P03 — edition matching and clip coverage

**Blocked on A02/A03/A04 evidence.** Current matching keeps exact albums ahead of
allowed deluxe/remaster suffixes and requires complete collaborator sets. This
avoids serving a live/remix or a same-name album from the wrong artist. Current
clip checks require Apple's HTTPS CDN, bounded playlists/resources, SDR video,
and complete VOD MP4 content. The existing limits include 60 seconds, 32 MiB
download, 64 MiB file and 128 MiB cache.

No rejected, permitted clips or validated matching fixtures were supplied, so
there is no evidence for a safe extension. Any proposal needs a concrete rejected
fixture, the smallest format/bound change, and validation covering malformed,
off-CDN, oversize and wrong-edition cases.

## P04 — artwork and icon fidelity

Recommendation: retain the current defaults. Lock-screen animated artwork is
off until the user enables `spotifyglass.animatedArtwork`; this avoids unexpected
network, battery and motion use. It also requires iOS 26, a supported MediaPlayer
key, and can be disabled by Low Power Mode or accessibility settings. The app
ships three Prisma-owned static PNG alternates (Violet, Emerald and Pearl), with
verified packaging metadata; no layered Icon Composer Liquid Glass asset or
Apple-toolchain validation is present. Keep describing them as static alternates,
not exact beta icon parity. Revisit only with source artwork rights, a macOS/iOS
26 Icon Composer build, and device checks for every iPhone/iPad icon slot.

## R03 — Release Please configuration review

Changed `docs/handoffs/updates-evidence.md` only. No release configuration changed:
those files are owned by the integration owner.

The stable and beta JSON files parse. Both retain the Prisma package name and
unprefixed tags; beta alone declares prerelease versioning with the `beta` type.
The workflow listens to `main` and `beta`, selects the matching configuration,
checks out the release-created tag, and attaches the resulting `.deb` to that
same tag.

Executed: the Node JSON/channel-field validation passed; a PowerShell workflow
contract check passed; `git diff --check` passed. A real non-publishing
Release Please action run remains owed because its action/schema validator is
not installed locally and this task does not authorize workflow dispatch or a
release. No macOS or device checks apply.
