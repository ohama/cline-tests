#!/bin/bash
# phase-02/infra/verify_no_regression.sh — the INF-03 gate.
#
# Re-runnable, read-only: makes no changes to any service. Proves that
# after INF-01 (--max-num-seqs) and INF-02 (--host 127.0.0.1) both landed,
# the existing flashnext alias call still works end to end:
#   litellm:4000 -> role-shim:8011 -> mlx_vlm.server:8000
#
# This is the phase's single standing regression guard. Phase 5 (Kanban +
# Telegram both live) and Phase 6 (network exposure) should call this
# script before and after bringing new services up.
#
# Usage: verify_no_regression.sh [--out-dir <dir>]
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
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-inf03"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/inf03-verdict.txt"
: > "$REPORT"

UID_NUM="$(id -u)"

log() {
  echo "$1" >> "$REPORT"
}

OVERALL_RC=0
FAIL_CHECKS=""
mark_fail() {
  OVERALL_RC=1
  FAIL_CHECKS="$FAIL_CHECKS $1"
  log "CHECK: FAIL $1"
}
mark_pass() {
  log "CHECK: PASS $1"
}

# ---------------------------------------------------------------------------
# Check 1: both hardening flags still present in the on-disk plists.
# ---------------------------------------------------------------------------
log "=== Check 1: hardening flags still in place ==="
FLASHNEXT_PLIST="$LAUNCH_AGENTS_DIR/$FLASHNEXT_LABEL.plist"
LITELLM_PLIST="$LAUNCH_AGENTS_DIR/$LITELLM_LABEL.plist"

set +e
FLASHNEXT_PA="$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$FLASHNEXT_PLIST" 2>&1)"
LITELLM_PA="$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$LITELLM_PLIST" 2>&1)"
set -e
log "--- $FLASHNEXT_LABEL.plist ProgramArguments ---"
log "$FLASHNEXT_PA"
log "--- $LITELLM_LABEL.plist ProgramArguments ---"
log "$LITELLM_PA"

FLAGS_OK=1
if ! printf '%s\n' "$FLASHNEXT_PA" | grep -q -- "--max-num-seqs"; then
  FLAGS_OK=0
fi
if ! printf '%s\n' "$FLASHNEXT_PA" | awk '{$1=$1; print}' | grep -qx "$MAX_NUM_SEQS"; then
  FLAGS_OK=0
fi
if ! printf '%s\n' "$LITELLM_PA" | grep -q -- "--host"; then
  FLAGS_OK=0
fi
if ! printf '%s\n' "$LITELLM_PA" | awk '{$1=$1; print}' | grep -qx "$LITELLM_BIND_HOST"; then
  FLAGS_OK=0
fi

if [ "$FLAGS_OK" -eq 1 ]; then
  mark_pass "hardening-flags-present"
else
  mark_fail "hardening-flags-present"
fi
log ""

# ---------------------------------------------------------------------------
# Check 2: all three protected services running, record pids.
# ---------------------------------------------------------------------------
log "=== Check 2: all three services running ==="
SERVICES_OK=1
for lbl in "$FLASHNEXT_LABEL" "$ROLESHIM_LABEL" "$LITELLM_LABEL"; do
  set +e
  PRINT_OUT="$(launchctl print "gui/$UID_NUM/$lbl" 2>&1)"
  PRINT_RC=$?
  set -e
  if [ "$PRINT_RC" -ne 0 ]; then
    log "$lbl: MISSING (launchctl print exit $PRINT_RC)"
    SERVICES_OK=0
    continue
  fi
  LINES="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*(state|pid) ')"
  log "--- $lbl ---"
  log "$LINES"
  STATE="$(printf '%s\n' "$LINES" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
  if [ "$STATE" != "running" ]; then
    log "$lbl: state=$STATE, expected running"
    SERVICES_OK=0
  fi
done
if [ "$SERVICES_OK" -eq 1 ]; then
  mark_pass "services-running"
else
  mark_fail "services-running"
fi
log ""

