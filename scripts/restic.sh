#!/usr/bin/env bash
# Thin wrapper: run any restic command with the repo + R2 creds loaded from restic.env.
# Examples:
#   ./scripts/restic.sh snapshots
#   ./scripts/restic.sh ls latest
#   ./scripts/restic.sh ls latest /Users/.../hermes-box-data/hermes-home/wiki
#   ./scripts/restic.sh stats
#   ./scripts/restic.sh find self-hosting-setup.md
source "$(dirname "$0")/../lib/common.sh"

ENVF="${REPO_ROOT}/restic.env"
[ -f "${ENVF}" ] || { echo "missing ${ENVF} — run ./scripts/cf-r2-setup.sh first" >&2; exit 1; }
set -a; . "${ENVF}"; set +a
command -v restic >/dev/null 2>&1 || { echo "restic not installed (brew install restic)" >&2; exit 1; }

exec restic "$@"
