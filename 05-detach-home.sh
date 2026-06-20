#!/usr/bin/env bash
# Detach the Mac home from the box: set home-mount=none so /Users/<you> is NOT
# visible inside the machine. `container machine` cannot bind-mount an arbitrary
# host folder (only ro/rw/none of the Mac home), so the box uses its own internal
# /home/<user> in the rootfs, which persists across restarts.
source "$(dirname "$0")/lib.sh"

echo "Setting home-mount=none on ${MACHINE}..."
container machine set -n "${MACHINE}" home-mount=none

echo "Restarting machine to apply (no 'start' subcommand; 'run' boots it)..."
container machine stop "${MACHINE}"
container machine run -n "${MACHINE}" -- true

echo
echo "=== verify over tailnet: /Users must NOT be mounted ==="
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "${BOX_USER}@${MACHINE}" \
  'echo "mounts referencing /Users:"; mount | grep /Users && echo "  STILL MOUNTED (!!)" || echo "  (none) — detached ✓"; echo "HOME=$HOME"; echo "home contents:"; ls -la ~'
