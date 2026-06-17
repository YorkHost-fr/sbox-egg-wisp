# CHANGELOG

## 2026-06-17 — fix: server never boots (SteamCMD windows-platform / poisoned manifest)

Symptom: on boot the auto-update logged
`steamcmd.sh: Couldn't find steamcmd at .../Steam/steamcmd/windows/steamcmd, exiting`,
then `sbox-server.exe was not found`, and the server crash-looped (exit 1).
Install-time prefetch also failed with `Error! App '1892930' state is 0x402`.

### Root causes
1. **`STEAM_PLATFORM=windows` (Dockerfile ENV).** The `steamcmd/steamcmd:alpine`
   base wrapper reads `STEAM_PLATFORM` to choose which *client binary* to exec,
   so it looked for a windows-native steamcmd that doesn't exist on Linux and
   exited before any update could run. The windows platform must be selected
   only for *content* via `+@sSteamCmdForcePlatformType`, never via env.
2. **SteamCMD resolved to the wrong launcher.** `resolve_steamcmd_binary` only
   checked the distro wrappers.
3. **Poisoned appmanifest.** A failed `app_update` leaves
   `appmanifest_1892930.acf` in a failure state (0x402); every later run then
   aborts instantly without downloading.

### Yolk/Dockerfile
- Runtime base switched from `steamcmd/steamcmd:alpine` to `debian:trixie-slim`
  (same family as the builder stage → baked Wine prefix is binary-compatible).
- Removed `ENV STEAM_PLATFORM=windows`; added `STEAMCMD_DIR=/opt/steamcmd`.
- Ship the Valve SteamCMD tarball at `/opt/steamcmd` (world-writable for the
  arbitrary Wings UID + self-update); install Debian wine + 32-bit libs.

### Yolk/entrypoint.sh
- `resolve_steamcmd_binary` now prefers `${STEAMCMD_DIR}/steamcmd.sh` (Valve
  launcher, always linux32) and runs it via `bash`; no windows-binary lookup.
- Dropped the Debian-only `LD_LIBRARY_PATH`; HOME pinned to the server volume.
- Added `clear_steam_appmanifest` + `dump_steamcmd_stderr`; on update failure
  the manifest is cleared and the update retried once with validate.

### Yolk/install.sh
- Prefetch now clears a poisoned manifest and retries once (still non-fatal).

## 2026-04-28 — port handling + .NET bump + egg variable visibility

### Yolk/entrypoint.sh

Fixed `+port` and `+net_query_port` handling in `run_sbox()`:

- **Always pass `+port ${SERVER_PORT}`**, regardless of connect mode. Previously
  the flag was only set in Direct Connect, and used a hardcoded `27015`
  fallback when `SERVER_PORT` was empty. Even in Steam Relay mode we want a
  predictable bind port (the panel allocation).

- **Fallback `+net_query_port` to `SERVER_PORT`** when `QUERY_PORT` is empty,
  so A2S queries land somewhere predictable in Direct Connect mode without
  forcing operators to allocate a second port.

- **Direct Connect mode now sets `+sbox_steam_relay 0`** explicitly, in
  addition to `+net_hide_address 0`. Without this, the server kept routing
  through the Steam Datagram Relay even when Direct Connect was enabled.

### Yolk/Dockerfile

- **Bumped `BAKE_WIN_DOTNET_VERSION` from `10.0.0` to `10.0.7`** to match the
  current S&Box runtime requirement. Old value caused
  `FileNotFoundException: ...Microsoft.NETCore.App\10.0.7\System.Runtime.dll`
  on recent S&Box builds because the runtime was hardcoded to 10.0.0.

### sandbox-pterodactyl.json / sandbox-pelican.json

- **Made `QUERY_PORT`, `ENABLE_DIRECT_CONNECT`, `TOKEN`, `SBOX_BRANCH` visible
  and editable by users.** They were `user_viewable: false`, so operators
  could not enable Direct Connect or set a Steam GSLT from the panel UI.
- **Bumped `WIN_DOTNET_VERSION` default to `10.0.7`** to match the Dockerfile.
- **Made `GAME` required** (was nullable, but the server cannot start without).
- **Widened the boot-done detection regex** to match `Bootstrap Networking`,
  `Server is ready`, and `Server started`. The previous `Loading game` was
  matching too early in the boot sequence and Pterodactyl was marking the
  server as running before it actually accepted connections.

### Migration

1. Replace the files in your local clone of the repo with these versions
2. `git add -A && git commit -m "fix: port handling, .NET 10.0.7, egg variable visibility"`
3. `git push origin main`
4. GitHub Actions rebuilds and publishes `ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`
5. On Wings nodes: `docker pull ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`
6. Re-import `sandbox-pterodactyl.json` in the panel (Admin > Nests > Update Egg)
   so the new variable visibility takes effect on existing servers.
7. Restart S&Box servers (no reinstall needed; the entrypoint reseeds the
   prefix from the new baked image automatically on first boot).

