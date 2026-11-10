#!/bin/sh
# Adds routes that bypass the VPN for the destinations listed in /bypass/list.
#
# It runs inside the awg-vpn container, either as a PostUp hook of the AmneziaWG
# config or by hand:   docker exec awg-vpn /bypass/apply.sh
# Set DRY_RUN=1 to print the commands instead of running them:
#   docker exec -e DRY_RUN=1 awg-vpn /bypass/apply.sh
#
# The script never exits with an error: a failing PostUp hook would bring the tunnel down.

LIST="/bypass/list"
IPV4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'

if [ ! -f "$LIST" ]; then
  echo "bypass: $LIST not found, nothing to do"
  exit 0
fi

# Gateway and device of the normal (non-VPN) network of the container.
route_info="$(ip -4 route show default | awk '/^default/ {
  for (i = 1; i < NF; i++) { if ($i == "via") gw = $(i + 1); if ($i == "dev") dev = $(i + 1) }
  print gw, dev; exit }')"
GW="${route_info%% *}"
DEV="${route_info##* }"
if [ -z "$GW" ] || [ -z "$DEV" ]; then
  echo "bypass: no default route with a gateway found, nothing to do" >&2
  exit 0
fi

add_route() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "ip route replace $1 via $GW dev $DEV"
  elif ip route replace "$1" via "$GW" dev "$DEV"; then
    echo "bypass: $1"
  else
    echo "bypass: could not add $1" >&2
  fi
}

resolve() {
  ips="$(getent ahostsv4 "$1" 2>/dev/null </dev/null | awk '{ print $1 }' | grep -E "$IPV4" | sort -u)"
  if [ -z "$ips" ]; then
    ips="$(nslookup "$1" 2>/dev/null </dev/null \
      | awk '/^Name:/ { seen = 1; next } seen && /^Address/ { print $NF }' | grep -E "$IPV4" | sort -u)"
  fi
  echo "$ips"
}

tr -d '\r' < "$LIST" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  case "$entry" in
    *[!0-9./]*)
      # a host name: route every IPv4 address it resolves to
      ips="$(resolve "$entry")"
      if [ -z "$ips" ]; then
        echo "bypass: $entry did not resolve to an IPv4 address" >&2
        continue
      fi
      for ip in $ips; do add_route "$ip/32"; done
      ;;
    *)
      # an IPv4 address or network
      add_route "$entry"
      ;;
  esac
done

exit 0
