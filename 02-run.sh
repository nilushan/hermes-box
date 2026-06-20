#!/usr/bin/env bash
# Step 2 — run the box with `container run`: real --volume bind mounts, plus the
# capabilities Tailscale needs to create its TUN interface. Replaces the old
# `container machine create` (which could not bind-mount arbitrary folders).
source "$(dirname "$0")/lib.sh"

mkdir -p "${HERMES_HOME}"
container volume inspect "${TS_STATE_VOLUME}" >/dev/null 2>&1 || container volume create "${TS_STATE_VOLUME}" >/dev/null

echo "Removing any existing '${NAME}'..."
container rm -f "${NAME}" 2>/dev/null || true

echo "Running '${NAME}':"
echo "  user   : ${BOX_USER} (uid ${BOX_UID}, gid ${BOX_GID})"
echo "  home   : ${HERMES_HOME}  ->  /home/${BOX_USER}  (real bind mount)"
echo "  tsstate: volume ${TS_STATE_VOLUME}  ->  /var/lib/tailscale"
container run -d --name "${NAME}" \
  --cpus "${CPUS}" --memory "${MEMORY}" \
  --cap-add CAP_NET_ADMIN --cap-add CAP_NET_RAW \
  --env BOX_USER="${BOX_USER}" \
  --env BOX_UID="${BOX_UID}" \
  --env BOX_GID="${BOX_GID}" \
  --volume "${TS_STATE_VOLUME}:/var/lib/tailscale" \
  --volume "${HERMES_HOME}:/home/${BOX_USER}" \
  "${IMAGE_TAG}"

container list | grep -E "ID|${NAME}" || container list
