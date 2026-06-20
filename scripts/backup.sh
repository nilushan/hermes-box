#!/usr/bin/env bash
# Create a restorable, timestamped snapshot of the data root (.hermes + hermes-home)
# as a gzip tarball in BACKUP_DIR (kept OUTSIDE the data root). The Tailscale identity
# (named volume) is intentionally NOT included — it's re-authable. restic->Cloudflare
# R2 is the planned offsite/versioned follow-up.
source "$(dirname "$0")/../lib/common.sh"

[ -d "${DATA_ROOT}" ] || { echo "no data root at ${DATA_ROOT}" >&2; exit 1; }
ts="${1:-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "${BACKUP_DIR}"
archive="${BACKUP_DIR}/hermes-box-data-${ts}.tar.gz"

# Skip regenerable caches to keep snapshots lean (override with HERMES_BOX_BACKUP_EXCLUDES).
: "${HERMES_BOX_BACKUP_EXCLUDES:=.cache .npm node_modules .playwright}"
ex=""; for e in ${HERMES_BOX_BACKUP_EXCLUDES}; do ex="${ex} --exclude=${e}"; done

echo "Backing up ${DATA_ROOT} -> ${archive}"
echo "  excluding: ${HERMES_BOX_BACKUP_EXCLUDES}"
# shellcheck disable=SC2086
tar -C "$(dirname "${DATA_ROOT}")" ${ex} -czf "${archive}" "$(basename "${DATA_ROOT}")"
echo "Done: $(du -h "${archive}" | cut -f1)  ${archive}"
echo "Recent snapshots:"
ls -1t "${BACKUP_DIR}"/hermes-box-data-*.tar.gz 2>/dev/null | head -5
