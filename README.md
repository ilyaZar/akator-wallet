# Akator Wallet

Flutter baseline for the Akator wallet mobile app.

## Development

Use the shared mobile tooling for this host:

```sh
source "$HOME/.config/mobile-dev/flutter.env"
fvm flutter pub get
fvm flutter run -d emulator-5554
```

Android SDK, AVD, and Flutter cache state live under:

```text
~/Dropbox/libraries/Android/optiplex/
```

## Mobile Releases

Merges to `main` create a signed APK in a private GitHub Release. The Android
app shows the exact version, Git revision, and release tag under Wallet
Settings > Build.

See [Mobile release workflow](docs/mobile-release.md) for signing setup,
Obtainium configuration, installation, verification, and key recovery.

## Host-backed images

Syncthing and Proton Drive run on a companion computer, not on Android. The app
uses a narrow authenticated companion API to browse, read, and write card
images. Syncthing-Fork and the Proton Drive Android app are not required.

- Syncthing images live in a dedicated directory managed by the official
  Syncthing daemon.
- Proton Drive images use explicit operations from the official Proton Drive
  CLI. This is not continuous local-folder synchronization.
- The companion URL and token are stored in Android secure storage. Remote card
  references contain a backend and relative object path, never the token.
- Old Android `content://` image references remain readable for migration
  compatibility.

See [Network storage architecture](docs/network-storage.md) for the reviewed
official integration choices, trust model, setup, and limitations. See the
[companion runbook](companion/README.md) to build and operate the host service.

## Demo Assets

The current favorite-card images are local dummy assets used to exercise the
wallet UI:

- credit card mockup: `CC 2.png` by Jed1571, CC BY 3.0
- student ID sample: 1958 Allentown High School ID, public domain
- personal ID sample: California DMV sample ID, public domain
- health insurance sample: Medicare sample card, U.S. government public domain
- loyalty card sample: Blockbuster membership card, public domain text logo
- loyalty card sample: DC Public Library card, public domain text logo
- loyalty card sample: Customerloyalitycards.JPG, public domain release
- loyalty card sample: Delta Skymiles membership card, public domain
- driving license sample: Massachusetts sample driver license, public domain
- numbered variants are local demo copies generated from the same source images
