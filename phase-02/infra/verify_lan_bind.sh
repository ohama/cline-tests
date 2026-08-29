#!/bin/bash
# phase-02/infra/verify_lan_bind.sh — re-runnable INF-02 proof.
#
# Read-only: makes no changes, safe to run at any time (plan 02-04 and any
# future phase can re-run it). Proves litellm is loopback-only from both
# directions:
#   1. structural: lsof shows 127.0.0.1:4000, never *:4000
#   2. LAN-IP curl is refused at the connection level
#   3. loopback by IP still returns 200 with flashnext listed
#   4. loopback by the "localhost" hostname still returns 200 (all four
#      real consumers use the hostname, not the bare IP, and /etc/hosts
#      maps localhost to both 127.0.0.1 and ::1)
#   5. the other two protected services (:8000, :8011) are unaffected
#
# Usage: verify_lan_bind.sh --out-dir <dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-inf02-verify"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/inf02-verdict.txt"
: > "$REPORT"

log() {
  echo "$1" >> "$REPORT"
}

OVERALL_RC=0
FAIL_CHECKS=""
INCONCLUSIVE_CHECKS=""
mark_fail() {
  OVERALL_RC=1
  FAIL_CHECKS="$FAIL_CHECKS $1"
}
mark_inconclusive() {
  INCONCLUSIVE_CHECKS="$INCONCLUSIVE_CHECKS $1"
}

# ---------------------------------------------------------------------------
# 1. Bind address — structural proof via lsof.
# ---------------------------------------------------------------------------
log "=== Check 1: bind address (lsof) ==="
set +e
LSOF_OUT="$(lsof -nP -iTCP:"$LITELLM_PORT" -sTCP:LISTEN 2>/dev/null)"
set -e
log "$LSOF_OUT"
if printf '%s\n' "$LSOF_OUT" | grep -q "127.0.0.1:${LITELLM_PORT} " \
   && ! printf '%s\n' "$LSOF_OUT" | grep -q "\*:${LITELLM_PORT} "; then
  log "CHECK 1: PASS (loopback-only listener confirmed, no wildcard bind found)"
else
  log "CHECK 1: FAIL bind-address"
  mark_fail "bind-address"
fi
log ""

# ---------------------------------------------------------------------------
# 2. LAN rejection.
# ---------------------------------------------------------------------------
log "=== Check 2: LAN rejection ==="
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
LAN_IFACE="en0"
if [ -z "$LAN_IP" ]; then
  LAN_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
  LAN_IFACE="en1"
fi

if [ -z "$LAN_IP" ]; then
  log "CHECK 2: INCONCLUSIVE (neither en0 nor en1 yielded an address)"
  mark_inconclusive "lan-rejection"
else
  log "LAN_IFACE: $LAN_IFACE"
  log "LAN_IP: $LAN_IP"
  set +e
  HTTP_CODE="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$LAN_IP:${LITELLM_PORT}/v1/models")"
  CURL_RC=$?
  set -e
  log "curl http://$LAN_IP:${LITELLM_PORT}/v1/models -> http_code=$HTTP_CODE curl_rc=$CURL_RC"
  if [ "$CURL_RC" -eq 7 ]; then
    log "CHECK 2: PASS (connection refused, rc=7)"
  elif [ "$CURL_RC" -eq 28 ]; then
    log "CHECK 2: PASS (secondary — timeout, rc=28, no listener answering)"
  elif [ "$CURL_RC" -eq 0 ]; then
    log "CHECK 2: FAIL (port reachable off-loopback, http_code=$HTTP_CODE)"
    mark_fail "lan-rejection"
  else
    log "CHECK 2: FAIL (unexpected curl rc=$CURL_RC)"
    mark_fail "lan-rejection"
  fi
fi
log ""

