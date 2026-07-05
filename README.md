<p align="center">
  <img src="res/logo-header.svg" alt="Ghost Desk"><br>
  <a href="#self-hosted-defaults">Self-hosted defaults</a> •
  <a href="#support-mode-and-managed-mode">Support / Managed Mode</a> •
  <a href="#platform-support">Platforms</a> •
  <a href="#raw-steps-to-build">Build</a> •
  <a href="#file-structure">Structure</a>
</p>

> [!Caution]
> **Misuse Disclaimer:** <br>
> Ghost Desk is a remote access and remote support tool. Misuse — unauthorized access, control, or invasion of privacy — is strictly against our guidelines. Only connect to devices you own or are explicitly authorized to support.

## What is Ghost Desk

Ghost Desk is our branded remote-support and remote-access client, built on top of
[RustDesk](https://github.com/rustdesk/rustdesk) (AGPL-3.0). RustDesk supplies the
remote-control engine — screen capture, input, networking, encryption; Ghost Desk is the
product layer on top: our branding, our self-hosted server defaults, and onboarding
designed for non-technical end users being helped by an operator.

Ghost Desk is a separate repo/product from **Ghostline** (our onboarding, customer
workflow, and operator platform). Ghostline drives the workflow; Ghost Desk is the
client that actually establishes the remote session.

We do not fork the engine to rewrite it — protocol, capture, and input handling stay as
upstream RustDesk provides them. Our changes live in a small, clearly-scoped layer on top
(see [`src/ghost_desk.rs`](src/ghost_desk.rs)).

## Self-hosted defaults

Ghost Desk ships preconfigured to reach our own self-hosted `rustdesk-server`
(hbbs/hbbr) instance, instead of the public RustDesk relay network. This is implemented
in [`src/ghost_desk.rs`](src/ghost_desk.rs), which is the single place Ghost Desk
diverges from stock RustDesk defaults:

- It does **not** patch the RustDesk/`hbb_common` engine. It only populates the override
  points (`DEFAULT_SETTINGS`, `APP_NAME`) that `hbb_common::config` already exposes for
  white-labeled clients.
- Defaults (ID/relay server host, server public key, app name) are baked in at **compile
  time** via `option_env!`, so a build can be re-pointed at a different server or brand
  without touching source:

  ```sh
  GHOST_DESK_ID_SERVER=dev.example.com \
  GHOST_DESK_RELAY_SERVER=dev.example.com \
  GHOST_DESK_SERVER_KEY=<base64 pubkey> \
  GHOST_DESK_APP_NAME="Ghost Desk Dev" \
  cargo build
  ```

  Unset any of these and the build falls back to our production self-hosted server.
  This keeps local/dev builds simple (no env vars needed) while making it trivial for CI
  to bake in a different server per build channel.

- These are **defaults**, not forced values — end users can still override the ID/relay
  server and key from Settings > Network at any time. The self-hosted values only apply
  when nothing else (user config, `custom.txt`, an admin override) has already set them.

### Optional: baked-in preset permanent password

For managing enrolled work devices, a build can also bake in a **preset permanent
password**, so an install is immediately controllable without the end user setting
anything up:

```sh
GHOST_DESK_PRESET_PASSWORD=<shared password> \
GHOST_DESK_PRESET_PASSWORD_SALT=<any fixed string, optional> \
cargo build
```

Notes:

- This is a **shared password baked into that build/APK** — every device installed from
  the same build accepts the same password. It is not per-device and there is no
  auto-generated device inventory; track which devices you've deployed to yourself for
  now (e.g. a spreadsheet) until a real fleet dashboard exists on the Ghostline side.
- It uses RustDesk's existing preset-password mechanism (`HARD_SETTINGS["password"]` /
  `["salt"]`), the same override point RustDesk Server Pro uses for managed deployments —
  we're not inventing new password storage, just baking a value into it at compile time.
- The password is stored hashed (SHA-256 + salt), never in plaintext, in the built
  binary. Still, treat it like any shared credential: rotating it means rebuilding and
  redeploying, and anyone who extracts it from the binary has full remote control of
  every device on that build — don't reuse it across a build meant to be distributed
  publicly.
