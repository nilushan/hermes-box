#!/usr/bin/env bash
# Verify Claude Code (subscription) in the box. Claude is baked into the image
# (/usr/local/bin/claude); a data-dir copy (/opt/data/.local/bin/claude) shadows it via
# PATH if present — both fine. The OAuth login lives in /opt/data/.claude (persistent
# volume), so it survives recreates and is in the restic backup (creds encrypted).
#
# Authentication is your interactive Claude subscription login (cannot be scripted):
#   container exec -it --user hermes hermes-box sh -lc 'export HOME=/opt/data; claude'
source "$(dirname "$0")/../lib/common.sh"

BOX_HOME=/opt/data
run_user() { container exec --user "${BOX_USER}" "${NAME}" sh -lc "export HOME=${BOX_HOME}; $1"; }

CLAUDE="$(run_user 'command -v claude' 2>/dev/null | tr -d '\r')"
if [ -z "${CLAUDE}" ]; then
  echo "claude not found in '${NAME}'. It's baked into the image — rebuild + run:" >&2
  echo "  ./scripts/01-build.sh && ./scripts/02-run.sh" >&2
  exit 1
fi

echo "claude: ${CLAUDE}"
echo "Version: $(run_user "claude --version" 2>&1 | head -1)"
echo "Checking subscription auth (sends a tiny test prompt)..."
if run_user "claude -p 'reply with exactly: AUTH_OK'" 2>&1 | grep -q AUTH_OK; then
  echo "Claude Code is authenticated ✓"
else
  echo "NOT authenticated. Log in interactively:"
  echo "  container exec -it --user ${BOX_USER} ${NAME} sh -lc 'export HOME=${BOX_HOME}; claude'"
fi
