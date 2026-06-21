#!/usr/bin/env bash
# Remove the daily restic-backup launchd agent.
source "$(dirname "$0")/../lib/common.sh"
LABEL="${HERMES_BOX_RESTIC_LABEL:-local.${NAME}.restic}"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
rm -f "${PLIST}"
echo "Removed '${LABEL}' (${PLIST})"
