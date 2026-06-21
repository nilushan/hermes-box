#!/usr/bin/env bash
# List restic snapshots (and repo stats). Reads restic.env.
source "$(dirname "$0")/../lib/common.sh"
ENVF="${REPO_ROOT}/restic.env"
[ -f "${ENVF}" ] || { echo "missing ${ENVF}" >&2; exit 1; }
set -a; . "${ENVF}"; set +a

restic snapshots --tag hermes-box
echo "=== repo stats ==="
restic stats --mode raw-data 2>/dev/null || true