- End users still see RustDesk's standard "a permanent password is preset by your
  administrator" notice in Settings > Security, and can set a local password that
  overrides the preset one on their own device. This is disclosure, not a loophole:
  a fully hidden/unremovable password isn't something this mechanism (or RustDesk's) is
  built for.
- Leave it unset for a normal build (e.g. anything meant for public distribution or
  Support Mode) — no preset password is baked in by default.

## Support Mode and Managed Mode

Ghost Desk frames two connection workflows for non-technical users, on top of RustDesk's
existing session model:

- **Support Mode** — a one-time support session. The end user opens the app, shares an
  ID/password with an operator (e.g. via Ghostline), and the connection ends when the
  session is closed. No lasting access is retained.
- **Managed Mode** — persistent/recurring managed access, for devices under ongoing
  support (e.g. a permanent password or unattended-access setup, deployed once).

This is currently a naming/UX framing on top of RustDesk's existing password and
unattended-access mechanisms; dedicated onboarding screens for each mode are planned but
not yet built — see the transformation plan for phasing.

## Platform support

Ghost Desk preserves RustDesk's cross-platform reach. Priority order for this product:

1. **Desktop (Windows / macOS / Linux)** — full parity with upstream RustDesk.
2. **Android** — full parity with upstream RustDesk, with caveats below.
3. Other platforms (iOS, web) continue to build but are not a current focus.

### Android-specific limitations

Android's permission model constrains what a remote-support app can do out of the box.
When setting expectations with non-technical users:

- **Screen sharing/control requires the Accessibility service** ("Ghost Desk Input") to
  be enabled manually in system settings — this cannot be granted programmatically.
- **Unattended/background operation** is fought by Android's battery optimization; users
  must exclude Ghost Desk from battery optimizations for reliable unattended access.
- **Input injection** (remote-controlling the Android device) depends on the
  Accessibility service above and is not available on all OEM Android builds/versions.
- Recent Android versions increasingly restrict foreground services and background
  starts; some flows require the app to be open/foregrounded at least once per boot.

These are Android platform constraints, not Ghost Desk-specific bugs — see upstream
RustDesk's Android documentation for background.

## Raw steps to build

- Prepare your Rust development env and C++ build env.
- Install [vcpkg](https://github.com/microsoft/vcpkg), and set `VCPKG_ROOT` correctly:
  - Windows: `vcpkg install libvpx:x64-windows-static libyuv:x64-windows-static opus:x64-windows-static aom:x64-windows-static`
  - Linux/macOS: `vcpkg install libvpx libyuv opus aom`
- `cargo run`

Flutter (current UI, desktop + mobile) build instructions: see
[RustDesk's build docs](https://rustdesk.com/docs/en/dev/build/) and our CI workflow
under `.github/workflows/`. The engine build process is unchanged from upstream
RustDesk; only the defaults described above differ.

## File structure

- **`src/ghost_desk.rs`** — Ghost Desk branding + self-hosted server defaults (the one
  file that makes this repo "Ghost Desk" rather than stock RustDesk).
- **`libs/hbb_common`** — video codec, config, tcp/udp wrapper, protobuf, fs functions
  for file transfer (RustDesk engine, submodule, unmodified).
- **`libs/scrap`** — screen capture (RustDesk engine).
- **`libs/enigo`** — platform-specific keyboard/mouse control (RustDesk engine).
- **`libs/clipboard`** — clipboard file copy/paste for Windows, Linux, macOS.
- **`src/server`** — audio/clipboard/input/video services and network connections.
- **`src/client.rs`** — start a peer connection.
- **`src/rendezvous_mediator.rs`** — talks to the rendezvous/relay server (by default,
  our self-hosted one — see above).
- **`src/platform`** — platform-specific code.
- **`src/lang`** — UI strings; `en.rs` carries Ghost Desk's rebranded English strings,
  other languages remain upstream RustDesk translations pending a full localization pass.
- **`flutter`** — Flutter UI for desktop and mobile.

## License and attribution

Ghost Desk is built on [RustDesk](https://github.com/rustdesk/rustdesk), licensed under
AGPL-3.0 (see [`LICENCE`](LICENCE)). This repo remains AGPL-3.0; source availability
obligations apply the same way they do upstream. Full credit to the RustDesk project and
contributors for the underlying remote-control engine.