# ---------------------------------------------------------------------------
# Check 3: Hop 3 (model server) alive.
# ---------------------------------------------------------------------------
log "=== Check 3: hop 3 - mlx_vlm.server :$MLX_PORT /v1/models ==="
set +e
CODE_8000="$(curl -s -m 60 -o "$OUT_DIR/models-8000.json" -w '%{http_code}' "http://127.0.0.1:${MLX_PORT}/v1/models")"
set -e
log "http_code=$CODE_8000"
if [ "$CODE_8000" = "200" ]; then
  mark_pass "hop3-mlx-vlm-server"
else
  mark_fail "hop3-mlx-vlm-server"
fi
log ""

# ---------------------------------------------------------------------------
# Check 4: Hop 2 (role-shim) alive.
# ---------------------------------------------------------------------------
log "=== Check 4: hop 2 - role-shim :$ROLESHIM_PORT /v1/models ==="
set +e
CODE_8011="$(curl -s -m 60 -o "$OUT_DIR/models-8011.json" -w '%{http_code}' "http://127.0.0.1:${ROLESHIM_PORT}/v1/models")"
CODE_8011_RC=$?
set -e
if [ "$CODE_8011_RC" -eq 0 ] && [ "$CODE_8011" = "200" ]; then
  log "oracle=/v1/models http_code=$CODE_8011"
  mark_pass "hop2-role-shim"
else
  log "oracle=/v1/models unavailable (rc=$CODE_8011_RC, code=$CODE_8011); falling back to TCP connect probe"
  set +e
  nc -z -G 5 127.0.0.1 "$ROLESHIM_PORT"
  NC_RC=$?
  set -e
  log "oracle=tcp-connect nc_rc=$NC_RC"
  if [ "$NC_RC" -eq 0 ]; then
    mark_pass "hop2-role-shim (tcp-connect fallback, /v1/models route not present)"
  else
    mark_fail "hop2-role-shim"
  fi
fi
log ""

# ---------------------------------------------------------------------------
# Check 5: Hop 1 (litellm) alive and still advertising the alias.
# ---------------------------------------------------------------------------
log "=== Check 5: hop 1 - litellm :$LITELLM_PORT /v1/models advertises flashnext ==="
set +e
CODE_4000="$(curl -s -m 60 -o "$OUT_DIR/models-4000.json" -w '%{http_code}' "http://127.0.0.1:${LITELLM_PORT}/v1/models")"
set -e
log "http_code=$CODE_4000"
if [ "$CODE_4000" = "200" ] && grep -q "flashnext" "$OUT_DIR/models-4000.json"; then
  mark_pass "hop1-litellm-advertises-flashnext"
else
  mark_fail "hop1-litellm-advertises-flashnext"
fi
log ""

# ---------------------------------------------------------------------------
# Check 6: THE GATE — full chain, real completion, via 127.0.0.1.
# ---------------------------------------------------------------------------
log "=== Check 6: full chain completion via 127.0.0.1 ==="
set +e
CODE_CHAIN_IP="$(curl -s -m 180 -X POST "http://127.0.0.1:${LITELLM_PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"flashnext","messages":[{"role":"user","content":"say hi"}],"max_tokens":8}' \
  -o "$OUT_DIR/chain-response.json" -w '%{http_code}')"
set -e
log "http_code=$CODE_CHAIN_IP"
log "body: $(cat "$OUT_DIR/chain-response.json" 2>/dev/null)"
CHAIN_IP_OK=0
if [ "$CODE_CHAIN_IP" = "200" ]; then
  set +e
  CONTENT_CHECK="$(python3 -c "
import json, sys
try:
    d = json.load(open('$OUT_DIR/chain-response.json'))
    content = d['choices'][0]['message']['content']
    usage = d.get('usage')
    if content and content.strip():
        print('CONTENT_OK')
        if usage:
            print('usage:', usage, file=sys.stderr)
    else:
        print('CONTENT_EMPTY')
except Exception as e:
    print('CONTENT_ERROR: %s' % e)
" 2>>"$REPORT")"
  set -e
  log "parsed: $CONTENT_CHECK"
  if [ "$CONTENT_CHECK" = "CONTENT_OK" ]; then
    CHAIN_IP_OK=1
  fi
