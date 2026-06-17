# s&box YorkHost egg — minimal Docker image
#
# The image ships only what is **expensive to provision at runtime**:
#   - Wine runtime
#   - A pre-baked Wine prefix with Windows .NET 10 installed
#
# The s&box server files themselves are NOT baked. They are fetched by the
# panel install script (Yolk/install.sh) via SteamCMD into /home/container/sbox
# at server creation, and kept current at runtime by the entrypoint.
#
# Two-stage build:
#   Stage 1 (builder): installs Wine on Debian, creates a Wine prefix,
#     installs Windows .NET 10 via Wine, and copies the prefix out.
#   Stage 2 (runtime): steamcmd/steamcmd:alpine + Wine apk. Baked prefix is
#     copied to /opt/sbox-wine-prefix. entrypoint.sh seeds it into the
#     /home/container volume on first boot.
#
# Build from repo root:
#   docker build --platform linux/amd64 \
#     -f Yolk/Dockerfile \
#     -t ghcr.io/yorkhost-fr/s-box-egg-wisp:latest \
#     .
#
# Originally based on HyberHost/gameforge-sbox-egg (MIT).

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Builder — bakes the Wine prefix + Windows .NET
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:trixie-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG BAKE_WINETRICKS_VERBS="win10 vcrun2022"
ARG BAKE_WIN_DOTNET_VERSION=10.0.7

RUN dpkg --add-architecture i386 \
    && sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       cabextract \
       git \
       make \
       psmisc \
       wget \
       wine \
       wine32 \
       wine64 \
       libwine \
       libwine:i386 \
       fonts-wine \
       winbind \
       xauth \
       xserver-xorg-core \
       xvfb \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/Winetricks/winetricks.git /tmp/winetricks \
    && cd /tmp/winetricks \
    && make install \
    && rm -rf /tmp/winetricks

RUN mkdir -p /work && cd /work && \
    WINEPREFIX=/work/wineprefix xvfb-run winetricks -q --force ${BAKE_WINETRICKS_VERBS} && \
    wget -q "https://builds.dotnet.microsoft.com/dotnet/Runtime/${BAKE_WIN_DOTNET_VERSION}/dotnet-runtime-${BAKE_WIN_DOTNET_VERSION}-win-x64.exe" -O dotnet-installer.exe && \
    WINEPREFIX=/work/wineprefix xvfb-run wine dotnet-installer.exe /install /quiet /norestart && \
    rm dotnet-installer.exe && \
    rm -rf "/work/wineprefix/drive_c/ProgramData/Package Cache"

# Sanity check on .NET install (warn only).
RUN if ! find /work/wineprefix/drive_c -name hostfxr.dll 2>/dev/null | grep -q .; then \
        echo "warn: hostfxr.dll not found — Windows .NET may have failed to install" >&2; \
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime (Debian Trixie + Wine + Valve SteamCMD tarball)
#
# CHANGED (YorkHost fix, 2026-06): the runtime used to be
# `steamcmd/steamcmd:alpine` with ENV STEAM_PLATFORM=windows. That image's
# steamcmd wrapper reads STEAM_PLATFORM to decide which client binary to exec,
# so it looked for $HOME/.local/share/Steam/steamcmd/windows/steamcmd — which
# does not exist (there is no native windows steamcmd on Linux) — and exited.
# The boot-time auto-update could therefore never run and sbox-server.exe was
# never fetched. We now run on Debian Trixie (same family as the builder stage,
# so the baked Wine prefix is binary-compatible) and ship the Valve SteamCMD
# tarball at /opt/steamcmd. steamcmd.sh always runs the linux32 client; the
# windows platform is selected only for *content* via the explicit
# +@sSteamCmdForcePlatformType flag in entrypoint.sh — no windows-binary lookup.
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:trixie-slim

LABEL org.opencontainers.image.title="s&box YorkHost egg" \
      org.opencontainers.image.description="s&box dedicated server image for Pterodactyl/Pelican (YorkHost)" \
      org.opencontainers.image.source="https://github.com/YorkHost-fr/s-box-egg-wisp" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="YorkHost"

ARG DEBIAN_FRONTEND=noninteractive

# Runtime defaults.
# NOTE: STEAM_PLATFORM is intentionally NOT set (see Stage 2 header).
ENV CONTAINER_HOME=/home/container \
    HOME=/home/container \
    WINEPREFIX=/home/container/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=icu,icuuc=d \
    SBOX_BAKED_WINEPREFIX=/opt/sbox-wine-prefix \
    STEAMCMD_DIR=/opt/steamcmd \
    SBOX_APP_ID=1892930 \
    SBOX_INSTALL_DIR=/home/container/sbox \
    SBOX_SERVER_EXE=/home/container/sbox/sbox-server.exe \
    SBOX_AUTO_UPDATE=1 \
    SBOX_LOG_KEEP=10 \
    DOTNET_EnableWriteXorExecute=0 \
    DOTNET_TieredCompilation=0 \
    DOTNET_ReadyToRun=0 \
    DOTNET_ZapDisable=1 \
    GAME= \
    MAP= \
    SERVER_NAME= \
    SBOX_PROJECT= \
    SBOX_EXTRA_ARGS= \
    XDG_RUNTIME_DIR=/tmp

# i386 + contrib/non-free for wine32 (same component set as the builder stage so
# the runtime wine matches the wine that created the baked prefix).
RUN dpkg --add-architecture i386 \
    && sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       coreutils \
       curl \
       tar \
       tzdata \
       lib32gcc-s1 \
       libgcc-s1 \
       libstdc++6 \
       libstdc++6:i386 \
       libfreetype6 \
       libfreetype6:i386 \
       wine \
       wine32 \
       wine64 \
       libwine \
       libwine:i386 \
       fonts-wine \
       winbind \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Valve SteamCMD tarball (NOT a distro package / not the alpine wrapper). Wings
# runs the container under an arbitrary UID that won't own this dir, and SteamCMD
# self-updates by rewriting its own directory on first run, so it must be
# world-writable. It's an ephemeral in-image dir, so 0777 is harmless.
RUN mkdir -p "${STEAMCMD_DIR}" \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
       | tar -xz -C "${STEAMCMD_DIR}" \
    && chmod +x "${STEAMCMD_DIR}/steamcmd.sh" \
    && find "${STEAMCMD_DIR}" -type f -name steamcmd -exec chmod +x {} + \
    && chmod -R 0777 "${STEAMCMD_DIR}"

RUN mkdir -p \
        /home/container/.wine \
        /home/container/.local/share \
        /home/container/projects \
        /home/container/logs \
        /home/container/sbox \
    && chmod 1777 /tmp

COPY --from=builder /work/wineprefix /opt/sbox-wine-prefix
RUN chmod -R u+rwX,g+rX,o+rX /opt/sbox-wine-prefix

COPY Yolk/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR ${CONTAINER_HOME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start-sbox"]
