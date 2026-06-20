#!/usr/bin/env bash
# Step 4 — bring up Tailscale with Tailscale SSH inside the box.
# This is the one interactive step: it prints a login URL and blocks until you
# authenticate the box into your tailnet in a browser.
source "$(dirname "$0")/lib.sh"

echo "Bringing up Tailscale inside ${MACHINE} with Tailscale SSH (--ssh)..."
echo "An authentication URL will be printed below."
echo "Open it in a browser and approve the machine. This command blocks until you do."
echo

container machine run -n "${MACHINE}" -- sudo tailscale up --ssh --hostname "${MACHINE}"

echo
echo "Tailscale is up. Box tailnet IPv4:"
container machine run -n "${MACHINE}" -- tailscale ip -4
