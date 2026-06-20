#!/usr/bin/env bash
# Set up a robust, keyed OpenSSH transport for mutagen, over the host<->VM bridge.
#
# Why the bridge and not Tailscale SSH? mutagen installs its agent via SFTP then
# chmod +x's it, but Tailscale SSH's SFTP server ignores chmod, leaving the agent
# non-executable ("Permission denied"). The box's own OpenSSH server (reachable on
# the bridge IP, port 22 — Tailscale only intercepts the tailscale0 interface)
# handles SFTP correctly. The bridge link is local to this Mac and sub-millisecond,
# which is ideal for syncing a folder that already lives on this Mac.
#
# Tailscale SSH on the tailnet stays untouched for remote interactive logins.
source "$(dirname "$0")/lib.sh"

# 1) Dedicated passphraseless keypair on the Mac (a local automation transport).
if [ ! -f "${SYNC_KEY}" ]; then
  echo "Generating ${SYNC_KEY}..."
  ssh-keygen -t ed25519 -N "" -C "hermes-box-sync" -f "${SYNC_KEY}"
else
  echo "Key ${SYNC_KEY} already exists."
fi
PUB="$(cat "${SYNC_KEY}.pub")"

# 2) Authorize the key in the box (over the working Tailscale SSH; exec works there).
echo "Authorizing key in the box..."
ssh -o BatchMode=yes "${BOX_USER}@${MACHINE}" "PUB='${PUB}' bash -s" <<'REMOTE'
set -e
umask 077
mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys
grep -qxF "$PUB" ~/.ssh/authorized_keys || echo "$PUB" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
echo "  authorized_keys updated"
REMOTE

# 3) Write the managed ssh-config alias pointing at the box's current bridge IP.
refresh_sync_alias

# 4) Verify keyed connection to the REAL sshd (no prompt, no Tailscale-SSH check).
echo "=== verify keyed SSH via ${SYNC_HOST} ==="
ssh -o BatchMode=yes "${SYNC_HOST}" 'echo "KEYED SSH OK on $(hostname) — this is the box'\''s real sshd"'
