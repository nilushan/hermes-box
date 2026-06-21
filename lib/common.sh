#!/usr/bin/env bash
# Shared configuration for the hermes-box scripts. Sourced by every step.
# Everything is env-overridable with portable defaults — no hardcoded paths or
# usernames, so these run anywhere. Per-machine overrides go in .env.
set -euo pipefail

# Resolve repo layout from this file's location (lib/common.sh), so scripts work
# regardless of the directory they're invoked from.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LIB_DIR}/.." && pwd)"
IMAGE_DIR="${REPO_ROOT}/image"   # build context (Dockerfile + s6 service)

# Optional per-machine overrides (gitignored, at repo root). See .env.example.
if [ -f "${REPO_ROOT}/.env" ]; then set -a; . "${REPO_ROOT}/.env"; set +a; fi

IMAGE_TAG="${HERMES_BOX_IMAGE:-local/hermes-box:latest}"
NAME="${HERMES_BOX_NAME:-hermes-box}"
CPUS="${HERMES_BOX_CPUS:-4}"
MEMORY="${HERMES_BOX_MEMORY:-4G}"
TS_HOSTNAME="${HERMES_BOX_TS_HOSTNAME:-${NAME}}"
# Full tailnet FQDN (for Caddy TLS + tests). Empty = test.sh skips the HTTPS checks.
TS_FQDN="${HERMES_BOX_TS_FQDN:-}"

# SSH login user inside the box. The Hermes image ships a 'hermes' user (uid 501).
BOX_USER="${HERMES_BOX_USER:-hermes}"

# Hermes runtime settings (mirrors run-hermes.sh).
PUID="${HERMES_BOX_PUID:-$(id -u)}"
PGID="${HERMES_BOX_PGID:-$(id -g)}"
GATEWAY_PORT="${HERMES_BOX_GATEWAY_PORT:-9119}"
DASHBOARD_PORT="${HERMES_BOX_DASHBOARD_PORT:-8642}"

# Consolidated, backup-friendly data root. Host subdirs keep their original names,
# relocated under one root so it's one thing to back up/restore:
#   ${DATA_ROOT}/.hermes      -> /opt/data       (Hermes state, was ~/.hermes)
#   ${DATA_ROOT}/hermes-home  -> /home/nilushan  (work folder, was ~/AiInfra/hermes-home)
DATA_ROOT="${HERMES_BOX_DATA_ROOT:-${HOME}/AiInfra/hermes-box-data}"
HERMES_DATA_DIR="${DATA_ROOT}/.hermes"
HERMES_WORK_DIR="${DATA_ROOT}/hermes-home"

# Where local tar snapshots are written (kept OUTSIDE the data root).
BACKUP_DIR="${HERMES_BOX_BACKUP_DIR:-${HOME}/AiInfra/hermes-box-backups}"
# Regenerable paths excluded from backups (local tar + restic). Space-separated names.
BACKUP_EXCLUDES="${HERMES_BOX_BACKUP_EXCLUDES:-.cache .npm node_modules .playwright}"

# Persisted Tailscale identity. MUST be a named volume, not a host bind mount:
# tailscaled chmods its state dir to 0700, which virtiofs bind mounts reject
# ("state store unhealthy"). Re-authable, so it's excluded from data backups.
TS_STATE_VOLUME="${HERMES_BOX_STATE_VOLUME:-${NAME}-tsstate}"
