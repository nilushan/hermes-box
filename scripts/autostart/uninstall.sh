#!/usr/bin/env bash
# Remove the launchd autostart agent. Does NOT stop the running box.
source "$(dirname "$0")/../../lib/common.sh"

LABEL="${HERMES_BOX_AUTOSTART_LABEL:-local.${NAME}.boot}"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
rm -f "${PLIST}"
echo "Removed launchd agent '${LABEL}' (${PLIST})"
