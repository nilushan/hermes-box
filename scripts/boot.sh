#!/usr/bin/env bash
# Ensure the box is up. Idempotent — safe to run anytime. This is what the launchd
# autostart agent runs at login, and you can run it by hand too.
#   - already running  -> nothing
#   - exists, stopped  -> start it (reuses volumes + tailscale identity)
#   - does not exist   -> create it via 02-run.sh
source "$(dirname "$0")/../lib/common.sh"

echo "[boot] $(date) ensuring '${NAME}' is up"
container system start 2>/dev/null || true

if container inspect "${NAME}" >/dev/null 2>&1; then
  if container list 2>/dev/null | grep -E "(^|[[:space:]])${NAME}([[:space:]]|\$)" | grep -q running; then
    echo "[boot] '${NAME}' already running"
  else
    echo "[boot] starting existing '${NAME}'"
    container start "${NAME}"
  fi
else
  echo "[boot] '${NAME}' not found; creating"
  "$(dirname "$0")/02-run.sh"
fi
