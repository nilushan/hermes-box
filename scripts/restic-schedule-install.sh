#!/usr/bin/env bash
# Install a launchd agent that runs scripts/restic-backup.sh daily (offsite backup to R2).
# Per-user agent; runs at HERMES_BOX_RESTIC_HOUR (default 03:00). Idempotent.
source "$(dirname "$0")/../lib/common.sh"

LABEL="${HERMES_BOX_RESTIC_LABEL:-local.${NAME}.restic}"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
SCRIPT="${REPO_ROOT}/scripts/restic-backup.sh"
LOG="${REPO_ROOT}/restic-backup.log"
HOUR="${HERMES_BOX_RESTIC_HOUR:-3}"
DOMAIN="gui/$(id -u)"

[ -f "${REPO_ROOT}/restic.env" ] || { echo "restic.env missing — run ./scripts/cf-r2-setup.sh first" >&2; exit 1; }
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
    <string>${SCRIPT}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>${HOUR}</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>${LOG}</string>
  <key>StandardErrorPath</key><string>${LOG}</string>
</dict>
</plist>
EOF

launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${PLIST}"
launchctl enable "${DOMAIN}/${LABEL}"
echo "Installed '${LABEL}' — daily restic backup at ${HOUR}:00. Log: ${LOG}"
echo "Run now to test: launchctl kickstart ${DOMAIN}/${LABEL}"
