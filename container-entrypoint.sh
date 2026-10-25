#!/bin/sh
# Stop on errors and unset variables so startup fails clearly instead of continuing half-configured.
set -eu

# Seed a mounted config directory on its first run; preserve the user's config on later starts.
if [ ! -f /opt/magicmirror/config/config.js ]; then
    cp /opt/magicmirror/config.js.container /opt/magicmirror/config/config.js
fi

# Use MagicMirror's own entry points and keep stop signals flowing through Podman's --init.
case "${MM_MODE:-server}" in
    server)
        exec node --run server
        ;;
    electron)
        exec node --run start:wayland
        ;;
    client)
        : "${MM_SERVER_ADDRESS:?Set MM_SERVER_ADDRESS to a reachable MagicMirror server address}"
        MM_SERVER_PORT=${MM_SERVER_PORT:-8080}
        set -- clientonly --address "$MM_SERVER_ADDRESS" --port "$MM_SERVER_PORT"
        if [ "${MM_SERVER_TLS:-false}" = "true" ]; then
            set -- "$@" --use-tls
        fi
        exec node "$@"
        ;;
    *)
        printf 'Unsupported MM_MODE: %s\n' "$MM_MODE" >&2
        exit 1
        ;;
esac
