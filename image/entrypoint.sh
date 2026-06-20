#!/bin/sh
# Entrypoint for the container-run hermes-box.
#  1. Create the box user from env (portable across accounts).
#  2. Start tailscaled (needs CAP_NET_ADMIN/CAP_NET_RAW from `container run`).
#  3. Run a passed command, else hold the container open.
# tailscaled restores its last `up` state — including Tailscale SSH — automatically
# when /var/lib/tailscale is a persisted volume, so restarts need no re-auth.
set -eu

BOX_USER="${BOX_USER:-hermes}"
BOX_UID="${BOX_UID:-1000}"
BOX_GID="${BOX_GID:-1000}"
BOX_HOME="/home/${BOX_USER}"

if ! id "${BOX_USER}" >/dev/null 2>&1; then
  if ! getent group "${BOX_GID}" >/dev/null 2>&1; then
    groupadd -g "${BOX_GID}" "${BOX_USER}"
  fi
  GRP="$(getent group "${BOX_GID}" | cut -d: -f1)"
  useradd -M -d "${BOX_HOME}" -u "${BOX_UID}" -g "${GRP}" -s /bin/bash "${BOX_USER}"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${BOX_USER}" > /etc/sudoers.d/"${BOX_USER}"
  chmod 0440 /etc/sudoers.d/"${BOX_USER}"
fi

mkdir -p /var/lib/tailscale /run/tailscale
tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/run/tailscale/tailscaled.sock \
  --port="${TS_PORT:-41641}" &

# Wait for the control socket so the `tailscale` CLI is usable right away.
i=0
while [ ! -S /run/tailscale/tailscaled.sock ] && [ "$i" -lt 50 ]; do
  sleep 0.1; i=$((i + 1))
done

if [ "$#" -gt 0 ]; then exec "$@"; else exec tail -f /dev/null; fi
