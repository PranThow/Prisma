<p align="center">
  <img src="docs/icon.png" width="96" alt="Prisma project icon">
</p>

<h1 align="center">Prisma</h1>

<p align="center">A fresh look for Spotify on iOS. Open source, yours to build.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Spotify-9.1.78-1ED760?style=for-the-badge&logo=spotify&logoColor=white" alt="Spotify 9.1.78">
  <img src="https://img.shields.io/badge/Native-iOS_16.1+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Native look requires iOS 16.1 or newer">
  <img src="https://img.shields.io/badge/Liquid_Glass-iOS_26+-3A95E3?style=for-the-badge&logo=apple&logoColor=white" alt="Liquid Glass redesign requires iOS 26 or newer">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL_v3-blue?style=for-the-badge" alt="GPL v3 license"></a>
</p>

<p align="center">
  <a href="https://github.com/PranThow/Prisma/releases">Releases</a> &middot;
  <a href="#build-prisma">Build Prisma</a> &middot;
  <a href="docs/tweaks.md">Development guide</a> &middot;
  <a href="https://github.com/PranThow/Prisma/issues">Issues</a>
</p>

<p align="center">
  <img src="docs/screenshots/now-playing.webp" width="16%" alt="Full-screen player with lyrics">
  <img src="docs/screenshots/album.webp" width="16%" alt="Album page">
  <img src="docs/screenshots/playlist.webp" width="16%" alt="Playlist page">
  <img src="docs/screenshots/queue.webp" width="16%" alt="Playback queue">
  <img src="docs/screenshots/live-activity.webp" width="16%" alt="Live Activity on the lock screen">
  <img src="docs/screenshots/home.webp" width="16%" alt="Home page">
</p>

Prisma is an independent, GPL v3 fork of **spoti.pw**, based on its GPL-licensed source. It brings a Liquid Glass redesign and extra customization to Spotify on iOS through an Objective-C and Logos tweak built with Theos. No jailbreak is required: build it into your own decrypted Spotify IPA, then sign and sideload it.

This fork gives that open-source foundation a new home and identity, with credit to the original project's work.

## What Prisma brings

Choose your look in **Settings > Mod Settings > Appearance**:

- **Native:** keep Spotify's own interface and customize it with glass header buttons, a Home gradient, AMOLED backgrounds, accent colors, and controls for hiding clutter.
- **Redesigned:** a Liquid Glass interface with a glass tab bar, search field and now playing bar; a redesigned player; Apple Music-style lyrics; cleaner Home, Search and Library screens; and reworked playlist, album and artist pages.

Both looks include lyrics sources, lock-screen lyrics, player gestures, blocked artists, privacy controls, feature flags, vibrations, audio effects, speed and pitch controls, and Live Activity support. Most settings require a restart; some, including vibrations and Live Activity, apply immediately.

## Compatibility

The inherited implementation targets **Spotify 9.1.78**; Prisma changes still need a full device build and verification. Use a decrypted IPA of that version. Spotify's internal classes change between releases, so other versions may build successfully but fail at runtime.

| Feature | Minimum iOS version |
|---|---|
| Native look | iOS 16.1 |
| Liquid Glass redesign | iOS 26 |
| Live Activity | iOS 17 |

Below iOS 26, Prisma uses the native look and disables the redesign switch. Live Activity also requires a build that includes its widget extension.

## Build Prisma

This repository does not distribute Spotify IPAs. Supply your own decrypted **Spotify 9.1.78** IPA and sign the resulting build with your own certificate or sideloading tool.

### With GitHub Actions

1. Fork [PranThow/Prisma](https://github.com/PranThow/Prisma) and enable GitHub Actions in your fork.
2. Open **Actions > Build IPA from your own Spotify IPA > Run workflow**.
3. Enter a direct download link to your decrypted IPA.
4. Choose **artifacts** as the upload method, then download the built IPA from the completed workflow run.
5. Sign and sideload the IPA.

No Mac is needed for this workflow. It also offers a Filebin upload option if you choose to upload the result there.

### On a Mac

Install Theos in `~/theos` and select Xcode with an iPhoneOS 26 or newer SDK using `xcode-select`. A standalone SDK in `~/theos/sdks` can build the tweak, but without the Live Activity extension.

Install the build tools:

```sh
brew install make ldid dpkg zsign ideviceinstaller libimobiledevice
uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"
```

Place your decrypted IPA in `ipa/`, then run:

```sh
make release    # Unsigned IPA in out/Prisma-<version>.ipa
make install    # Sign and install over USB; output is out/Prisma-dev.ipa
```

For `make install`, copy `.signing.env.example` to `.signing.env` and set `SIGN_P12`, `SIGN_PROFILE`, and `SIGN_P12_PASSWORD`. Local installs use Prisma as the display name; set `DEV_NAME` to override it.

The first build extracts Spotify's feature flags from your IPA. Run `make flags` to regenerate them.

### Signing and installation

Sign with a bundle identifier matching your certificate's App ID. A mismatch can prevent lock-screen player taps from opening the app; the mod shows a warning on first launch with the identifier to use.

In Feather, enter the App ID in **Identifier** and leave **PPQ protection** off. You can also sign with tools such as SideStore, AltStore, or Sideloadly.

The build retains Spotify's bundle identifier before signing. Installing it with that identifier replaces the existing Spotify app.

## Contributing

Bug reports and contributions belong in [Prisma's issues](https://github.com/PranThow/Prisma/issues) and pull requests. For a bug report, include your iOS version, Spotify version, Prisma build version, chosen look, and steps to reproduce it.

Read the [development guide](docs/tweaks.md) before changing code. It covers the source layers, view-tree inspection, build targets, and known pitfalls. Native and redesigned UI changes belong in their respective layers; behavior shared by both belongs in `Shared/`.

Useful development commands:

```sh
make install FLEX=1    # Install with the view inspector
make session           # Record clean Spotify view trees
make log               # Stream the tweak's device logs
```

## AI disclosure

AI tools are used to help write documentation, review code, and implement changes in Prisma. This includes the fork's initial documentation, branding, and removal of donation prompts and upstream usage reporting. The inherited implementation and screenshots come from the original project; they are not presented as new work by Prisma.

AI assistance does not establish correctness. Build and device testing are still needed, and the maintainer is responsible for the changes shipped in each release.

## Credits and license

Prisma builds on the GPL v3 version of [spoti.pw](https://github.com/skopevoj/spoti.pw) by skopevoj and its contributors. The original implementation and screenshots are inherited from that project.

- [Theos](https://theos.dev) builds the tweak.
- [cyan](https://github.com/asdfzxcvbn/pyzule-rw) injects it into the IPA.
- [FLEX](https://github.com/FLEXTool/FLEX), through hopeless's AutoFLEX build in `vendor/`, provides the view inspector.
- The lyrics hook follows [EeveeSpotify Reincarnated](https://github.com/SideloadLabs/EeveeSpotifyReincarnated).
- Third-party audio components and their licenses are documented in [vendor/audio/README.md](vendor/audio/README.md).

Prisma is licensed under the [GNU General Public License v3](LICENSE). Existing copyright and attribution notices are retained.

Prisma is an independent project and is not affiliated with or endorsed by Spotify.
