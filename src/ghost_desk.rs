// Ghost Desk branding + self-hosted server defaults.
//
// This module is the single place where Ghost Desk diverges from stock
// RustDesk defaults. It does not patch the `hbb_common` engine: it only
// populates the override points (`DEFAULT_SETTINGS`, `APP_NAME`) that
// `hbb_common::config` already exposes for white-labeled clients.
//
// Values are baked in at compile time via `option_env!`, so a build can be
// re-pointed at a different server/brand without touching this file:
//
//   GHOST_DESK_ID_SERVER=dev.example.com \
//   GHOST_DESK_SERVER_KEY=<base64 pubkey> \
//   cargo build
//
// Anyone running the resulting client can still override the server/key from
// Settings > Network at any time; these are defaults, not forced values.

use hbb_common::config::{self, keys};

const fn const_or<'a>(opt: Option<&'a str>, default: &'a str) -> &'a str {
    match opt {
        Some(v) => v,
        None => default,
    }
}

/// Our self-hosted rustdesk-server (hbbs) instance.
const ID_SERVER: &str = const_or(option_env!("GHOST_DESK_ID_SERVER"), "212.147.227.60");
/// Relay server (hbbr). Same host as hbbs in the current deployment
/// (docker compose, `network_mode: host`).
const RELAY_SERVER: &str = const_or(option_env!("GHOST_DESK_RELAY_SERVER"), "212.147.227.60");
/// Public key of the self-hosted server, from `id_ed25519.pub`.
const SERVER_KEY: &str = const_or(
    option_env!("GHOST_DESK_SERVER_KEY"),
    "4CozyI5ZXDpA3PMqAH8H1MwD71OLAJAc1bZ8redS3fs=",
);
/// Product name shown throughout the UI, window titles, and IPC/socket paths.
pub const APP_DISPLAY_NAME: &str = const_or(option_env!("GHOST_DESK_APP_NAME"), "Ghost Desk");

/// Optional preset permanent password, baked in at compile time. Empty means
/// "no preset password" (end users set their own, as in stock RustDesk).
///
/// This is a fleet-management default, not a hidden backdoor: once baked in,
/// `Settings > Security` on the device shows a permanent password is preset
/// (RustDesk's existing `preset_password_warning` UI), and any user with the
/// build can still set their own password to override it locally.
const PRESET_PASSWORD: &str = const_or(option_env!("GHOST_DESK_PRESET_PASSWORD"), "");
/// Salt paired with `PRESET_PASSWORD`. Only matters if a preset password is
/// set; changing it invalidates any previously-baked password of the same
/// build. Fixed (not random) so every install of a given build agrees on it.
const PRESET_PASSWORD_SALT: &str = const_or(
    option_env!("GHOST_DESK_PRESET_PASSWORD_SALT"),
    "ghost-desk-preset-v1",
);

/// Applies Ghost Desk defaults. Called once, early in process startup
/// (see `common::load_custom_client`, which every entry point invokes).
pub fn apply_defaults() {
    {
        let mut default_settings = config::DEFAULT_SETTINGS.write().unwrap();
        default_settings.insert(
            keys::OPTION_CUSTOM_RENDEZVOUS_SERVER.to_owned(),
            ID_SERVER.to_owned(),
        );
        default_settings.insert(keys::OPTION_KEY.to_owned(), SERVER_KEY.to_owned());
        default_settings.insert(
            keys::OPTION_RELAY_SERVER.to_owned(),
            RELAY_SERVER.to_owned(),
        );
    }
    *config::APP_NAME.write().unwrap() = APP_DISPLAY_NAME.to_owned();

    if !PRESET_PASSWORD.is_empty() {
        let h1 = config::compute_permanent_password_h1(PRESET_PASSWORD, PRESET_PASSWORD_SALT);
        let storage = "00".to_owned()
            + &hbb_common::sodiumoxide::base64::encode(
                h1,
                hbb_common::sodiumoxide::base64::Variant::Original,
            );
        let mut hard_settings = config::HARD_SETTINGS.write().unwrap();
        hard_settings.insert("password".to_owned(), storage);
        hard_settings.insert("salt".to_owned(), PRESET_PASSWORD_SALT.to_owned());
    }
}
