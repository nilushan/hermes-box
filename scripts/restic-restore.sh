#!/usr/bin/env bash
# Restore from restic/R2. Usage: restic-restore.sh [snapshot] [target]
#   snapshot: snapshot id, or 'latest' (default)
#   target:   restore destination (default: ~/hermes-box-restore) — NOT the live data
#             root, so you can review before swapping in.
source "$(dirname "$0")/../lib/common.sh"

ENVF="${REPO_ROOT}/restic.env"
[ -f "${ENVF}" ] || { echo "missing ${ENVF}" >&2; exit 1; }
set -a; . "${ENVF}"; set +a
command -v restic >/dev/null 2>&1 || { echo "restic not installed" >&2; exit 1; }

SNAP="${1:-latest}"
TARGET="${2:-${HOME}/hermes-box-restore}"
mkdir -p "${TARGET}"

echo "Restoring snapshot '${SNAP}' -> ${TARGET}"
restic restore "${SNAP}" --target "${TARGET}"
# restic preserves absolute paths, so data lands under ${TARGET}${DATA_ROOT}.
echo "Done. Restored data is at: ${TARGET}${DATA_ROOT}"
echo "To put it live: container rm -f ${NAME}; replace ${DATA_ROOT} with the restored copy; ./scripts/02-run.sh"
