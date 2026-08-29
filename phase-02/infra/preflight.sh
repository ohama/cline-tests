#!/bin/bash
# phase-02/infra/preflight.sh — re-runnable, read-only pre-change gate.
# Asserts: three protected services running, GPU wired limit intact, all
# three ports listening, plist sha256 + ProgramArguments captured, and
# live-vs-mirror plist drift recorded (not failed on).
#
# Usage: preflight.sh [--label <text>] [--out-dir <dir>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

LABEL="preflight"
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --label)
      LABEL="$2"
      shift 2
      ;;
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
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/preflight-$LABEL.txt"
: > "$REPORT"

UID_NUM="$(id -u)"

log() {
  echo "$1" >> "$REPORT"
}

finish() {
  echo "RESULTS_DIR=$OUT_DIR"
  exit "$1"
}

fail() {
  local reason="$1"
  log "PREFLIGHT: FAIL $reason"
  echo "PREFLIGHT: FAIL $reason" >&2
  finish 1
}

# ---------------------------------------------------------------------------
# 1. date / OS version
# ---------------------------------------------------------------------------
log "=== timestamp / OS ==="
log "$(date -u)"
log "sw_vers -productVersion: $(sw_vers -productVersion)"
log "uname -r: $(uname -r)"
log ""

# ---------------------------------------------------------------------------
# 2. three protected services must be running
# ---------------------------------------------------------------------------
log "=== service state ==="
LABELS="$FLASHNEXT_LABEL $ROLESHIM_LABEL $LITELLM_LABEL"
for lbl in $LABELS; do
  set +e
  PRINT_OUT="$(launchctl print "gui/$UID_NUM/$lbl" 2>&1)"
  PRINT_RC=$?
  set -e
  if [ "$PRINT_RC" -ne 0 ]; then
    log "LABEL $lbl: MISSING (launchctl print exit $PRINT_RC)"
    fail "label $lbl is missing (launchctl print exited $PRINT_RC)"
  fi
  LINES="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*(state|pid|path) ')"
  log "--- $lbl ---"
  log "$LINES"
  TOP_STATE="$(printf '%s\n' "$LINES" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
  if [ "$TOP_STATE" != "running" ]; then
    fail "label $lbl state is '$TOP_STATE', expected 'running'"
  fi
done
log ""

# ---------------------------------------------------------------------------
# 3. GPU wired limit sysctl (Pitfall 6: only changes on machine reboot)
# ---------------------------------------------------------------------------
log "=== iogpu.wired_limit_mb ==="
CURRENT_WIRED_LIMIT="$(sysctl -n iogpu.wired_limit_mb)"
log "iogpu.wired_limit_mb=$CURRENT_WIRED_LIMIT (expected $EXPECTED_WIRED_LIMIT_MB)"
if [ "$CURRENT_WIRED_LIMIT" != "$EXPECTED_WIRED_LIMIT_MB" ]; then
  fail "iogpu.wired_limit_mb=$CURRENT_WIRED_LIMIT != expected $EXPECTED_WIRED_LIMIT_MB; machine appears to have rebooted; re-apply \`sudo sysctl iogpu.wired_limit_mb=$EXPECTED_WIRED_LIMIT_MB\` and re-run"
fi
log ""

# ---------------------------------------------------------------------------
# 4. listening ports
# ---------------------------------------------------------------------------
log "=== listening ports ==="
set +e
LSOF_LINES="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ":(${MLX_PORT}|${ROLESHIM_PORT}|${LITELLM_PORT}) ")"
set -e
log "$LSOF_LINES"
for p in "$MLX_PORT" "$ROLESHIM_PORT" "$LITELLM_PORT"; do
  if ! printf '%s\n' "$LSOF_LINES" | grep -qE ":${p} "; then
    fail "port $p is not listening"
  fi
done
if printf '%s\n' "$LSOF_LINES" | grep -q "\*:${LITELLM_PORT} "; then
  log "LITELLM_BIND_MARKER: *:${LITELLM_PORT} (LAN-exposed)"
elif printf '%s\n' "$LSOF_LINES" | grep -q "127.0.0.1:${LITELLM_PORT} "; then
  log "LITELLM_BIND_MARKER: 127.0.0.1:${LITELLM_PORT} (localhost-only)"
else
  log "LITELLM_BIND_MARKER: unknown (could not classify bind address from lsof line)"
fi
log ""

# ---------------------------------------------------------------------------
# 5 & 6. plist sha256 + ProgramArguments dump + live-vs-mirror diff
#    (flashnext + litellm only, per plan)
# ---------------------------------------------------------------------------
log "=== plist sha256 / ProgramArguments / mirror drift ==="
for lbl in "$FLASHNEXT_LABEL" "$LITELLM_LABEL"; do
  LIVE_PLIST="$LAUNCH_AGENTS_DIR/$lbl.plist"
  MIRROR_PLIST="$MIRROR_AGENTS_DIR/$lbl.plist"
  log "--- $lbl.plist ---"
  if [ ! -f "$LIVE_PLIST" ]; then
    fail "live plist missing: $LIVE_PLIST"
  fi
  log "sha256: $(shasum -a 256 "$LIVE_PLIST")"
  log "ProgramArguments:"
  set +e
  PA_DUMP="$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$LIVE_PLIST" 2>&1)"
  set -e
  log "$PA_DUMP"
  if [ -f "$MIRROR_PLIST" ]; then
    set +e
    DIFF_OUT="$(diff "$LIVE_PLIST" "$MIRROR_PLIST")"
    DIFF_RC=$?
    set -e
    if [ "$DIFF_RC" -ne 0 ]; then
      log "MIRROR_DRIFT: $lbl.plist (live differs from $MIRROR_PLIST)"
      log "$DIFF_OUT"
      echo "WARNING: MIRROR_DRIFT detected for $lbl.plist (see $REPORT)" >&2
    else
      log "mirror: identical to $MIRROR_PLIST"
    fi
  else
    log "MIRROR_DRIFT: $lbl.plist (mirror file not found at $MIRROR_PLIST)"
    echo "WARNING: mirror file not found for $lbl.plist" >&2
  fi
  log ""
done

# ---------------------------------------------------------------------------
# 7. final verdict
# ---------------------------------------------------------------------------
log "PREFLIGHT: PASS"
echo "PREFLIGHT: PASS"
finish 0
