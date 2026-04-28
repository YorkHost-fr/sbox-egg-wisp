# CHANGELOG

## 2026-04-28 — port handling + .NET bump

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

### Migration

1. Replace the files in your local clone of the repo with these versions
2. `git add -A && git commit -m "fix: port handling and .NET 10.0.7"`
3. `git push origin main`
4. GitHub Actions rebuilds and publishes `ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`
5. On Wings nodes: `docker pull ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`
6. Restart S&Box servers (no reinstall needed; the entrypoint reseeds the
   prefix from the new baked image automatically on first boot).
