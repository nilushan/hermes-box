#!/usr/bin/env bash
# Step 2 — create + boot the machine, sized explicitly, with home mounted read-only.
source "$(dirname "$0")/lib.sh"

if container machine list | awk 'NR>1{print $1}' | grep -qx "${MACHINE}"; then
  echo "Machine ${MACHINE} already exists:"
  container machine list
  exit 0
fi

echo "Creating machine ${MACHINE} (cpus=${CPUS} memory=${MEMORY} home-mount=${HOME_MOUNT})..."
container machine create "${IMAGE_TAG}" \
  --name "${MACHINE}" \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  --home-mount "${HOME_MOUNT}" \
  --set-default

container machine list