fi
if [ "$CHAIN_IP_OK" -eq 1 ]; then
  mark_pass "full-chain-127.0.0.1"
else
  mark_fail "full-chain-127.0.0.1"
fi
log ""

# ---------------------------------------------------------------------------
# Check 7: same call via the `localhost` hostname.
# ---------------------------------------------------------------------------
log "=== Check 7: full chain completion via localhost hostname ==="
set +e
CODE_CHAIN_HOST="$(curl -s -m 180 -X POST "http://localhost:${LITELLM_PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"flashnext","messages":[{"role":"user","content":"say hi"}],"max_tokens":8}' \
  -o "$OUT_DIR/chain-response-localhost.json" -w '%{http_code}')"
set -e
log "http_code=$CODE_CHAIN_HOST"
log "body: $(cat "$OUT_DIR/chain-response-localhost.json" 2>/dev/null)"
CHAIN_HOST_OK=0
if [ "$CODE_CHAIN_HOST" = "200" ]; then
  set +e
  CONTENT_CHECK_HOST="$(python3 -c "
import json
try:
    d = json.load(open('$OUT_DIR/chain-response-localhost.json'))
    content = d['choices'][0]['message']['content']
    if content and content.strip():
        print('CONTENT_OK')
    else:
        print('CONTENT_EMPTY')
except Exception as e:
    print('CONTENT_ERROR: %s' % e)
")"
  set -e
  log "parsed: $CONTENT_CHECK_HOST"
  if [ "$CONTENT_CHECK_HOST" = "CONTENT_OK" ]; then
    CHAIN_HOST_OK=1
  fi
fi
if [ "$CHAIN_HOST_OK" -eq 1 ]; then
  mark_pass "full-chain-localhost"
else
  mark_fail "full-chain-localhost"
fi
log ""

# ---------------------------------------------------------------------------
# Check 8: serialization did not deadlock the server — one more direct probe.
# ---------------------------------------------------------------------------
log "=== Check 8: direct :$MLX_PORT probe (no queue deadlock) ==="
set +e
CODE_DIRECT="$(curl -s -m 180 -X POST "http://127.0.0.1:${MLX_PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$(python3 -c "import json; print(json.load(open('$OUT_DIR/models-8000.json'))['data'][-1]['id'])" 2>/dev/null || echo flashnext)\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}],\"max_tokens\":8}" \
  -o "$OUT_DIR/direct-8000-response.json" -w '%{http_code}')"
set -e
log "http_code=$CODE_DIRECT"
log "body: $(cat "$OUT_DIR/direct-8000-response.json" 2>/dev/null)"
DIRECT_OK=0
if [ "$CODE_DIRECT" = "200" ]; then
  set +e
  DIRECT_CONTENT_CHECK="$(python3 -c "
import json
try:
    d = json.load(open('$OUT_DIR/direct-8000-response.json'))
    content = d['choices'][0]['message']['content']
    if content and content.strip():
        print('CONTENT_OK')
    else:
        print('CONTENT_EMPTY')
except Exception as e:
    print('CONTENT_ERROR: %s' % e)
")"
  set -e
  log "parsed: $DIRECT_CONTENT_CHECK"
  if [ "$DIRECT_CONTENT_CHECK" = "CONTENT_OK" ]; then
    DIRECT_OK=1
  fi
fi
if [ "$DIRECT_OK" -eq 1 ]; then
  mark_pass "no-queue-deadlock"
else
  mark_fail "no-queue-deadlock"
fi
log ""

# ---------------------------------------------------------------------------
# Final verdict.
# ---------------------------------------------------------------------------
if [ "$OVERALL_RC" -eq 0 ]; then
  log "INF03: PASS"
  echo "INF03: PASS"
else
  log "INF03: FAIL${FAIL_CHECKS}"
  echo "INF03: FAIL${FAIL_CHECKS} (see $REPORT)" >&2
fi

echo "RESULTS_DIR=$OUT_DIR"
exit "$OVERALL_RC"
