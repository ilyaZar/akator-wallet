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

## External Images

Add Card supports Android Storage Access Framework image links for external
sources:

- Syncthing expects Syncthing-Fork on the phone and a normal Android-visible
  synced folder. The app asks once for folder access, then stores linked
  `content://` image references.
- Proton Drive expects the official Android app package
  `me.proton.android.drive`. If it is not installed, the app shows a quiet
  in-form message instead of opening a generic picker.

Accepted external images are copied only to a temporary local file for cropping.
When cropping is saved, the cropped file is created through SAF and the card
keeps the resulting external URI.

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
