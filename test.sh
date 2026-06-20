#!/usr/bin/env bash
# Canonical, re-runnable, non-destructive health check for the hermes-box.
# Run after any change. Exits non-zero if any check fails.
source "$(dirname "$0")/lib.sh"

fail=0
pass() { echo "PASS: $1"; }
ck()   { if eval "$2" >/dev/null 2>&1; then pass "$1"; else echo "FAIL: $1"; fail=1; fi; }

echo "== hermes-box checks (name=${NAME}, user=${BOX_USER}, ts=${TS_HOSTNAME}) =="

ck "container '${NAME}' is running" \
   "container list 2>/dev/null | grep -E '(^|[[:space:]])${NAME}([[:space:]]|\$)' | grep -q running"
ck "box user '${BOX_USER}' exists" \
   "container exec ${NAME} id ${BOX_USER}"
ck "tailscaled state store healthy" \
   "! container exec ${NAME} tailscale status 2>&1 | grep -qi 'state store'"
ck "tailscale is up (not logged out/stopped)" \
   "! container exec ${NAME} tailscale status 2>&1 | grep -Eqi 'logged out|Tailscale is stopped'"
ck "home is mounted (${HERMES_HOME})" \
   "container exec ${NAME} test -d /home/${BOX_USER}"

# Real bidirectional volume mount.
STAMP=".hbox-test-$$"
echo "mac-$$" > "${HERMES_HOME}/${STAMP}"
ck "box reads Mac-written file" \
   "container exec ${NAME} grep -q 'mac-$$' /home/${BOX_USER}/${STAMP}"
container exec "${NAME}" sh -c "echo box-$$ >> /home/${BOX_USER}/${STAMP}" 2>/dev/null || true
ck "Mac reads box-written append" \
   "grep -q 'box-$$' ${HERMES_HOME}/${STAMP}"
rm -f "${HERMES_HOME}/${STAMP}"

# SSH over the tailnet (best-effort; needs the ACL + correct TS hostname).
ck "SSH over tailnet (${BOX_USER}@${TS_HOSTNAME})" \
   "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 ${BOX_USER}@${TS_HOSTNAME} true"

echo "============================================"
if [ "${fail}" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
