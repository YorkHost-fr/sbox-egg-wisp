# s&box YorkHost egg — Docker image (ALPINE runtime)
#
# WHY ALPINE RUNTIME (2026-06-20):
#   The Debian Trixie Wine (glibc) crashes at Steam networking init under our
#   node networking ("Assertion Failed: CalcUnIPThisBox - GetAdaptersAddresses
#   returned 13" -> exit 1, right after "Bootstrap Networking"). The SAME server,
#   on the SAME node, boots fine on Alpine Wine (musl) — proven against
#   mydrissjlv's image. So the runtime Wine is the differentiator, not the node
#   network. We keep our Debian builder (it bakes the Wine prefix + Windows .NET
#   exactly like before) but RUN the server on Alpine Wine.
#
# We keep our working SteamCMD setup (Valve tarball at /opt/steamcmd + the
# build-time warm-up + the entrypoint warm-up/loop), so the auto-update keeps
# completing for real — unlike the prebaked-only upstreams that fall back to a
# stale build.
#
# Build from repo root:
#   docker build --platform linux/amd64 \
#     -f Yolk/Dockerfile \
#     -t ghcr.io/yorkhost-fr/s-box-egg-wisp:latest \
#     .
#
# Originally based on HyberHost/gameforge-sbox-egg (MIT).

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Builder — bakes the Wine prefix + Windows .NET (Debian, unchanged)
#
# The prefix is mostly registry/config and is portable: a Debian-built prefix
# runs fine under Alpine Wine at runtime (this is exactly what mydrissjlv's
# working image does).
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
# Stage 2: Runtime — Alpine + Wine (musl). This is the actual fix.
#
# Base is steamcmd/steamcmd:alpine (same family mydrissjlv runs on) which already
# ships the glibc shim needed to run the Valve SteamCMD linux32 client, so our
# /opt/steamcmd tarball runs here too. We DO NOT set STEAM_PLATFORM (that env is
# what made the alpine steamcmd wrapper look for a non-existent windows binary);
# the windows depot is selected only for content via +@sSteamCmdForcePlatformType
# inside entrypoint.sh.
# ─────────────────────────────────────────────────────────────────────────────
FROM steamcmd/steamcmd:alpine

LABEL org.opencontainers.image.title="s&box YorkHost egg" \
      org.opencontainers.image.description="s&box dedicated server image for Pterodactyl/Pelican (YorkHost) — Alpine Wine runtime" \
      org.opencontainers.image.source="https://github.com/YorkHost-fr/s-box-egg-wisp" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="YorkHost"

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
    SERVER_STARTUP_SCENE= \
    SERVER_NAME= \
    SBOX_PROJECT= \
    SBOX_EXTRA_ARGS= \
    XDG_RUNTIME_DIR=/tmp

# Wine + the libraries it needs, via apk (musl). Mirrors the dependency set of
# the known-good Alpine s&box image. No winbind (not required for s&box).
RUN apk add --no-cache \
        bash \
        ca-certificates \
        coreutils \
        curl \
        tar \
        tzdata \
        gnutls \
        libgcc \
        libstdc++ \
        freetype \
        fontconfig \
        wine

# Valve SteamCMD tarball at /opt/steamcmd. World-writable: Wings runs the
# container under an arbitrary UID and SteamCMD self-updates by rewriting its own
# dir. The steamcmd/steamcmd:alpine base provides the glibc compat to run it.
RUN mkdir -p "${STEAMCMD_DIR}" \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
       | tar -xz -C "${STEAMCMD_DIR}" \
    && chmod +x "${STEAMCMD_DIR}/steamcmd.sh" \
    && find "${STEAMCMD_DIR}" -type f -name steamcmd -exec chmod +x {} + \
    && chmod -R 0777 "${STEAMCMD_DIR}"

# Warm up SteamCMD at build time so its first-run self-update is already absorbed
# in the image; the first runtime boot then runs app_update immediately.
RUN HOME=/tmp bash "${STEAMCMD_DIR}/steamcmd.sh" +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +quit 2>/dev/null || true \
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
