#!/usr/bin/env bash
# Shared configuration for the hermes-box scripts. Sourced by every step.
# Everything is env-overridable with portable defaults derived from the current
# user/host — no hardcoded paths or usernames, so these run anywhere.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional per-machine overrides (gitignored). See .env.example.
if [ -f "${SCRIPT_DIR}/.env" ]; then set -a; . "${SCRIPT_DIR}/.env"; set +a; fi

IMAGE_TAG="${HERMES_BOX_IMAGE:-local/hermes-box:latest}"
NAME="${HERMES_BOX_NAME:-hermes-box}"
CPUS="${HERMES_BOX_CPUS:-4}"
MEMORY="${HERMES_BOX_MEMORY:-4G}"
TS_HOSTNAME="${HERMES_BOX_TS_HOSTNAME:-${NAME}}"

# Box user inside the container (defaults to the user running these scripts so
# bind-mounted files line up by owner).
BOX_USER="${HERMES_BOX_USER:-$(id -un)}"
BOX_UID="${HERMES_BOX_UID:-$(id -u)}"
BOX_GID="${HERMES_BOX_GID:-$(id -g)}"

# Host folder bind-mounted as the box user's home.
HERMES_HOME="${HERMES_BOX_HOME:-${HOME}/hermes-home}"
# Persisted Tailscale identity (so restarts/recreates don't re-auth). This MUST be a
# named volume, not a host bind mount: tailscaled chmods its state dir to 0700, which
# virtiofs bind mounts reject ("state store unhealthy"). Named volumes are block-backed.
TS_STATE_VOLUME="${HERMES_BOX_STATE_VOLUME:-${NAME}-tsstate}"
