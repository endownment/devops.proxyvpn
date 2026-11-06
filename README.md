# awg-vpn

An AmneziaWG client in a Docker container. The tunnel lives inside the container, so the host
network and any other VPN on the host stay untouched. Other containers can use the tunnel by
joining the network of this one (`network_mode: "container:awg-vpn"`).

## Layout

```
vpn/
├── docker-compose.yml   # the AmneziaWG client container (awg-vpn)
├── .gitignore
├── README.md
└── /                    # your *.conf files (contents not tracked: they hold private keys)
```

## Quick start

1. `git clone <repository url> vpn && cd vpn`
2. Put your VPN config file(s) into `/` and restrict access: `chmod 600 *.conf`.
   For Amnezia Premium: personal dashboard, Connection Assets, Configuration Files, pick a
   location and download the file.
3. `docker compose up -d`

Check that the tunnel is up:

```
docker exec awg-vpn awg show wg0 | grep -E 'latest handshake|transfer'
docker run --rm --network container:awg-vpn curlimages/curl -s https://ipinfo.io
```

The first command shows a recent handshake and growing counters, the second shows the address
and country of the VPN server.

## Switching the config

Run `docker compose up -d`. The container is recreated.
Containers that use this network lose it and must be restarted (see below).

## Amnezia Premium notes

- A configuration file for a location can only be used on one device at a time. Using the same
  file in several places breaks the connection everywhere.
- Use a different location in the Amnezia app on other devices.
- Each generated configuration file takes one of the active connection slots of the subscription.

## Using the tunnel from other containers

In the other project add to the service:

```
network_mode: "container:awg-vpn"
```

This container must be running first. When it is recreated or restarted, the dependent
containers lose the network: restart them (for example `docker compose restart` in their folder).
`ports` and `networks` cannot be combined with `network_mode: container:...`.

## Troubleshooting

- No handshake and `received` stays at 0 in `awg show wg0`: check that the same config file is
  not used on another device.
- Log lines about `resolvconf` and "could not detect a useable init system" are harmless.

## Security

- The config files contain private keys: keep them out of git and keep `chmod 600` on them.
- The image is a community build (`vernette/amneziawg`). It runs with `NET_ADMIN` and the TUN
  device, but only inside this container's own network namespace.
