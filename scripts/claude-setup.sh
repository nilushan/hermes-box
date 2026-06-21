#!/usr/bin/env bash
# Ensure Claude Code is installed in the box and report subscription auth status.
# Idempotent. Claude Code lives in the box home (/opt/data/.local) — the persistent
# data volume — so the binary AND the login survive container recreates and are
# included in the restic backup (creds encrypted by restic).
#
# Authentication is your interactive Claude subscription login (cannot be scripted):
#   container exec -it --user hermes hermes-box sh -lc 'export HOME=/opt/data; \
#     /opt/data/.local/bin/claude'   # then follow the login prompts (URL + code)
source "$(dirname "$0")/../lib/common.sh"

BOX_HOME=/opt/data
CLAUDE="${BOX_HOME}/.local/bin/claude"
run_user() { container exec --user "${BOX_USER}" "${NAME}" sh -lc "export HOME=${BOX_HOME}; $1"; }

# Install if missing (official installer, into the box home, as the box user).
if ! container exec "${NAME}" test -x "${CLAUDE}" 2>/dev/null; then
  echo "Claude Code not found — installing into ${NAME}:${BOX_HOME}/.local ..."
  run_user "curl -fsSL https://claude.ai/install.sh | bash"
fi

echo "Version: $(container exec "${NAME}" "${CLAUDE}" --version 2>&1 | head -1)"

echo "Checking subscription auth (sends a tiny test prompt)..."
if run_user "${CLAUDE} -p 'reply with exactly: AUTH_OK'" 2>&1 | grep -q AUTH_OK; then
  echo "Claude Code is authenticated ✓"
else
  echo "NOT authenticated. Log in interactively:"
  echo "  container exec -it --user ${BOX_USER} ${NAME} sh -lc 'export HOME=${BOX_HOME}; ${CLAUDE}'"
fi
