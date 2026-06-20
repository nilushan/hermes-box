#!/usr/bin/env bash
# Install a launchd LaunchAgent that runs scripts/boot.sh at login, so the box
# auto-starts after a Mac reboot. Per-user agent (Apple `container` is user-scoped).
# Idempotent: re-running rewrites and reloads the agent.
source "$(dirname "$0")/../lib/common.sh"

LABEL="${HERMES_BOX_AUTOSTART_LABEL:-local.${NAME}.boot}"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
BOOT="${REPO_ROOT}/scripts/boot.sh"
LOG="${REPO_ROOT}/autostart.log"
DOMAIN="gui/$(id -u)"

mkdir -p "${HOME}/Library/LaunchAgents"
cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${BOOT}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${LOG}</string>
  <key>StandardErrorPath</key><string>${LOG}</string>
</dict>
</plist>
EOF

# Reload cleanly (bootout is harmless if not loaded).
launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${PLIST}"
launchctl enable "${DOMAIN}/${LABEL}"

echo "Installed launchd agent '${LABEL}'"
echo "  plist: ${PLIST}"
echo "  log  : ${LOG}"
launchctl print "${DOMAIN}/${LABEL}" >/dev/null 2>&1 && echo "  status: loaded"
