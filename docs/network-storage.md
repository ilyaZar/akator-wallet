# Network storage architecture

## Outcome

Akator can use Syncthing and Proton Drive for card images without either
provider app on Android. Provider software and provider credentials stay on a
companion computer. Android reaches a small, authenticated API exposed by that
computer.

This feature does not synchronize the wallet database. It only browses, reads,
and writes images used by the existing add-card workflow.

## Independent review

The former implementation was Android Storage Access Framework integration, not
a network backend. It checked for provider package names, stored an Android
folder URI or a boolean, and opened a generic document picker. The picker did
not guarantee that the selected file came from the provider shown in the UI.

The reviewed companion design remains the smallest supported design:

- Syncthing is a peer-to-peer synchronization daemon, not an account-backed
  cloud filesystem. The companion reads and writes its managed local folder.
- Proton Drive is end-to-end encrypted. The supported CLI performs encryption,
  authentication, and explicit file operations on the companion host.
- Android receives neither the Syncthing GUI API key nor Proton credentials.
- A direct Proton SDK integration is not suitable yet. Proton describes the
  public SDK as a preview and says standalone third-party authentication is not
  supported.

## Official integration findings

### Syncthing

Syncthing has no central cloud account. Devices identify one another with
device IDs, exchange data directly when possible, and may use discovery and
relays to find and connect to peers. The
[Syncthing FAQ](https://docs.syncthing.net/users/faq.html) and
[Block Exchange Protocol](https://docs.syncthing.net/specs/bep-v1.html)
describe this peer model and its authenticated TLS protocol.

The folder modes have materially different contracts:

- [Send and receive](https://docs.syncthing.net/users/foldertypes.html) applies
  both local and remote changes. Akator needs this because the companion writes
  locally and configured peers may also add images.
- Send only treats this computer as the reference copy and does not apply
  remote changes.
- Receive only does not distribute local companion writes.

The Syncthing
[REST API](https://docs.syncthing.net/dev/rest.html) is the administrative
interface used by the GUI. It controls configuration and exposes status. It is
subject to change and requires the sensitive GUI API key. It is not a supported
general file-content API. Akator therefore does not expose it or use it as a
remote filesystem.

Implementing the Block Exchange Protocol in Akator would turn the wallet into a
Syncthing peer. That would duplicate discovery, relay, database, conflict, TLS,
and device-identity behavior and would expand the security surface far beyond
image storage. The official daemon already implements that protocol.

The official
[autostart guide](https://docs.syncthing.net/users/autostart.html) documents
running Syncthing as the normal user. The host uses the existing user service.
The wallet folder uses send-and-receive mode, file watching, periodic rescans,
and staggered versioning with a one-year maximum age.
[Versioning](https://docs.syncthing.net/users/versioning.html) protects local
copies when a remote peer replaces or deletes a file. It does not archive this
host's own local changes, so it is a recovery layer rather than a complete
backup.

Syncthing conflict files can still occur after concurrent edits. Akator uses
atomic local writes, but it does not hide or automatically resolve Syncthing
conflicts. Only supported image extensions appear in the app browser.

### Proton Drive

Proton documents the
[official Drive CLI](https://proton.me/support/drive-cli) for Linux, macOS, and
Windows. Authentication opens the system browser, the authenticated session is
stored in the operating system's secret store, and `--json` provides structured
automation output. The official
[CLI repository](https://github.com/ProtonDriveApps/sdk/tree/main/cli)
documents its use of the Drive SDK, OS secret storage, cache locations, and
one-shot commands.

The current official download index is
[Proton Drive CLI 0.6.0](https://proton.me/download/drive/cli/index.html).
The companion validates the known 0.4.6 through 0.6.x command contract and
fails closed on an unreviewed version.

Proton explicitly describes the CLI as appropriate for an action at a specific
time instead of keeping folders continuously synchronized in its
[CLI announcement](https://proton.me/blog/proton-drive-cli). The Akator Proton
adapter therefore performs an explicit list, upload, or download for each API
request. It must not be described as continuous sync.

The public SDK remains a preview. Proton's
[January 2026 SDK update](https://proton.me/blog/drive-sdk-january-2026)
states that authentication and other modules required by standalone third-party
integrations are not supported. The
[June 2026 update](https://proton.me/blog/drive-sdk-june-2026) still calls it a
preview. Calling the official authenticated CLI is consequently the supported
host-side boundary today.

Proton Drive remains end-to-end encrypted. Encryption, decryption, account
state, and keys are handled by the official CLI on the companion host. The
companion sees plaintext image bytes because it must return an image to Akator
and accept cropped image bytes for upload. Proton servers and the Android app
do not receive the Proton account password or session.

## Trust boundary

```text
Android app
  |  HTTPS + bearer token
  v
Akator storage companion
  |                         |
  | confined local files    | argument-array CLI process
  v                         v
Syncthing wallet folder     official Proton Drive CLI
  |                         |
  | Syncthing TLS/BEP       | Proton encrypted protocol
  v                         v
explicit Syncthing peers    Proton Drive cloud
```

The companion is trusted with plaintext card images and a narrow bearer token.
The host user is also trusted because both provider tools and the companion run
under that user. A stolen companion token allows list, read, and write access to
images under the configured roots, but not provider administration, deletion,
rename, Syncthing pairing, or Proton login.

The API applies these controls:

- versioned routes and per-backend capability and health discovery
- constant-time bearer-token comparison
- traversal, absolute path, backslash, NUL, and symlink-escape rejection
- a 12 MiB image limit and content-type detection
- extension allowlisting for JPEG, PNG, GIF, and WebP
- atomic `0600` local-folder writes
- command argument arrays without a shell
- bounded Proton command output and redacted provider errors
- request, provider, and server timeouts
- `no-store`, `nosniff`, and `no-referrer` response headers

## Transport

The checked-in service binds to `127.0.0.1:8787`. Android debug builds may use
cleartext HTTP only when local port forwarding or `adb reverse` keeps the
connection on the host. Release builds accept HTTPS companion URLs only and do
not enable Android cleartext traffic.

For access from another device, terminate TLS at the companion or at a trusted
reverse proxy. The companion refuses non-loopback plaintext HTTP unless the
operator opts in explicitly. Future Tailscale integration can provide the
private route and a Tailscale HTTPS hostname; it does not require changing the
mobile API. This project does not install Tailscale, alter firewall rules, or
publish the companion.

## Android data model and migration

New remote references serialize:

- the reference kind `remote`
- `syncthing` or `proton_drive`
- the relative provider path
- display name and MIME type

They do not serialize the companion URL or access token. Connection data is
stored through `flutter_secure_storage`.

Existing asset, local-file, and Android `content://` references keep their old
meaning. Minimal native code remains only to read existing `content://` images.
The app no longer queries, launches, or requires Syncthing-Fork, legacy
Syncthing Android, or Proton Drive Android packages.

Remote images are fetched only when displayed. Cropping downloads one bounded
image into the operating system's temporary directory, deletes the temporary
directory on success or failure as far as the platform permits, uploads the
crop through the same backend, and stores the returned stable path. Full
offline mirroring is not implemented.

## Current host configuration

The configured workstation uses:

- the existing official Syncthing user service
- folder ID `akator-wallet-images`
- local root `~/Work/akator-wallet-storage/syncthing`
- send-and-receive mode
- file watching and an hourly full rescan
- staggered versioning with a one-year maximum age
- no automatically selected peer
- official Proton Drive CLI 0.6.0
- Proton root `/my-files/Akator Wallet`
- a loopback-only companion user service

The Syncthing folder is indexed and healthy, but it is intentionally not shared
with every existing peer. A live cross-device synchronization check requires
an explicit peer choice. See the companion runbook for that final step.

## Limitations

- Proton operations are explicit and can take longer than local Syncthing
  operations.
- The companion supports images only. It does not synchronize card metadata or
  the wallet database.
- Hidden paths and provider metadata are excluded from the wallet API.
- There is no delete, rename, folder creation, provider login, or peer
  administration API.
- Remote images have a loading and unavailable state but no persistent offline
  cache.
- Release use from a physical phone requires an HTTPS route to the companion.
- Syncthing cross-device proof remains pending until a peer is explicitly
  chosen and accepts this dedicated folder.
