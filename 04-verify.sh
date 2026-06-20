#!/usr/bin/env bash
# Step 6 — verify: confirm Tailscale status in the box, then SSH in from the Mac
# entirely over the tailnet (MagicDNS hostname).
source "$(dirname "$0")/lib.sh"

echo "=== Tailscale status inside the box ==="
container machine run -n "${MACHINE}" -- tailscale status

echo
echo "=== Box tailnet IPv4 ==="
container machine run -n "${MACHINE}" -- tailscale ip -4

echo
echo "=== SSH from the Mac over the tailnet (${BOX_USER}@${MACHINE}) ==="
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
    "${BOX_USER}@${MACHINE}" \
    'echo "CONNECTED as $(whoami) on $(hostname)"; uname -srm'
