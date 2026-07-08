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

## Demo Assets

The current favorite-card images are local dummy assets used to exercise the
wallet UI:

- credit card mockup: `CC 2.png` by Jed1571, CC BY 3.0
- student ID sample: 1958 Allentown High School ID, public domain
- personal ID sample: California DMV sample ID, public domain
- numbered variants are local demo copies generated from the same source images
