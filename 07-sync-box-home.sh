#!/usr/bin/env bash
# Continuous two-way sync between the host folder ./box-home and the box's home
# directory (/home/<user>), over the tailnet, using mutagen. This is the closest
# practical substitute for a bind mount, which `container machine` does not support.
#
# Transport: the 'hermes-box-sync' ssh alias (keyed OpenSSH on the bridge, port 22)
# created by 06-setup-sync-ssh.sh. Do NOT use Tailscale SSH here — its SFTP server
# can't chmod the mutagen agent executable.
source "$(dirname "$0")/lib.sh"

SESSION="hermes-box-home"
LOCAL_DIR="${SCRIPT_DIR}/${BOX_HOME_DIR}"
REMOTE="${SYNC_HOST}:/home/${BOX_USER}"

command -v mutagen >/dev/null 2>&1 || {
  echo "mutagen not installed. Run: brew install mutagen-io/mutagen/mutagen" >&2
  exit 1
}

# Refresh the alias to the box's current bridge IP (it changes across restarts),
# then confirm the keyed transport works.
refresh_sync_alias
ssh -o BatchMode=yes "${SYNC_HOST}" true 2>/dev/null || {
  echo "Keyed SSH to ${SYNC_HOST} failed. Run ./06-setup-sync-ssh.sh first." >&2
  exit 1
}

mkdir -p "${LOCAL_DIR}"
mutagen daemon start 2>/dev/null || true

# Idempotent: recreate the session if it already exists.
if mutagen sync list "${SESSION}" >/dev/null 2>&1; then
  echo "Session ${SESSION} already exists; terminating to recreate cleanly..."
  mutagen sync terminate "${SESSION}" 2>/dev/null || true
fi

echo "Creating two-way sync:"
echo "  local : ${LOCAL_DIR}"
echo "  remote: ${REMOTE}"
mutagen sync create \
  --name="${SESSION}" \
  --sync-mode=two-way-resolved \
  --ignore-vcs \
  --ignore=".cache" \
  --ignore=".mutagen" \
  --ignore=".mutagen-agent*" \
  "${LOCAL_DIR}" \
  "${REMOTE}"

echo
echo "Flushing initial sync..."
mutagen sync flush "${SESSION}" 2>/dev/null || true
mutagen sync list "${SESSION}"
