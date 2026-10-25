# Keep the branch configurable so the same image recipe can test other refs later.
ARG MM_REF=develop
# Keep the small server image as the default; desktop modes are opt-in build variants.
ARG MM_MODE=server

# Install and prepare MagicMirror in a separate stage; build tools won't end up in the runtime image.
FROM node:26-bookworm-slim AS build
ARG MM_REF
ARG MM_MODE

# Git is only needed to fetch the selected MagicMirror branch.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# Fetch only the selected branch, install server dependencies, then drop Git history.
RUN git clone --depth 1 --branch "${MM_REF}" https://github.com/MagicMirrorOrg/MagicMirror . \
    # Electron is optional, so include it only in desktop image variants.
    && if [ "${MM_MODE}" = "electron" ] || [ "${MM_MODE}" = "client" ]; then \
        npm ci --omit=dev --no-audit --no-fund \
        && node node_modules/electron/install.js; \
    else \
        npm ci --omit=dev --omit=optional --no-audit --no-fund; \
    fi \
    && rm -rf .git

# Reuse the same Node version at runtime, without the build tools from the first stage.
FROM node:26-bookworm-slim
ARG MM_MODE

ENV NODE_ENV=production \
    MM_MODE=${MM_MODE}
WORKDIR /opt/magicmirror

COPY --from=build --chown=node:node /src/ ./
# Keep the container's default config separate so a mounted config directory can persist user edits.
COPY --chown=node:node config.js /opt/magicmirror/config.js.container
# Install the startup script as an executable in a directory on PATH.
COPY --chmod=755 container-entrypoint.sh /usr/local/bin/container-entrypoint

# Electron connects to this private runtime dir; its Wayland socket is bind-mounted here.
# Create the config location and runtime dir for the unprivileged runtime user.
RUN mkdir -p /opt/magicmirror/config \
    && mkdir -p /run/user/1000 \
    && chown node:node /opt/magicmirror/config /run/user/1000 \
    && chmod 700 /run/user/1000

# Electron needs these libraries for Wayland rendering; keep them out of server builds.
RUN if [ "${MM_MODE}" = "electron" ] || [ "${MM_MODE}" = "client" ]; then \
        apt-get update \
        && apt-get install --yes --no-install-recommends \
            libasound2 libatk-bridge2.0-0 libatk1.0-0 libcairo2 libcups2 \
            libdbus-1-3 libdrm2 libgbm1 libglib2.0-0 libgtk-3-0 \
            libnss3 libpango-1.0-0 libwayland-client0 libwayland-cursor0 \
            libwayland-egl1 libx11-xcb1 libxcomposite1 libxdamage1 \
            libxfixes3 libxkbcommon0 libxrandr2 libxshmfence1 libxss1 libxtst6 \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Run MagicMirror without root inside the container.
USER node

# Document the server port; Podman only exposes it on the host when run with --publish.
EXPOSE 8080
# The entrypoint uses MagicMirror's package script; the Podman runner enables --init for signal forwarding.
ENTRYPOINT ["container-entrypoint"]