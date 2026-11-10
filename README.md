# awg-vpn

An AmneziaWG client in a Docker container. The tunnel lives inside the container, so the host
network and any other VPN on the host stay untouched. Other containers can use the tunnel by
joining the network of this one, and a list of destinations can bypass the tunnel
(see "Bypass list").

## Layout

```
vpn/
├── docker-compose.yml   # the AmneziaWG client container (awg-vpn)
├── bypass/
│   ├── apply.sh         # adds the direct routes (runs inside the container)
│   ├── hook.cfg         # hook-only interface config that starts apply.sh
│   ├── list.example     # example of the list
│   └── list             # your list (not tracked by git)
├── .gitignore
├── README.md
└── wg0-sg.conf          # your VPN config(s), *.conf (not tracked by git: private keys)
```

## Quick start

1. `git clone <repository url> vpn && cd vpn`
2. Download the config of your VPN into this folder, save it with a name ending in `.conf`
   and restrict access: `chmod 600 wg0-sg.conf`.
   For Amnezia Premium: personal dashboard, Connection Assets, Configuration Files, pick a
   location and download the file.
3. In `docker-compose.yml` the first line under `volumes:` must point to that file:
   `- ./wg0-sg.conf:/etc/amnezia/amneziawg/wg0.conf:ro`
4. Optional, direct access for some destinations: `cp bypass/list.example bypass/list` and edit it.
5. `docker compose up -d`

Check that the tunnel is up:

```
docker exec awg-vpn awg show wg0 | grep -E 'latest handshake|transfer'
docker run --rm --network container:awg-vpn curlimages/curl -s https://ipinfo.io
```

The first command shows a recent handshake and growing counters, the second shows the address
and country of the VPN server.

## What the compose file does

| Setting | Purpose |
|---|---|
| `./wg0-sg.conf` to `/etc/amnezia/amneziawg/wg0.conf` (read-only) | The tunnel config. The file name inside the container is the interface name (`wg0`). |
| `./bypass` to `/bypass` (read-only) | The bypass script and your list. |
| `./bypass/hook.cfg` to `/etc/amnezia/amneziawg/bypass.conf` (read-only) | The hook that starts the bypass script (see below). |
| `/dev/net/tun` | The tunnel runs in userspace and needs the TUN device. |
| `NET_ADMIN` | Creates the interface and routes, only inside this container. |
| `net.ipv4.conf.all.src_valid_mark=1` | Needed for a full tunnel (`AllowedIPs = 0.0.0.0/0`). |

## Switching the config

Change the file name in the first `volumes:` line of `docker-compose.yml` (for example to
`./wg0-de.conf`) and run `docker compose up -d`. The container is recreated, so the containers
that use its network must be recreated too (see "Using the tunnel from other containers").

## Amnezia Premium notes

- A configuration file for a location can only be used on one device at a time. Using the same
  file in several places breaks the connection everywhere.
- Use a different location in the Amnezia app on other devices.
- Each generated configuration file takes one of the active connection slots of the subscription.
- A VPN running on the host: with the Amnezia app on the host in the AmneziaWG mode everything
  worked next to this container. With the VLESS mode the packets of this tunnel went inside the
  host VPN (checked with `ip route get <server address>`) and the connection was unstable.

## Bypass list (direct access without the VPN)

Destinations listed in `bypass/list` are reached directly instead of through the tunnel.
"Directly" means through the normal network of the container, so from there on the network
rules of the host apply (including a VPN running on the host).

1. `cp bypass/list.example bypass/list` and edit it. The file is not tracked by git.
2. `docker compose up -d`. To apply later changes without restarting the container:
   `docker exec awg-vpn /bypass/apply.sh`.

One entry per line, `#` starts a comment. An entry is an IPv4 address, an IPv4 network (CIDR)
or a public host name. A host name is resolved to its IPv4 addresses each time the script runs,
so it only works while the addresses of the service stay the same (it is not reliable behind a CDN).
There are no wildcards. IPv6 and names that resolve only inside a private network are not supported.

Check what was added: `docker exec awg-vpn ip route show`.
