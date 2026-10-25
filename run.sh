#!/bin/sh
set -eu

# Keep paths relative to this repository even when this script is called from elsewhere.
cd "$(dirname "$0")"

# Store settings outside the repository so they survive image rebuilds and work with Quadlet too.
CONFIG_DIR="$HOME/.config/magicmirror-podman"
mkdir -p "$CONFIG_DIR"

# Preserve a config created by earlier versions of this script, but never overwrite user settings.
if [ -f "$PWD/config/config.js" ] && [ ! -f "$CONFIG_DIR/config.js" ]; then
    cp "$PWD/config/config.js" "$CONFIG_DIR/config.js"
fi

# Keep the server local by default; set MM_BIND_ADDRESS to a host interface for LAN clients.
MM_BIND_ADDRESS=${MM_BIND_ADDRESS:-127.0.0.1}

# Podman's init process forwards stop signals to the child started by `node --run server`.
exec podman run --rm --init --name magicmirror \
    --userns=keep-id:uid=1000,gid=1000 \
    --publish "$MM_BIND_ADDRESS:8080:8080" \
    --volume "$CONFIG_DIR:/opt/magicmirror/config:Z" \
    localhost/magicmirror-podman:develop