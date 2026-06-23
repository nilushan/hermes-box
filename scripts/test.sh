#!/usr/bin/env bash
# Canonical, re-runnable, non-destructive health check for the hermes-box
# (Hermes gateway + Tailscale). Run after any change. Exits non-zero on any failure.
source "$(dirname "$0")/../lib/common.sh"

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

# Hermes gateway answers HTTP on the gateway port (the dashboard UI is served here).
ck "Hermes gateway responds on :${GATEWAY_PORT}" \
   "test \"\$(curl -s -o /dev/null -m 8 -w '%{http_code}' http://localhost:${GATEWAY_PORT}/ )\" != 000"

# Data + work bind mounts present.
ck "Hermes data mounted (/opt/data)" \
   "container exec ${NAME} test -e /opt/data"
ck "work folder mounted (${WORK_MOUNT})" \
   "container exec ${NAME} test -d ${WORK_MOUNT}"

# Real bidirectional volume mount (work folder).
STAMP=".hbox-test-$$"
echo "mac-$$" > "${HERMES_WORK_DIR}/${STAMP}"
ck "box reads Mac-written file" \
   "container exec ${NAME} grep -q 'mac-$$' ${WORK_MOUNT}/${STAMP}"
container exec "${NAME}" sh -c "echo box-$$ >> ${WORK_MOUNT}/${STAMP}" 2>/dev/null || true
ck "Mac reads box-written append" \
   "grep -q 'box-$$' ${HERMES_WORK_DIR}/${STAMP}"
rm -f "${HERMES_WORK_DIR}/${STAMP}"

# SSH over the tailnet (needs the ACL + correct TS hostname).
ck "SSH over tailnet (${BOX_USER}@${TS_HOSTNAME})" \
   "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 ${BOX_USER}@${TS_HOSTNAME} true"

# Caddy front (wiki + dashboard over the tailnet via Tailscale TLS). Skipped if no FQDN.
if [ -n "${TS_FQDN}" ]; then
  ck "wiki served (https://${TS_FQDN}/)" \
     "test \"\$(curl -s -o /dev/null -m 12 -w '%{http_code}' https://${TS_FQDN}/ )\" = 200"
  ck "dashboard via Caddy (https://${TS_FQDN}:8443/)" \
     "test \"\$(curl -s -o /dev/null -m 12 -w '%{http_code}' https://${TS_FQDN}:8443/ )\" != 000"
else
  echo "SKIP: Caddy HTTPS checks (set HERMES_BOX_TS_FQDN in .env)"
fi

echo "============================================"
if [ "${fail}" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "${fail}"
