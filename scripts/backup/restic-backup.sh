#!/usr/bin/env bash
# Offsite backup of the data root to restic/Cloudflare R2 (encrypted, versioned).
# Runs on the Mac (the data lives on the host). Inits the repo on first run, backs up,
# then prunes per the retention policy. Reads credentials from restic.env (gitignored).
source "$(dirname "$0")/../../lib/common.sh"

ENVF="${REPO_ROOT}/restic.env"
[ -f "${ENVF}" ] || { echo "missing ${ENVF} — cp restic.env.example restic.env and fill it" >&2; exit 1; }
set -a; . "${ENVF}"; set +a
command -v restic >/dev/null 2>&1 || { echo "restic not installed (brew install restic)" >&2; exit 1; }
[ -d "${DATA_ROOT}" ] || { echo "no data root at ${DATA_ROOT}" >&2; exit 1; }

# Initialize the repo if it doesn't exist yet.
if ! restic cat config >/dev/null 2>&1; then
  echo "Initializing restic repo at ${RESTIC_REPOSITORY} ..."
  restic init
fi

ex=""; for e in ${BACKUP_EXCLUDES}; do ex="${ex} --exclude=${e}"; done
echo "Backing up ${DATA_ROOT} (excluding: ${BACKUP_EXCLUDES})"
# shellcheck disable=SC2086
restic backup "${DATA_ROOT}" ${ex} --tag hermes-box --host "${NAME}"

# Retention: keep recent dailies/weeklies/monthlies, prune the rest.
restic forget --tag hermes-box \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

echo "=== latest snapshots ==="
restic snapshots --tag hermes-box --latest 5
