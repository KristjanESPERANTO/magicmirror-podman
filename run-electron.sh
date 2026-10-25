#!/bin/sh
set -eu

# Keep paths relative to this repository even when the script is called from elsewhere.
cd "$(dirname "$0")"

# Electron needs a Wayland socket from the active desktop session.
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set; start this from a Wayland session}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set; start this from a Wayland session}"

# WAYLAND_DISPLAY is usually a name, but it may also be an absolute socket path.
case "$WAYLAND_DISPLAY" in
    /*)
        WAYLAND_SOCKET="$WAYLAND_DISPLAY"
        WAYLAND_SOCKET_NAME=$(basename "$WAYLAND_DISPLAY")
        ;;
    *)
        WAYLAND_SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        WAYLAND_SOCKET_NAME="$WAYLAND_DISPLAY"
        ;;
esac

if [ ! -S "$WAYLAND_SOCKET" ]; then
    printf 'Wayland socket not found: %s\n' "$WAYLAND_SOCKET" >&2
    exit 1
fi

# Keep settings shared with server mode and bind only the display socket, not the whole session dir.
CONFIG_DIR="$HOME/.config/magicmirror-podman"
mkdir -p "$CONFIG_DIR"

# --init forwards stop signals; keep-id maps the container's node user to this desktop user.
exec podman run --rm --init --name magicmirror-electron \
    --userns=keep-id:uid=1000,gid=1000 \
    --env MM_MODE=electron \
    --env XDG_RUNTIME_DIR=/run/user/1000 \
    --env WAYLAND_DISPLAY="$WAYLAND_SOCKET_NAME" \
    --volume "$WAYLAND_SOCKET:/run/user/1000/$WAYLAND_SOCKET_NAME:ro" \
    --volume "$CONFIG_DIR:/opt/magicmirror/config:Z" \
    localhost/magicmirror-podman:develop-electron