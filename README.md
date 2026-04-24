# s&box egg — YorkHost

Pterodactyl / Pelican egg + container image for hosting an **s&box** dedicated
server on Linux via Wine.

Forked / adapted from [HyberHost/gameforge-sbox-egg](https://github.com/HyberHost/gameforge-sbox-egg)
(MIT). Rebased on our own GHCR image so we do not depend on a third party for
production image rebuilds.

## Design — minimal image, SteamCMD-driven install

The Docker image ships **only** what is expensive to provision at runtime:
Wine + a pre-baked Wine prefix with Windows .NET 10 installed. **The s&box
server files themselves are not in the image.** They are fetched via SteamCMD
by the panel install script at server creation, and kept current at runtime.

Why: baking ~3-4 GB of game depot into the image makes it heavy, stale, and
slow to build. The install script does the same SteamCMD call at provisioning
time — one less moving part, one less place to keep fresh.

Expected image size: **~1.5-2 GB**. Build time: **~15 min**.

## Layout

| Path | Purpose |
|---|---|
| [Yolk/Dockerfile](Yolk/Dockerfile) | Two-stage image build: Wine + baked Windows .NET 10 Wine prefix. No game files. |
| [Yolk/entrypoint.sh](Yolk/entrypoint.sh) | Runtime: seed Wine prefix, run SteamCMD update, launch `sbox-server.exe`. |
| [Yolk/install.sh](Yolk/install.sh) | Panel install script: bootstraps SteamCMD into `/mnt/server/steamcmd` and fetches the s&box depot into `/mnt/server/sbox`. |
| [sandbox-pterodactyl.json](sandbox-pterodactyl.json) | Pterodactyl egg export. |
| [sandbox-pelican.json](sandbox-pelican.json) | Pelican egg export. |
| [.github/workflows/build-and-publish.yml](.github/workflows/build-and-publish.yml) | Builds and pushes to `ghcr.io/yorkhost-fr/s-box-egg-wisp`. |

## Image

Published at: `ghcr.io/yorkhost-fr/s-box-egg-wisp:latest`

Tagged on every push to `main` plus a timestamped tag and short SHA. Also
rebuilt on the 1st of each month via cron to refresh Wine + .NET base
packages.

Local build:

```bash
docker build --platform linux/amd64 \
  -f Yolk/Dockerfile \
  -t ghcr.io/yorkhost-fr/s-box-egg-wisp:latest \
  .
```

## Install and runtime flow

1. **Panel server creation** — Pterodactyl/Pelican runs [Yolk/install.sh](Yolk/install.sh)
   in a `debian:bookworm-slim` container: installs SteamCMD dependencies,
   downloads SteamCMD into `/mnt/server/steamcmd`, runs
   `app_update 1892930 validate` with `+@sSteamCmdForcePlatformType windows`.
   Server files end up in `/mnt/server/sbox/`.
2. **First boot** — the image entrypoint seeds the Wine prefix from
   `/opt/sbox-wine-prefix` into `/home/container/.wine`. Then runs SteamCMD
   again (`SBOX_AUTO_UPDATE=1` default) on the already-populated `sbox/` dir —
   this is cheap since everything is already up to date.
3. **Subsequent boots** — entrypoint runs SteamCMD to pull any s&box update
   from Facepunch. On Steam failure, it falls back to the files on disk and
   launches anyway.

## Changes vs upstream

- Image moved to our own GHCR namespace (was `ghcr.io/hyberhost/gameforge-sbox-egg`).
- **s&box depot no longer baked into the image**. Install script owns that
  responsibility. Runtime updater keeps things current.
- Install script is no longer a no-op. It bootstraps SteamCMD and fetches the
  depot at provisioning.
- Install container: `debian:bookworm-slim` (was `alpine:3`), needed for
  SteamCMD (32-bit glibc).
- Author / labels / source URLs point at YorkHost.

## Panel variables

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
3. Create a server. The install script downloads s&box via SteamCMD.
4. Start. Entrypoint seeds the Wine prefix, runs SteamCMD to confirm current
   version, launches.

## Notes

- `linux/amd64` only.
- Logs under `/home/container/logs/`.
- Runtime behaviour changes belong in `Yolk/entrypoint.sh`; panel UX changes
  belong in the egg JSONs (both must stay in sync).
