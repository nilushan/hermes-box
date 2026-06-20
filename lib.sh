#!/usr/bin/env bash
# Shared configuration for Phase 1 scripts. Sourced by every step.
set -euo pipefail

IMAGE_TAG="local/hermes-box:latest"
MACHINE="hermes-box"
CPUS="4"
MEMORY="4G"                # host has 8 GB; 4G leaves headroom for macOS
HOME_MOUNT="none"          # do NOT mount the Mac home (/Users) into the box at all
BOX_HOME_DIR="box-home"    # host folder intended as the box's working home (see 05)
BOX_USER="nilushansilva"   # auto-provisioned in the box to match the Mac account

# Local sync transport (mutagen): keyed OpenSSH on the host<->VM bridge (port 22,
# the box's REAL sshd — NOT Tailscale SSH, whose SFTP can't chmod the mutagen agent).
# The bridge IP changes across machine restarts, so we resolve it dynamically into a
# managed ssh-config alias.
SYNC_HOST="hermes-box-sync"
SYNC_KEY="${HOME}/.ssh/hermes-box_ed25519"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the box's current bridge IP and (re)write the managed ssh-config alias.
refresh_sync_alias() {
  local cfg="${HOME}/.ssh/config" ip
  ip="$(container machine inspect "${MACHINE}" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["ipAddress"])')"
  [ -n "${ip}" ] || { echo "could not resolve ${MACHINE} bridge IP" >&2; return 1; }
  touch "${cfg}"; chmod 600 "${cfg}"
  SYNC_HOST="${SYNC_HOST}" BOX_USER="${BOX_USER}" SYNC_KEY="${SYNC_KEY}" \
  python3 - "${cfg}" "${ip}" <<'PY'
import os, re, sys
cfg, ip = sys.argv[1], sys.argv[2]
host, user, key = os.environ["SYNC_HOST"], os.environ["BOX_USER"], os.environ["SYNC_KEY"]
start = f"# >>> {host} (managed by hermes-dev) >>>"
end   = f"# <<< {host} (managed by hermes-dev) <<<"
block = (f"{start}\n"
         f"Host {host}\n"
         f"    HostName {ip}\n"
         f"    Port 22\n"
         f"    User {user}\n"
         f"    IdentityFile {key}\n"
         f"    IdentitiesOnly yes\n"
         f"    HostKeyAlias {host}\n"
         f"    StrictHostKeyChecking accept-new\n"
         f"{end}\n")
s = open(cfg).read() if os.path.exists(cfg) else ""
s = re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n?", "", s, flags=re.S)
if s and not s.endswith("\n"): s += "\n"
open(cfg, "w").write(s + block)
print(f"ssh alias '{host}' -> {ip}:22")
PY
}
