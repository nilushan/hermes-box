#!/usr/bin/env bash
# Step 4 — verify: Tailscale status, SSH in from the Mac over the tailnet, and
# prove the --volume mount is a real bidirectional bind mount (no sync involved).
source "$(dirname "$0")/lib.sh"

echo "=== tailscale status (in box) ==="
container exec "${NAME}" tailscale status

echo
echo "=== box tailnet IPv4 ==="
container exec "${NAME}" tailscale ip -4

echo
echo "=== SSH from the Mac over the tailnet (${BOX_USER}@${TS_HOSTNAME}) ==="
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
    "${BOX_USER}@${TS_HOSTNAME}" \
    'echo "CONNECTED as $(whoami) on $(hostname)"; echo "HOME=$HOME"; ls -A ~ | head'

echo
echo "=== prove real bidirectional volume mount ==="
STAMP="vol-proof-$$"
echo "written on the Mac" > "${HERMES_HOME}/${STAMP}"
echo "-- box reads the Mac's file: --"
container exec "${NAME}" sh -c "cat /home/${BOX_USER}/${STAMP}"
container exec "${NAME}" sh -c "echo 'appended in the box' >> /home/${BOX_USER}/${STAMP}"
echo "-- Mac reads the box's append: --"
cat "${HERMES_HOME}/${STAMP}"
rm -f "${HERMES_HOME}/${STAMP}"
echo "(test file removed)"
