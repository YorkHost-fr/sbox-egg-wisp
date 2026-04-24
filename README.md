# s&box egg — YorkHost

Pterodactyl / Pelican egg + container image for hosting an **s&box** dedicated
server on Linux via Wine.

Forked / adapted from [HyberHost/gameforge-sbox-egg](https://github.com/HyberHost/gameforge-sbox-egg)
(MIT). Rebased on our own GHCR image so we do not depend on a third party for
production image rebuilds.

## Layout

| Path | Purpose |
|---|---|
| [Yolk/Dockerfile](Yolk/Dockerfile) | Two-stage image build (Wine + baked Windows .NET + baked s&box depot). |
| [Yolk/entrypoint.sh](Yolk/entrypoint.sh) | Runtime: seed prefix/files, run SteamCMD update, launch `sbox-server.exe`. |
| [Yolk/install.sh](Yolk/install.sh) | Panel-side install script: bootstraps SteamCMD into `/mnt/server` and prefetches the s&box depot. |
| [sandbox-pterodactyl.json](sandbox-pterodactyl.json) | Pterodactyl egg export. |
| [sandbox-pelican.json](sandbox-pelican.json) | Pelican egg export. |
| [.github/workflows/build-and-publish.yml](.github/workflows/build-and-publish.yml) | Builds and pushes to `ghcr.io/yorkhost-fr/s-box-egg-wisp`. |

## Image

Published at: `ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`

Tagged on every push to `main` plus a timestamped tag and short SHA. Also
rebuilt every 3 days via cron so the baked s&box depot stays fresh.

Local build:

```bash
docker build --platform linux/amd64 \
  -f Yolk/Dockerfile \
  -t ghcr.io/yorkhost-fr/s-box-egg-wisp:latest \
  .
```

## Changes vs upstream

- Image moved to our own GHCR namespace (was `ghcr.io/hyberhost/gameforge-sbox-egg`).
- Install script is no longer a no-op. It now bootstraps SteamCMD inside the
  server volume and prefetches the s&box Windows depot, so the first container
  boot does not block on a Steam round-trip. Runtime `SBOX_AUTO_UPDATE` still
  keeps the server current on subsequent boots.
- Install container: `debian:bookworm-slim` (was `alpine:3`), needed for
  SteamCMD (32-bit glibc).
- Author / labels / source URLs point at YorkHost.

## Install flow

Two places fetch s&box content, intentionally redundant:

1. **Image build** — `Yolk/Dockerfile` runs SteamCMD at build time and bakes
   the depot into `/opt/sbox-server-template`. `entrypoint.sh` seeds from
   there on first boot if the panel volume is empty.
2. **Panel install script** — `Yolk/install.sh` runs in the install container
   and populates `/mnt/server/sbox` directly. This means the very first boot
   on a brand-new server already has files on disk, even before any runtime
   SteamCMD call.
3. **Runtime** — `entrypoint.sh` runs SteamCMD on boot (if
   `SBOX_AUTO_UPDATE=1`) to keep the server patched. On failure it falls back
   to whatever is already on disk.

## Panel variables

Identical to upstream; summary:

| Variable | Default | Notes |
|---|---|---|
| `GAME` | `facepunch.walker` | `+game` package. |
| `SERVER_NAME` | `Merci YorkHost.fr !` | Public name. |
| `MAP` | (empty) | Optional map/package. |
| `SBOX_PROJECT` | (empty) | Relative `.sbproj` under `projects/`. |
| `SBOX_EXTRA_ARGS` | (empty) | Extra args appended to `sbox-server.exe`. |
| `MAX_PLAYERS` | (empty) | Integer, 1–256. |
| `SBOX_AUTO_UPDATE` | `1` | Run SteamCMD on every boot. |
| `SBOX_BRANCH` | (empty) | Steam beta branch. |
| `SBOX_STEAMCMD_TIMEOUT` | `600` | Per-call SteamCMD timeout, `0` to disable. |
| `QUERY_PORT` | (empty) | Direct-connect query port. |
| `ENABLE_DIRECT_CONNECT` | `0` | Bypass Steam relay. |
| `TOKEN` | (empty) | GSLT. |
| `WIN_DOTNET_VERSION` | `10.0.0` | Informational — baked at image build. |

## Quick start

1. Import `sandbox-pterodactyl.json` (or `sandbox-pelican.json`) into your panel.
2. Confirm the docker image is `ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`.
3. Create a server. The install script prefetches the depot.
4. Start. Entrypoint seeds the Wine prefix if needed, runs SteamCMD, launches.

## Notes

- `linux/amd64` only.
- Logs under `/home/container/logs/`.
- Runtime behaviour changes belong in `Yolk/entrypoint.sh`; panel UX changes
  belong in the egg JSONs (both must stay in sync).
