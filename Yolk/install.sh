#!/bin/bash
# s&box install script — YorkHost egg
#
# Runs once in the panel's install container (Pterodactyl/Pelican) against
# /mnt/server (which becomes /home/container at runtime). Goals:
#   1. Bootstrap SteamCMD inside the server volume.
#   2. Prefetch the s&box Windows server depot (app 1892930) so the first
#      container boot does not depend on a SteamCMD round-trip to Valve.
#   3. Create the directory skeleton the entrypoint expects.
#
# Failure of the prefetch is non-fatal — the runtime entrypoint will retry
# (SBOX_AUTO_UPDATE=1 by default), so the worst case is the original upstream
# behaviour (first boot pays the SteamCMD cost).
set -e

APP_ID="${SBOX_APP_ID:-1892930}"
BRANCH="${SBOX_BRANCH:-}"
PLATFORM="windows"

export DEBIAN_FRONTEND=noninteractive
dpkg --add-architecture i386
apt-get update -qq
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    lib32gcc-s1 \
    >/dev/null

cd /mnt/server
mkdir -p sbox projects logs steamcmd .wine

if [ ! -f steamcmd/steamcmd.sh ]; then
    echo "[install] downloading SteamCMD..."
    curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
        | tar -xz -C steamcmd
    chmod +x steamcmd/steamcmd.sh
fi

# Warm-up: SteamCMD's first invocation is consumed by its own self-update and
# never runs app_update. Absorb that with a throwaway +quit so the prefetch
# below actually downloads the depot instead of self-updating again. Non-fatal.
echo "[install] warming up SteamCMD (absorbing first-run self-update)..."
./steamcmd/steamcmd.sh +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +quit || true

echo "[install] prefetching s&box server (app ${APP_ID}, platform ${PLATFORM}${BRANCH:+, branch ${BRANCH}})..."

STEAM_ARGS=(
    +@ShutdownOnFailedCommand 1
    +@NoPromptForPassword 1
    +@sSteamCmdForcePlatformType "${PLATFORM}"
    +force_install_dir /mnt/server/sbox
    +login anonymous
    +app_update "${APP_ID}"
)

if [ -n "${BRANCH}" ]; then
    STEAM_ARGS+=( -beta "${BRANCH}" )
fi

STEAM_ARGS+=( validate +quit )

prefetch_ok=0
if ./steamcmd/steamcmd.sh "${STEAM_ARGS[@]}"; then
    prefetch_ok=1
else
    # A failed/interrupted app_update poisons appmanifest_<appid>.acf, after which
    # SteamCMD aborts instantly ("state is 0x402") on every later run. Clear it
    # and retry once so the prefetch can actually seed sbox-server.exe.
    MANIFEST="/mnt/server/sbox/steamapps/appmanifest_${APP_ID}.acf"
    if [ -f "${MANIFEST}" ]; then
        echo "[install] clearing stale Steam app manifest ${MANIFEST} and retrying prefetch once"
        rm -f "${MANIFEST}"
    else
        echo "[install] prefetch failed; retrying once"
    fi
    if ./steamcmd/steamcmd.sh "${STEAM_ARGS[@]}"; then
        prefetch_ok=1
    fi
fi

if [ "${prefetch_ok}" -ne 1 ]; then
    echo "[install] SteamCMD prefetch failed; runtime updater will retry on first boot"
fi

if [ -f sbox/sbox-server.exe ]; then
    echo "[install] prefetch ok: sbox/sbox-server.exe is present"
else
    echo "[install] warn: sbox-server.exe missing — first boot will rely on the runtime updater"
fi

echo "[install] done."
