# s&box YorkHost egg — Docker image build
#
# Two-stage build:
#   Stage 1 (builder): bakes a Wine prefix + Windows .NET, and prefetches the
#     s&box Windows server depot via SteamCMD into /work/server.
#   Stage 2 (runtime): steamcmd/steamcmd:alpine with Wine layered on top.
#     The baked prefix is copied to /opt/sbox-wine-prefix and the server
#     template to /opt/sbox-server-template, both outside the /home/container
#     Pterodactyl/Pelican volume. entrypoint.sh seeds them on first boot.
#
# Build from repo root:
#   docker build --platform linux/amd64 \
#     -f Yolk/Dockerfile \
#     -t ghcr.io/yorkhost-fr/s-box-egg-wisp:latest \
#     .
#
# Originally based on HyberHost/gameforge-sbox-egg (MIT).

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Builder
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:trixie-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG BAKE_WINETRICKS_VERBS="win10 vcrun2022"
ARG BAKE_WIN_DOTNET_VERSION=10.0.0
ARG BAKE_SBOX_APP_ID=1892930
ARG BAKE_SBOX_CACHE_BUSTER=static
ARG BAKE_STEAMCMD_TIMEOUT=900

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

# Bake s&box server content at build-time so first boot is not Steam-dependent.
# Keep this Windows-only to avoid baking Linux depots into the template.
RUN mkdir -p /work/steamcmd /work/server \
    && test -n "${BAKE_SBOX_CACHE_BUSTER}" \
     && wget -qO /work/steamcmd/steamcmd_linux.tar.gz \
         https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
     && tar -xzf /work/steamcmd/steamcmd_linux.tar.gz -C /work/steamcmd \
     && chmod 0755 /work/steamcmd/steamcmd.sh \
     && rm /work/steamcmd/steamcmd_linux.tar.gz \
     && if ! timeout "${BAKE_STEAMCMD_TIMEOUT}" bash /work/steamcmd/steamcmd.sh \
            +@ShutdownOnFailedCommand 1 \
            +@NoPromptForPassword 1 \
            +@sSteamCmdForcePlatformType windows \
            +force_install_dir /work/server \
            +login anonymous \
            +app_update ${BAKE_SBOX_APP_ID} validate \
            +quit; then \
            if [ "$?" -eq 124 ]; then \
                echo "warn: build-time SteamCMD timed out after ${BAKE_STEAMCMD_TIMEOUT}s (possible Steam API/user info stall)" >&2; \
            fi; \
            echo "warn: build-time Windows depot download failed for app ${BAKE_SBOX_APP_ID}; runtime update will be required" >&2; \
            rm -rf /work/server/*; \
          fi \
     && if [ ! -f /work/server/sbox-server.exe ]; then \
            echo "warn: build-time prebake is missing /work/server/sbox-server.exe; startup will rely on runtime SteamCMD update" >&2; \
        fi \
      && rm -rf /work/steamcmd

# Sanity check on .NET install (warn only).
RUN if ! find /work/wineprefix/drive_c -name hostfxr.dll 2>/dev/null | grep -q .; then \
        echo "warn: hostfxr.dll not found — Windows .NET may have failed to install" >&2; \
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime (SteamCMD Alpine base + Wine runtime)
# ─────────────────────────────────────────────────────────────────────────────
FROM steamcmd/steamcmd:alpine

LABEL org.opencontainers.image.title="s&box YorkHost egg" \
      org.opencontainers.image.description="s&box dedicated server image for Pterodactyl/Pelican (YorkHost)" \
      org.opencontainers.image.source="https://github.com/YorkHost-fr/s-box-egg-wisp" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="YorkHost"

ARG PUID=999
ARG PGID=999

# Runtime defaults
ENV CONTAINER_HOME=/home/container \
    HOME=/home/container \
    WINEPREFIX=/home/container/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=icu,icuuc=d \
    SBOX_BAKED_WINEPREFIX=/opt/sbox-wine-prefix \
    SBOX_BAKED_SERVER_TEMPLATE=/opt/sbox-server-template \
    SBOX_APP_ID=1892930 \
    SBOX_INSTALL_DIR=/home/container/sbox \
    SBOX_SERVER_EXE=/home/container/sbox/sbox-server.exe \
    SBOX_AUTO_UPDATE=1 \
    SBOX_LOG_KEEP=10 \
    STEAM_PLATFORM=windows \
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

RUN apk add --no-cache \
                bash \
                ca-certificates \
                gnutls \
                libgcc \
                libstdc++ \
                tar \
                wget \
                wine

RUN mkdir -p \
        /home/container/.wine \
        /home/container/.local/share \
        /home/container/projects \
        /home/container/logs \
        /home/container/sbox \
    && chmod 1777 /tmp

COPY --from=builder /work/wineprefix /opt/sbox-wine-prefix
COPY --from=builder /work/server /opt/sbox-server-template

RUN chmod -R u+rwX,g+rX,o+rX /opt/sbox-wine-prefix /opt/sbox-server-template

COPY Yolk/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR ${CONTAINER_HOME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start-sbox"]
