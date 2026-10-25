#!/bin/sh
set -eu

cd "$(dirname "$0")"

: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set; start this from a Wayland session}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set; start this from a Wayland session}"
: "${MM_SERVER_ADDRESS:?Set MM_SERVER_ADDRESS to a reachable MagicMirror server address}"

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

exec podman run --rm --init --name magicmirror-client \
    --userns=keep-id:uid=1000,gid=1000 \
    --env MM_MODE=client \
    --env MM_SERVER_ADDRESS \
    --env MM_SERVER_PORT="${MM_SERVER_PORT:-8080}" \
    --env MM_SERVER_TLS="${MM_SERVER_TLS:-false}" \
    --env XDG_RUNTIME_DIR=/run/user/1000 \
    --env WAYLAND_DISPLAY="$WAYLAND_SOCKET_NAME" \
    --volume "$WAYLAND_SOCKET:/run/user/1000/$WAYLAND_SOCKET_NAME:ro" \
    localhost/magicmirror-podman:develop-client