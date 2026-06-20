#!/usr/bin/env bash
# Step 3 — bring up Tailscale SSH inside the box (interactive auth on first run).
# Prints a login URL; open it to authorize the box. State is persisted in the
# mounted volume, so subsequent restarts reconnect automatically (no re-auth).
source "$(dirname "$0")/lib.sh"

echo "Bringing up Tailscale SSH inside '${NAME}' as hostname '${TS_HOSTNAME}'..."
echo "Open the printed login URL to authorize the box. This blocks until you do."
echo
container exec "${NAME}" tailscale up --ssh --hostname "${TS_HOSTNAME}"

echo
echo "Tailscale IPv4:"
container exec "${NAME}" tailscale ip -4
