# Akator storage companion

The companion is a small Go service that exposes only the image operations
needed by Akator Wallet. It adapts a Syncthing-managed local directory and the
official Proton Drive CLI behind one authenticated API.

The architecture and official API review are in
[`docs/network-storage.md`](../docs/network-storage.md).

## API

All routes require `Authorization: Bearer TOKEN`.

```text
GET /v1/health
GET /v1/backends/{backend}/entries?path=RELATIVE_FOLDER
GET /v1/backends/{backend}/file?path=RELATIVE_IMAGE
PUT /v1/backends/{backend}/file?path=RELATIVE_IMAGE
```

Backend IDs are `syncthing` and `proton_drive`. Health returns API version 1,
backend availability, a stable status, and `list`, `read`, and `write`
capabilities.

The API excludes hidden paths and provider metadata such as Syncthing's
`.stfolder`. It accepts only supported image files below the configured roots.

## Build and test

```sh
cd companion
gofmt -w cmd internal
go test ./...
go vet ./...
go build ./cmd/akator-storage-companion
```

Optional deeper checks:

```sh
go test -race ./...
go test -cover ./...
staticcheck ./...
govulncheck ./...
```

Install the binary for the current user:

```sh
go build -trimpath -ldflags='-s -w' \
  -o "$HOME/.local/bin/akator-storage-companion" \
  ./cmd/akator-storage-companion
```

## Token provisioning and rotation

Create a private random token without printing it:

```sh
install -d -m 700 "$HOME/.config/akator-wallet"
umask 077
openssl rand -hex 32 > \
  "$HOME/.config/akator-wallet/companion-token"
chmod 600 "$HOME/.config/akator-wallet/companion-token"
```

Copy the token directly into Akator's obscured Access token field. Do not put it
in a URL, card data, command history, screenshot, log, or source file.

To rotate it, stop the companion, replace the file with a new random token,
start the companion, and update Akator. Existing remote card references remain
valid because they do not contain the token.

## Syncthing

Install and start the official daemon according to the
[official autostart guide](https://docs.syncthing.net/users/autostart.html).
On a systemd desktop:

```sh
systemctl --user enable --now syncthing.service
systemctl --user is-active syncthing.service
```

Create the dedicated root and add it without assigning devices:

```sh
install -d -m 700 "$HOME/Work/akator-wallet-storage/syncthing"
syncthing cli config folders add \
  --id=akator-wallet-images \
  --label="Akator Wallet Images" \
  --path="$HOME/Work/akator-wallet-storage/syncthing" \
  --type=sendreceive \
  --fswatcher-enabled \
  --rescan-intervals=3600
syncthing cli config folders akator-wallet-images \
  versioning type set staggered
syncthing cli config folders akator-wallet-images \
  versioning params set maxAge 31536000
syncthing cli config folders akator-wallet-images \
  versioning cleanup-intervals set 3600
```

Do not silently share a wallet folder with every known device. Choose the exact
peer in the Syncthing GUI or add that device to this folder explicitly, then
accept the folder on the peer. Confirm that both sides report `Up to Date`.
Create a harmless image on one side, confirm the same bytes arrive on the other,
then remove the test image. That is the required live synchronization proof.

Staggered versioning archives changes received from peers; it does not archive
local companion writes. Maintain a separate backup policy for valuable data.

## Proton Drive

Download the official binary and verify the checksum shown on the
[official release index](https://proton.me/download/drive/cli/index.html).
The companion currently accepts the reviewed 0.4.6 through 0.6.x contract.

Authenticate only through the CLI's browser flow:

```sh
proton-drive auth login
```

Do not paste a password or two-factor code into Akator, the companion config, a
terminal argument, or chat. Create a dedicated remote folder:

```sh
proton-drive filesystem create-folder /my-files "Akator Wallet"
proton-drive filesystem info -j "/my-files/Akator Wallet"
```

The CLI session and encryption keys remain in the operating system's secret
store. The companion invokes `filesystem list`, `filesystem info`,
`filesystem upload`, and `filesystem download` with separate process
arguments and JSON output. It never starts login.

Proton operations are one-shot requests, not continuous folder sync. Log out
with:

```sh
proton-drive auth logout
```

Logging out makes the Proton backend unavailable until browser authentication
is completed again. It does not affect the Syncthing backend.

## Service configuration

Copy the checked-in user unit:

```sh
install -d -m 700 "$HOME/.config/systemd/user"
install -m 644 companion/systemd/akator-storage-companion.service \
  "$HOME/.config/systemd/user/akator-storage-companion.service"
```

Create `~/.config/akator-wallet/companion.env` with mode `0600`:

```text
AKATOR_COMPANION_LISTEN=127.0.0.1:8787
AKATOR_COMPANION_TOKEN_FILE=/home/USER/.config/akator-wallet/companion-token
AKATOR_SYNCTHING_ROOT=/home/USER/Work/akator-wallet-storage/syncthing
AKATOR_PROTON_ROOT="/my-files/Akator Wallet"
AKATOR_PROTON_CLI=/home/USER/.local/bin/proton-drive
```

Replace `USER` with the local user name. If the storage paths differ, update
the unit's `ReadWritePaths` hardening directives too.

Start, stop, inspect, and remove the service with:

```sh
systemctl --user daemon-reload
systemctl --user enable --now akator-storage-companion.service
systemctl --user status akator-storage-companion.service
journalctl --user -u akator-storage-companion.service
systemctl --user stop akator-storage-companion.service
systemctl --user disable akator-storage-companion.service
```

Logs intentionally contain no access token, remote file paths, provider
output, account identifier, or Syncthing device ID.

## Android connection

For an emulator debug build, forward the loopback port:

```sh
adb -s emulator-5554 reverse tcp:8787 tcp:8787
```

Open Connections in Akator and enter:

```text
http://127.0.0.1:8787
```

Paste the companion token in the obscured field and select **Test and save**.
Debug builds permit this loopback HTTP flow. Release builds require HTTPS.

For a physical phone, provide an HTTPS hostname through a trusted reverse proxy
or future Tailscale HTTPS setup, bind the companion appropriately with a
certificate, and use that HTTPS URL. Never expose the loopback example by
turning on unauthenticated or public plaintext access.

## Troubleshooting

Check the narrow layers in order:

```sh
systemctl --user is-active syncthing.service
proton-drive --version
proton-drive filesystem info -j "/my-files/Akator Wallet"
systemctl --user is-active akator-storage-companion.service
```

An `unsupported_version` Proton status means the installed CLI is outside the
reviewed command contract. Review the official release notes and update the
adapter before widening the accepted range.

An unavailable Proton backend usually means browser authentication expired, the
remote root is missing, the secret store is unavailable to the user service, or
the CLI command timed out. Provider output is deliberately redacted from the
mobile API and service errors.
