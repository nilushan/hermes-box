#!/usr/bin/env bash
# Step 2 — run the box: the Hermes gateway + Tailscale in one container.
# Real --volume bind mounts for the data root; --cap-add lets tailscaled make its
# TUN; tailscale state in a named volume. Mirrors run-hermes.sh + Tailscale.
source "$(dirname "$0")/../lib/common.sh"

mkdir -p "${HERMES_DATA_DIR}" "${HERMES_WORK_DIR}"
container volume inspect "${TS_STATE_VOLUME}" >/dev/null 2>&1 || container volume create "${TS_STATE_VOLUME}" >/dev/null

echo "Removing any existing '${NAME}'..."
container rm -f "${NAME}" 2>/dev/null || true

echo "Running '${NAME}' (Hermes gateway + Tailscale):"
echo "  data : ${HERMES_DATA_DIR}  ->  /opt/data"
echo "  work : ${HERMES_WORK_DIR}  ->  ${WORK_MOUNT}"
echo "  ts   : volume ${TS_STATE_VOLUME}  ->  /var/lib/tailscale"
echo "  ports: ${GATEWAY_PORT}->9119 (gateway), ${DASHBOARD_PORT}->8642 (dashboard)"
container run -d --name "${NAME}" \
  --cpus "${CPUS}" --memory "${MEMORY}" \
  --cap-add CAP_NET_ADMIN --cap-add CAP_NET_RAW \
  --env PUID="${PUID}" --env PGID="${PGID}" \
  --env HERMES_DASHBOARD=1 --env HERMES_DASHBOARD_INSECURE=1 \
  --publish "${GATEWAY_PORT}:9119" \
  --publish "${DASHBOARD_PORT}:8642" \
  --volume "${HERMES_DATA_DIR}:/opt/data" \
  --volume "${HERMES_WORK_DIR}:${WORK_MOUNT}" \
  --env HERMES_BOX_WIKI_ROOT="${WORK_MOUNT}/wiki-site/_site" \
  --volume "${TS_STATE_VOLUME}:/var/lib/tailscale" \
  "${IMAGE_TAG}" gateway run

container list | grep -E "ID|${NAME}" || container list
