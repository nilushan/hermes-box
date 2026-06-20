#!/usr/bin/env bash
# Restore the data root from a snapshot. Usage: restore.sh [archive]
# No arg = most recent snapshot in BACKUP_DIR. The box must be stopped first so the
# files aren't in use. The current data root is moved aside to *.pre-restore-<ts>
# before extracting, so a bad restore is recoverable.
source "$(dirname "$0")/../lib/common.sh"

archive="${1:-$(ls -1t "${BACKUP_DIR}"/hermes-box-data-*.tar.gz 2>/dev/null | head -1)}"
[ -n "${archive}" ] && [ -f "${archive}" ] || { echo "no archive found (looked in ${BACKUP_DIR})" >&2; exit 1; }

if container list 2>/dev/null | grep -E "(^|[[:space:]])${NAME}([[:space:]]|\$)" | grep -q running; then
  echo "Refusing to restore while '${NAME}' is running. Stop it first: container rm -f ${NAME}" >&2
  exit 1
fi

parent="$(dirname "${DATA_ROOT}")"; base="$(basename "${DATA_ROOT}")"
mkdir -p "${parent}"
if [ -e "${DATA_ROOT}" ]; then
  aside="${DATA_ROOT}.pre-restore-$(date +%Y%m%d-%H%M%S)"
  echo "Moving current data root aside -> ${aside}"
  mv "${DATA_ROOT}" "${aside}"
fi

echo "Restoring ${archive} -> ${DATA_ROOT}"
tar -C "${parent}" -xzf "${archive}"
echo "Restored. Data root:"; ls -la "${DATA_ROOT}"
echo "Next: ./scripts/02-run.sh"