# ---------------------------------------------------------------------------
# 3. Loopback by IP still works.
# ---------------------------------------------------------------------------
log "=== Check 3: loopback by IP (127.0.0.1) ==="
set +e
BODY_IP="$(curl -s -m 30 "http://127.0.0.1:${LITELLM_PORT}/v1/models")"
CURL_IP_RC=$?
CODE_IP="$(curl -s -m 30 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${LITELLM_PORT}/v1/models")"
set -e
log "http_code=$CODE_IP curl_rc=$CURL_IP_RC"
if [ "$CODE_IP" = "200" ] && printf '%s' "$BODY_IP" | grep -q "flashnext"; then
  log "CHECK 3: PASS (200, body contains flashnext)"
else
  log "CHECK 3: FAIL (code=$CODE_IP, flashnext-in-body=$(printf '%s' "$BODY_IP" | grep -qc flashnext))"
  mark_fail "loopback-ip"
fi
log ""

# ---------------------------------------------------------------------------
# 4. Loopback by HOSTNAME still works.
# ---------------------------------------------------------------------------
log "=== Check 4: loopback by hostname (localhost) ==="
set +e
CODE_HOST="$(curl -s -m 30 -o /dev/null -w '%{http_code}' "http://localhost:${LITELLM_PORT}/v1/models")"
set -e
log "http_code=$CODE_HOST"
if [ "$CODE_HOST" = "200" ]; then
  log "CHECK 4: PASS"
else
  log "CHECK 4: FAIL (localhost hostname path did not return 200 — code=$CODE_HOST)."
  log "This is a genuine INF-03 regression, not cosmetic: /etc/hosts maps localhost to"
  log "both 127.0.0.1 and ::1, and a v4-only bind can strand IPv6-preferring clients."
  log "Two real options: (a) leave the bind and update the four consumer configs"
  log "(Cline providers.json, ~/.hermes/config.yaml, ~/.openjarvis/config.toml,"
  log "~/.claude/proxy.env) to 127.0.0.1 explicitly, or (b) roll back to the pre-edit"
  log "plist. Do not choose unilaterally — report this."
  mark_fail "loopback-hostname"
fi
log ""

# ---------------------------------------------------------------------------
# 5. Other two services unchanged.
# ---------------------------------------------------------------------------
log "=== Check 5: :${MLX_PORT} and :${ROLESHIM_PORT} unchanged (loopback) ==="
set +e
LSOF_MLX="$(lsof -nP -iTCP:"$MLX_PORT" -sTCP:LISTEN 2>/dev/null)"
LSOF_ROLESHIM="$(lsof -nP -iTCP:"$ROLESHIM_PORT" -sTCP:LISTEN 2>/dev/null)"
set -e
log "--- :$MLX_PORT ---"
log "$LSOF_MLX"
log "--- :$ROLESHIM_PORT ---"
log "$LSOF_ROLESHIM"
if printf '%s\n' "$LSOF_MLX" | grep -q "127.0.0.1:${MLX_PORT} " \
   && printf '%s\n' "$LSOF_ROLESHIM" | grep -q "127.0.0.1:${ROLESHIM_PORT} "; then
  log "CHECK 5: PASS"
else
  log "CHECK 5: FAIL (collateral bind-address change on :${MLX_PORT} or :${ROLESHIM_PORT})"
  mark_fail "collateral-ports"
fi
log ""

# ---------------------------------------------------------------------------
# Final verdict.
# ---------------------------------------------------------------------------
if [ "$OVERALL_RC" -eq 0 ]; then
  if [ -n "$INCONCLUSIVE_CHECKS" ]; then
    log "INF02: INCONCLUSIVE${INCONCLUSIVE_CHECKS}"
    echo "INF02: INCONCLUSIVE${INCONCLUSIVE_CHECKS}"
  else
    log "INF02: PASS"
    echo "INF02: PASS"
  fi
else
  log "INF02: FAIL${FAIL_CHECKS}"
  echo "INF02: FAIL${FAIL_CHECKS} (see $REPORT)" >&2
fi

echo "RESULTS_DIR=$OUT_DIR"
exit "$OVERALL_RC"
