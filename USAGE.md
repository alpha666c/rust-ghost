# Using Ghost Desk

This is the practical "how do I actually use this" guide: downloading builds, setting
up the machine you'll be controlling from, setting up an employee's device, and running
a session. For architecture/build details, see [README.md](README.md).

Two roles, throughout this doc:

- **Controller** — you (or whoever's providing support/managing devices). Runs Ghost
  Desk on their own machine and initiates connections.
- **Managed device** — an employee's laptop, desktop, or phone that Ghost Desk is
  installed on so it can be supported/controlled.

Both roles run the exact same app. There's no separate "admin" build — what differs is
configuration (permanent password, unattended access) and who initiates the connection.

Deployment target for us is **Windows + Android only** — macOS/Linux still build (see
README) but aren't part of our rollout.

## 1. Download a build

Builds are published to the repo's `nightly` release:
https://github.com/alpha666c/rust-ghost/releases/tag/nightly

Pick the asset for your platform. Note the files are still named `rustdesk-*` (package
name/bundle ID are intentionally unchanged from upstream — see README) even though the
installed app displays as "Ghost Desk":

| Platform | Asset pattern |
|---|---|
| Windows | `rustdesk-<version>-x86_64.exe` (also `aarch64`, `i686` variants) |
| Android | `rustdesk-<version>-<abi>.apk`, or the `-universal.apk` if unsure which ABI |

Windows and Android builds are code-signed (see section 2) once the signing secrets are
configured in the repo. Until then, or on a device that hasn't trusted our cert yet:

- **Windows** will show a SmartScreen warning. Click "More info" → "Run anyway".
- **Android** needs "Install unknown apps" permission enabled for whatever app you used
  to download the APK (browser/file manager) — this applies regardless of signing, since
  it's outside the Play Store.

## 2. Signing (one-time CI setup)

Both Windows and Android builds are self-signed — our own certificates, not ones bought
from a public CA, since these installs never leave devices we manage. That's free but
means each Windows device needs to be told to trust our cert once (Android doesn't need
this step — self-signed APKs are normal and Android doesn't warn based on signer
identity the way Windows SmartScreen does).

**One-time setup (repo owner):**

1. Add these repository secrets under **Settings → Secrets and variables → Actions**:
   - `ANDROID_SIGNING_KEY` — base64-encoded PKCS12 keystore
   - `ANDROID_ALIAS` — `ghostdesk`
   - `ANDROID_KEY_STORE_PASSWORD` / `ANDROID_KEY_PASSWORD` — same password (PKCS12 uses
     one password for both)
   - `WINDOWS_PFX_BASE64` — base64-encoded Authenticode `.pfx`
   - `WINDOWS_PFX_PASSWORD` — its password
   - The actual cert files, their base64 encodings, and generated passwords were produced
     locally during setup (not committed to this repo — private key material never goes
     in git). Ask Claude/whoever ran the setup for the values, or regenerate following the
     same `openssl req -x509 ... / openssl pkcs12 -export ...` steps used originally.
2. Once those secrets exist, the next nightly build signs the `.apk`/`.exe`/`.msi`
   automatically — no further workflow changes needed (see
   `.github/workflows/flutter-build.yml`, gated on `WINDOWS_PFX_BASE64`/
   `ANDROID_SIGNING_KEY`, and `res/sign-windows.ps1` for the actual Windows signing logic).

**Rolling out trust to managed Windows devices (one-time per device):**

`res/ghost-desk-codesign.cer` is our public signing certificate (safe to distribute — no
private key in it) and `res/trust-ghost-desk-cert.ps1` imports it into the machine's
trusted stores. On each managed Windows device, as Administrator:

```powershell
.\trust-ghost-desk-cert.ps1   # run from the same folder as ghost-desk-codesign.cer
```

Roll this out via GPO startup script or your RMM/MDM tool instead of running by hand on
each machine one at a time. After this runs once, that device stops flagging
Ghost Desk installers/updates as untrusted — no need to repeat it on every install.

## 3. Set up the controller's machine

Install the app like any other desktop app for your OS. Nothing else is required —
Ghost Desk already points at our self-hosted server by default (verify under
**Settings → Network** if you want to confirm; you shouldn't need to change anything
there).

You now have your own ID and a rotating one-time password shown on the main window.
Anyone connecting *to you* would use those — but for supporting employees, you're
almost always the one initiating the connection, so this mostly doesn't matter day to
day.

## 4. Set up an employee's device (managed device)

Install the same build on their machine/phone. Then decide which mode you want (see
below) and configure accordingly:

### For occasional support (no persistent setup)
Nothing further needed. The employee just needs to have the app open and read you their
ID + current password when they need help (see Support Mode below).

### For ongoing/unattended access (no employee interaction needed later)
1. Open **Settings → Security** on the employee's device and set a **permanent
   password**. (Alternatively, bake one in at build time via `GHOST_DESK_PRESET_PASSWORD`
   — see README — so it's already set the moment the app is installed, with nothing for
   the employee to configure.)
2. Enable **Unattended Access** (same Security settings screen) — this lets you connect
   using the permanent password even if nobody is at the device to approve the session.
3. Note the device's **ID** (shown on its main screen) somewhere you'll remember it —
   there's no fleet/device directory built into Ghost Desk yet, so track ID ↔ employee
   yourself (a spreadsheet is fine for now). The ID stays stable across reboots and
   reconnects — it only changes if the app is reinstalled/its config is wiped.
4. Desktop: make sure the app is set to start on boot/login (check the relevant OS
   autostart setting, or Ghost Desk's own "start on boot" option if present) and excluded
   from sleep so it's reachable later.
5. Android specifically, also do:
   - Enable the **Accessibility service** ("Ghost Desk Input") in Android system settings
     — required for screen/input control, can't be granted automatically.
   - Exclude Ghost Desk from **battery optimization**, or unattended access will drop in
     the background.
   - Some OEM Android builds (Xiaomi, Huawei, etc.) have extra "autostart"/"protected
     apps" toggles — check those too if the device stops responding after a while.

## 5. Connecting: Support Mode vs. Managed Mode

**Support Mode** (ad hoc, one-off):
1. Employee opens Ghost Desk; it shows their **ID** and a **one-time password** that
   changes on each app restart.
2. They read/send you both (call, chat, whatever).
3. On your controller machine, type their ID into the "Control Remote Desktop" /
   connect field, hit connect, enter the password when prompted.
4. You're in. When you disconnect, that's it — no lasting access remains (unless a
   permanent password was separately configured, per step 4 above).

**Managed Mode** (ongoing, no employee needed at connect time):
1. Requires step 4's one-time setup (permanent password + unattended access) to already
   be done on that device.
2. Whenever you need in, type the device's ID into your controller app and connect using
   the permanent password you set. No action needed from the employee, and you can
   disconnect and reconnect as many times as you want without redoing any setup — the
   password and unattended-access config persist on the device.

## 6. What you can do in a session

Once connected, Ghost Desk (via the underlying RustDesk engine) gives you full control
of the device, not just a view of it:

- Full screen view + mouse/keyboard control (including multi-monitor switching on
  desktop, and tap/swipe/scroll input on Android once Accessibility is granted)
- Opening apps, clicking around, typing — anything you could do sitting at the device,
  driven the same way a person would (there's no separate "launch app" shortcut command,
  it's full input passthrough)
- File transfer between your machine and theirs
- Clipboard sync
- Text chat with whoever's at the device (if anyone)
- Audio passthrough (if enabled)
- Remote restart

Availability of each depends on OS and what permissions were granted on the managed
device (e.g., Android's Accessibility requirement above).

## 7. Security notes

- Only connect to devices you own or are explicitly authorized to access/support — see
  the misuse disclaimer in the README.
- A permanent/preset password grants **full remote control** of that device to anyone
  who has it. Treat it like any shared credential. If it needs to change, that means
  rebuilding (for a baked-in preset) or resetting it locally on the device.
- Prefer Support Mode's one-time passwords for occasional help; reserve permanent
  passwords + unattended access for devices you genuinely need to reach without the
  employee present.
- Our signing private keys only ever live in GitHub Actions secrets, never in this repo.
  Only the public `.cer` (no private key) is committed, for distributing trust to managed
  devices.

## 8. Troubleshooting

- **"Waiting for peer's response"/can't connect** — usually a firewall or network issue
  between the managed device and our self-hosted relay server, or the managed device's
  app isn't running. Confirm the app is open (or running in the background/on login) on
  the managed device.
- **Android control doesn't work but screen view does** — Accessibility service isn't
  enabled; see step 4.
- **Managed device stops responding after a while (mobile especially)** — battery
  optimization/OEM autostart killed the app in the background; see step 4.
- **Windows still shows SmartScreen after signing** — the device hasn't run
  `trust-ghost-desk-cert.ps1` yet (section 2), or the signing secrets weren't set when
  that particular build ran.
