# Mobile Release Workflow

This project uses one public release lane:

```text
ChatGPT app on phone
  -> Codex on the development host
  -> branch and pull request
  -> merge to main
  -> GitHub Actions tests and signs the APK
  -> public GitHub Release
  -> Obtainium update on Android
```

## Release Contract

- Pull requests run `flutter analyze` and `flutter test`.
- Every merge to `main` repeats those checks and builds a signed APK.
- Release tags use `build-<run number>`.
- Android version codes start at `100001` and increase with the release
  workflow run number.
- The APK contains the version, commit SHA, and release tag shown under Wallet
  Settings > Build.
- Each GitHub Release contains the APK, a SHA-256 checksum, and the signing
  certificate report.

The package name is `com.akator.wallet`. All update APKs must use that package
name, a higher version code, and the same signing key.

The release certificate SHA-256 fingerprint is:

```text
74:DA:5F:D6:CD:D5:3F:42:01:21:42:E5:4B:5D:13:86:26:7B:10:E3:5E:F9:9B:85:7F:B9:74:E9:49:86:95:01
```

## GitHub Secrets

The release workflow requires these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The keystore must never be committed. Keep at least one encrypted backup
outside this computer. Losing the signing key means installed copies cannot be
updated in place.

GitHub Actions secrets cannot be read back. The encrypted keystore backup and
its recovery password therefore need independent recovery copies.

For a local release build, copy `android/key.properties.example` to
`android/key.properties`, use the real values, and point `storeFile` at the
absolute keystore path.

## Proton Pass Recovery

The official Proton Pass CLI source is checked out at:

```text
~/Dropbox/projects/proton/pass-cli
```

It is pinned to the latest stable source tag. Proton limits CLI access by
account plan. Use Proton Pass Web when the account is not eligible for CLI
access.

Store the release password as a Proton Pass login item named
`Akator Wallet release signing`. Include the key alias, certificate
fingerprint, and backup location in the item's notes. The working keystore and
its password-protected Dropbox backup are outside this repository.

## First Phone Installation

The first permanent signed release replaces the old debug-signed build:

1. Back up any wallet data that must survive.
2. Uninstall the debug build.
3. Install the signed release APK.
4. Open Wallet Settings > Build.
5. Match the displayed revision and release tag to the GitHub Release.

This clean reinstall is required only for the signing-key migration. Future
releases update in place and preserve app data.

Do not uninstall a debug build with valuable private data. First add an in-app
export/import path or explicitly confirm that the data is disposable. A raw
ADB backup cannot be restored directly into a non-debuggable release.

## Obtainium

Install Obtainium from its official GitHub Release. In Obtainium:

1. Add `https://github.com/ilyaZar/akator-wallet`.
2. Leave prereleases disabled.
3. Confirm that Obtainium detects the latest `build-<number>` release.
4. Select the `akator-wallet-*.apk` release asset if prompted.

The public release feed needs no GitHub account or phone-side access token.

## Routine While Away

1. Open this Codex task in the ChatGPT Android app.
2. Start or continue the Codex task on the development host.
3. Ask Codex to implement, test, commit, push, and open a pull request.
4. Review the diff and checks in ChatGPT or GitHub Mobile.
5. Merge the pull request.
6. Wait for the `release` workflow to publish a new GitHub Release.
7. Install the update from Obtainium.
8. Confirm Wallet Settings > Build matches the merged commit and release.

The development host must stay awake, online, and running the Codex app for
tasks that execute on this computer. GitHub Actions continues independently
after code is pushed.

## Verification

For a downloaded APK:

```sh
sha256sum akator-wallet-*.apk
apksigner verify --verbose --print-certs akator-wallet-*.apk
```

For a USB-connected phone:

```sh
adb shell dumpsys package com.akator.wallet
```

Check `versionCode`, `versionName`, `apkSigningVersion`, and the installer
source. A clean release build must not include the `DEBUGGABLE` package flag.

## Android Developer Verification

Direct sideloading still works today. Android developer verification begins a
wider rollout in 2027, so register the developer identity and package in the
Android Developer Console before it reaches this device or region. ADB remains
available for development installs.
