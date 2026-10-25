# MagicMirror² for Podman

A small project to learn Podman by running [MagicMirror²](https://github.com/MagicMirrorOrg/MagicMirror) in a container.

> [!WARNING]
> **This entire project is experimental.** The server, Quadlet, and Wayland desktop modes are for learning and testing, not production use. They are not security-hardened or guaranteed to be reliable; configuration, behavior, and image details may change or break without notice.

This project is an independent work in progress focused on gaining experience with Podman. The existing [MagicMirror Docker project](https://gitlab.com/khassel/magicmirror) may be a better approach if you don't like to experiment. If you try this project, feedback and suggestions are very welcome.

## Plans

Server mode is the foundation; the current development focus is **Wayland-only Electron**. **Client** mode is experimental and has not been tested extensively. If the project grows into something suitable for general use, a stable-release option may follow.

## Run with systemd

The Quadlet unit uses the same image and settings directory as `run.sh`:

Build the image first:

```sh
podman build -t localhost/magicmirror-podman:develop .
```

Then install and start the user service:

```sh
mkdir -p ~/.config/containers/systemd
ln -s "$PWD/quadlet/magicmirror.container" ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start magicmirror.service
```

### Configuration

The active config is `~/.config/magicmirror-podman/config.js` on the host. Both `run.sh` and the Quadlet unit mount this directory into the container. Edit this host file to change MagicMirror settings; the repository's `config.js` is only the starter config copied on first start.

### Remote clients

The server is published on `127.0.0.1` by default. To allow clients on the LAN, bind it to the server machine's LAN address instead:

```sh
MM_BIND_ADDRESS=192.168.1.10 sh ./run.sh
```

For Quadlet, change `PublishPort=127.0.0.1:8080:8080` in `quadlet/magicmirror.container` to `PublishPort=192.168.1.10:8080:8080`, then run `systemctl --user daemon-reload` and restart the service. Use an address assigned to the server's LAN interface, and allow port 8080 only from trusted clients in the host firewall. Avoid `0.0.0.0` unless exposing the service on every host interface is intentional.

> [!CAUTION]
> MagicMirror has no built-in user authentication, and the sample `ipWhitelist: []` allows connections from any IP that can reach the server. A LAN bind is not access control. Restrict access with the host firewall and a suitable `ipWhitelist`; do not expose this service directly to the internet. HTTP traffic is unencrypted unless HTTPS is configured on the server.

### Autostart

Quadlet applies the unit's `[Install]` section automatically. Because the service is generated, do not run `systemctl --user enable`; `systemctl --user is-enabled magicmirror.service` reports `generated` when Quadlet has added it to `default.target`.

The service starts when your user systemd manager starts, usually when you log in. To have the user manager start at system boot before you log in, enable lingering:

```sh
loginctl enable-linger "$USER"
```

Lingering remains enabled until disabled with `loginctl disable-linger "$USER"`. To stop the service starting with your user manager, remove `WantedBy=default.target` from `quadlet/magicmirror.container` and run `systemctl --user daemon-reload`.

## Troubleshooting

List running containers:

```sh
podman ps
```

Include stopped containers too:

```sh
podman ps -a
```

## Electron on Wayland

Build the experimental Electron image:

```sh
podman build --build-arg MM_MODE=electron -t localhost/magicmirror-podman:develop-electron .
```

To start it manually from an active Wayland session:

```sh
sh ./run-electron.sh
```

This passes only the Wayland display socket into the container. X11 is not supported by this setup.

### Run as a user service

Install and start the Electron Quadlet from an active Wayland session:

```sh
mkdir -p ~/.config/containers/systemd
ln -s "$PWD/quadlet/magicmirror-electron.container" ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start magicmirror-electron.service
```

The unit is tied to `graphical-session.target`, starts with graphical sessions, and stops with that target. Quadlet applies `WantedBy=graphical-session.target` automatically; do not enable this generated unit manually. The unit currently expects the standard `wayland-0` socket; adjust `WAYLAND_DISPLAY` and the socket volume in `quadlet/magicmirror-electron.container` if your compositor uses another name.

## Client on Wayland

Client mode is experimental and has not been tested extensively.

The client image runs MagicMirror's client-only Electron viewer and connects to a separate, reachable MagicMirror server. Set the server address before building and starting it:

```sh
export MM_SERVER_ADDRESS=192.168.1.20
export MM_SERVER_PORT=8080
podman build --build-arg MM_MODE=client -t localhost/magicmirror-podman:develop-client .
sh ./run-client.sh
```

The bundled server runner and Quadlet bind only to `127.0.0.1` by default. Configure the server's LAN binding as described above before connecting remote clients.

For an HTTPS server, also set `MM_SERVER_TLS=true` and use its HTTPS port. The address must be reachable from the container and must not be `localhost`; X11 is not supported.
