#!/usr/bin/env bash
# One-time migration: consolidate existing Hermes data under the data root, keeping
# the original folder names (.hermes, hermes-home). Idempotent — skips a move if the
# source is gone or the destination already exists. STOP the box/old container first
# so the files aren't in use. Old locations overridable for portability.
source "$(dirname "$0")/../lib/common.sh"

OLD_DATA="${HERMES_BOX_OLD_DATA:-${HOME}/.hermes}"
OLD_WORK="${HERMES_BOX_OLD_WORK:-${HOME}/AiInfra/hermes-home}"

mkdir -p "${DATA_ROOT}"

move() {
  local src="$1" dst="$2"
  if [ -e "${dst}" ]; then echo "skip: ${dst} already exists"; return 0; fi
  if [ ! -e "${src}" ]; then echo "skip: ${src} not found"; return 0; fi
  echo "moving ${src} -> ${dst}"
  mv "${src}" "${dst}"
}

move "${OLD_DATA}" "${HERMES_DATA_DIR}"
move "${OLD_WORK}" "${HERMES_WORK_DIR}"

# Drop Pi-era Tailscale leftovers imported into the Hermes data dir (unused here).
rm -rf "${HERMES_DATA_DIR}/.tailscale" \
       "${HERMES_DATA_DIR}/.local/bin/tailscale" \
       "${HERMES_DATA_DIR}/.local/bin/tailscaled" 2>/dev/null || true

echo "Data root: ${DATA_ROOT}"
ls -la "${DATA_ROOT}" 2>/dev/null
