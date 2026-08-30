#!/bin/bash
# phase-05/services/verify_services.sh — the standing Phase 5 gate.
#
# This is Phase 5's standing gate, in the same shape as
# phase-02/infra/verify_no_regression.sh and phase-03/sandbox/verify_sandbox.sh:
# Phase 6 should call this script before and after opening anything to the
# network, comparing the transcripts. It never calls check_versions.sh (that
# spends one real cline invocation per run inside its own Check B) — that
# script stays the deliberate drift gate, run on purpose by a human/plan
# task, never from inside an automated health check. And it never sends a
# termination signal to any process and never invokes any of launchd's
# state-changing subcommands — the only launchd subcommand this script ever
# calls is the read-only `print`. If a service needs to be brought up again
# after this gate reports a problem, that is phase-02/infra/restart_service.sh's
# job, not this script's.
#
# Read-only, re-runnable, mutates nothing: no plist edits, no environment
# variable injection, no process supervision changes. Every judgement below
# is delegated to a real measurement (a port actually listening, an HTTP
# response, a pid sampled more than once, bytes mapped into a process's own
# memory) — never to `state = running` alone, which a job stuck in a restart
# loop can report on almost every sample.
#
# macOS /bin/bash is 3.2 (no declare -A) — this file uses only parallel
# indexed arrays, the same idiom verify_sandbox.sh already established.
#
# Usage: verify_services.sh [--out-dir <dir>]
#
# Exit code contract (mirrors phase-03/sandbox/verify_sandbox.sh's 3-way
# discipline, itself mirroring phase-01/parse_result.py):
#   0 = every CHECK line PASSed
#   1 = at least one CHECK FAILed and nothing crashed
#   2 = at least one probe crashed (inconclusive) — never reported as a pass
set -uo pipefail

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
      echo "verify_services.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-gate"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/verify_services-verdict.txt"
: > "$REPORT"

UID_NUM="$(id -u)"
SYNC_SH="$HOME/local-llm-settings/sync.sh"

vlog() {
  echo "$1" | tee -a "$REPORT"
}

# ---------------------------------------------------------------------------
# Case bookkeeping: parallel indexed arrays (bash 3.2 has no declare -A).
# rc convention (same as assert_denied.sh / verify_sandbox.sh):
#   0 = PASS, 1 = FAIL, 2 = CRASHED (the probe itself broke, not the target).
# ---------------------------------------------------------------------------
CASE_IDS=()
CASE_RCS=()

record_check() {
  local id="$1" rc="$2" detail="${3:-}"
  CASE_IDS+=("$id")
  CASE_RCS+=("$rc")
  if [ "$rc" -eq 0 ]; then
    vlog "CHECK: PASS $id"
  elif [ "$rc" -eq 2 ]; then
    vlog "CHECK: FAIL $id -- CRASHED: $detail"
  else
    vlog "CHECK: FAIL $id -- $detail"
  fi
}

# Sets STATE / PID globals from `launchctl print` for one label. Read-only.
print_state_pid() {
  local label="$1" out
  set +e
  out="$(launchctl print "gui/$UID_NUM/$label" 2>&1)"
  set -e
  STATE="$(printf '%s\n' "$out" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
  PID="$(printf '%s\n' "$out" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"
}

vlog "=== phase-05/services/verify_services.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog ""

# ---------------------------------------------------------------------------
# Assertions 1+2 (per label): running-with-a-pid, and SETTLED not looping.
# Three samples spaced ~10s apart (~20s total) must all report state=running
# with the SAME pid. A service that is "running" only because it keeps being
# restarted must FAIL the settled check — this is what makes the gate
# non-vacuous, the same discipline restart_service.sh's own portless health
# poll already applies.
# ---------------------------------------------------------------------------
KANBAN_PID=""
TELEGRAM_PID=""

for ROLE in kanban telegram; do
  if [ "$ROLE" = "kanban" ]; then LBL="$KANBAN_LABEL"; else LBL="$TELEGRAM_LABEL"; fi
  vlog "--- $ROLE ($LBL): running + settled ---"

  print_state_pid "$LBL"
  S1="$STATE"; P1="$PID"
  if [ "$S1" = "running" ] && [ -n "$P1" ]; then
    record_check "${ROLE}-state-running" 0
  else
    record_check "${ROLE}-state-running" 1 "state=${S1:-<none>} pid=${P1:-<none>}"
  fi

  sleep 10
  print_state_pid "$LBL"
  S2="$STATE"; P2="$PID"

  sleep 10
  print_state_pid "$LBL"
  S3="$STATE"; P3="$PID"

  vlog "${ROLE}-pid-samples: $P1 / $P2 / $P3 (state $S1/$S2/$S3)"
  if [ "$S1" = "running" ] && [ "$S2" = "running" ] && [ "$S3" = "running" ] \
    && [ -n "$P1" ] && [ "$P1" = "$P2" ] && [ "$P2" = "$P3" ]; then
    record_check "${ROLE}-pid-settled" 0
  else
    record_check "${ROLE}-pid-settled" 1 "pid samples $P1/$P2/$P3 over ~20s did not stay identical"
  fi

  if [ "$ROLE" = "kanban" ]; then KANBAN_PID="$P3"; else TELEGRAM_PID="$P3"; fi
done
vlog ""

# ---------------------------------------------------------------------------
# Assertion 3: kanban — port actually LISTENing and held by the reported
# pid, plus a real HTTP response (any status code is fine; the default
# passcode makes a 401/302 the correct answer, not a failure).
# ---------------------------------------------------------------------------
vlog "--- kanban: port + http ---"
if [ -z "$KANBAN_PID" ]; then
  record_check "kanban-port-listening" 1 "no kanban pid sampled above"
  record_check "kanban-http-response" 1 "no kanban pid sampled above"
else
  set +e
  LISTEN_OUT="$(lsof -nP -iTCP:"$KANBAN_PORT" -sTCP:LISTEN 2>/dev/null)"
  set -e
  if [ -n "$LISTEN_OUT" ] && printf '%s\n' "$LISTEN_OUT" | awk '{print $2}' | grep -qx "$KANBAN_PID"; then
    record_check "kanban-port-listening" 0
  else
    record_check "kanban-port-listening" 1 "port $KANBAN_PORT not LISTENing under pid $KANBAN_PID: $(printf '%s' "$LISTEN_OUT" | tr '\n' ';')"
  fi

  set +e
  HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://$KANBAN_HOST:$KANBAN_PORT/")"
  CURL_RC=$?
  set -e
  vlog "kanban-http-response: http_code=${HTTP_CODE:-<none>} curl_rc=$CURL_RC"
  if [ "$CURL_RC" -eq 0 ] && [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]] && [ "$HTTP_CODE" != "000" ]; then
    record_check "kanban-http-response" 0
  else
    record_check "kanban-http-response" 1 "http_code=${HTTP_CODE:-<none>} curl_rc=$CURL_RC"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# Assertion 4: anti-orphan.
#
# Kanban half: `ps -o args=` can NEVER show the literal string "sandbox-exec"
# for a supervised pid, no matter how correct the confinement is — sandbox-exec
# performs a real execve() into the wrapped command, and execve() replaces the
# recorded argv (05-04's decision log established this the same way; this
# gate deliberately does not repeat that plan-authoring trap). So identity is
# checked via `ps args` (does the process look like kanban), and confinement
# is checked the way 05-04 did: `vmmap` on this EXACT pid must show
# libsandbox.1.dylib/libsystem_sandbox.dylib actually mapped into its own
# memory — proof sandbox_init() ran inside it, not just that the wrapper
# script says it should have.
#
# Telegram half: the empty-token idle branch must never reach cline, so
# `pgrep -f 'connect telegram'` must be exactly 0 and the self-daemonize log
# signature must never appear. If a token has been injected, that assertion
# is deliberately relaxed to a different, still-meaningful one.
# ---------------------------------------------------------------------------
vlog "--- anti-orphan ---"
if [ -z "$KANBAN_PID" ]; then
  record_check "anti-orphan-kanban-sandboxed" 1 "no kanban pid sampled above"
else
  set +e
  KANBAN_ARGS="$(ps -o args= -p "$KANBAN_PID" 2>/dev/null)"
  KANBAN_VMMAP="$(vmmap "$KANBAN_PID" 2>/dev/null | grep -i sandbox)"
  set -e
  ARGS_OK=0
  printf '%s' "$KANBAN_ARGS" | grep -qi "kanban" && ARGS_OK=1
  SANDBOX_OK=0
  printf '%s' "$KANBAN_VMMAP" | grep -q "libsandbox" && SANDBOX_OK=1
  if [ "$ARGS_OK" -eq 1 ] && [ "$SANDBOX_OK" -eq 1 ]; then
    record_check "anti-orphan-kanban-sandboxed" 0
  else
    record_check "anti-orphan-kanban-sandboxed" 1 "args_match=$ARGS_OK sandbox_mapped=$SANDBOX_OK args='$KANBAN_ARGS'"
  fi
fi

TELEGRAM_PLIST="$LAUNCH_AGENTS_DIR/$TELEGRAM_LABEL.plist"
set +e
TOKEN_STATE="$(plutil -convert json -o - "$TELEGRAM_PLIST" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("CRASH:" + str(e))
    sys.exit(0)
env = d.get("EnvironmentVariables") or {}
if "TELEGRAM_BOT_TOKEN" not in env:
    print("CRASH:no TELEGRAM_BOT_TOKEN key")
elif env.get("TELEGRAM_BOT_TOKEN") == "":
    print("EMPTY")
else:
    print("SET")
')"
set -e

if [ -z "$TOKEN_STATE" ] || [[ "$TOKEN_STATE" == CRASH:* ]]; then
  record_check "anti-orphan-telegram" 2 "could not read TELEGRAM_BOT_TOKEN from $TELEGRAM_PLIST: ${TOKEN_STATE:-<empty output>}"
elif [ "$TOKEN_STATE" = "EMPTY" ]; then
  set +e
  ORPHAN_COUNT="$(pgrep -f 'connect telegram' | wc -l | tr -d ' ')"
  set -e
  LOG_HIT=0
  for f in "$SERVICE_LOG_DIR/telegram-connect.log" "$SERVICE_LOG_DIR/telegram-connect.err"; do
    [ -f "$f" ] || continue
    grep -q "starting background connector pid=" "$f" 2>/dev/null && LOG_HIT=1
  done
  vlog "anti-orphan-telegram: token empty, orphan_count=$ORPHAN_COUNT log_hit=$LOG_HIT"
  if [ "$ORPHAN_COUNT" = "0" ] && [ "$LOG_HIT" -eq 0 ]; then
    record_check "anti-orphan-telegram" 0
  else
    record_check "anti-orphan-telegram" 1 "orphan_count=$ORPHAN_COUNT log_hit=$LOG_HIT"
  fi
else
  vlog "INFO: TELEGRAM_BOT_TOKEN is non-empty -- the empty-token orphan assertion is relaxed. The supervised pid ($TELEGRAM_PID) must instead BE the connector process itself, invoked with -i (interactive/foreground), not a parent whose self-daemonized child has already detached."
  if [ -z "$TELEGRAM_PID" ]; then
    record_check "anti-orphan-telegram" 1 "no telegram pid sampled above"
  else
    set +e
    TELE_ARGS="$(ps -o args= -p "$TELEGRAM_PID" 2>/dev/null)"
    set -e
    if printf '%s' "$TELE_ARGS" | grep -q -- '-i' && printf '%s' "$TELE_ARGS" | grep -q 'connect telegram'; then
      record_check "anti-orphan-telegram" 0
    else
      record_check "anti-orphan-telegram" 1 "activated-token pid $TELEGRAM_PID args did not show '-i ... connect telegram': '$TELE_ARGS'"
    fi
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# Assertion 5: port hygiene, the Phase 6 precondition. Neither service pid
# may hold port 3000.
# ---------------------------------------------------------------------------
vlog "--- port hygiene: neither service on :3000 ---"
set +e
PORT3000_OUT="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null)"
set -e
HYGIENE_OK=1
HYGIENE_DETAIL=""
for p in "$KANBAN_PID" "$TELEGRAM_PID"; do
  [ -z "$p" ] && continue
  if printf '%s\n' "$PORT3000_OUT" | awk '{print $2}' | grep -qx "$p"; then
    HYGIENE_OK=0
    HYGIENE_DETAIL="$HYGIENE_DETAIL pid=$p"
  fi
done
if [ "$HYGIENE_OK" -eq 1 ]; then
  record_check "port-hygiene-no-3000" 0
else
  record_check "port-hygiene-no-3000" 1 "found on :3000:$HYGIENE_DETAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# Assertion 6: pin gates. Both installed plists must carry BOTH
# CLINE_NO_AUTO_UPDATE=1 and KANBAN_NO_AUTO_UPDATE=1 — no binary is invoked,
# only plutil (read-only conversion) and python3 (parsing) touch the plist.
# ---------------------------------------------------------------------------
vlog "--- pin gates (both auto-update env vars, both plists) ---"
for LBL in "$KANBAN_LABEL" "$TELEGRAM_LABEL"; do
  PLIST="$LAUNCH_AGENTS_DIR/$LBL.plist"
  if [ ! -f "$PLIST" ]; then
    record_check "pin-gate-$LBL" 1 "plist not found: $PLIST"
    continue
  fi
  set +e
  RESULT="$(plutil -convert json -o - "$PLIST" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("CRASH:" + str(e))
    sys.exit(0)
env = d.get("EnvironmentVariables") or {}
c = str(env.get("CLINE_NO_AUTO_UPDATE"))
k = str(env.get("KANBAN_NO_AUTO_UPDATE"))
if c == "1" and k == "1":
    print("OK")
else:
    print("FAIL cline=%s kanban=%s" % (c, k))
')"
  set -e
  if [ -z "$RESULT" ]; then
    record_check "pin-gate-$LBL" 2 "plutil/python3 produced no output for $PLIST"
  elif [[ "$RESULT" == CRASH:* ]]; then
    record_check "pin-gate-$LBL" 2 "$RESULT"
  elif [ "$RESULT" = "OK" ]; then
    record_check "pin-gate-$LBL" 0
  else
    record_check "pin-gate-$LBL" 1 "$RESULT"
  fi
done
vlog ""

# ---------------------------------------------------------------------------
# Assertion 7: sandbox boundary unchanged — EXTRA_ALLOW_PATHS stays empty.
# Sourced in a subshell so this script's own environment is never touched.
# ---------------------------------------------------------------------------
vlog "--- sandbox boundary: EXTRA_ALLOW_PATHS empty ---"
set +e
EAP_VALUE="$(bash -c 'source "$1/phase-03/sandbox/config.env" && printf "%s" "$EXTRA_ALLOW_PATHS"' _ "$PROJECT_ROOT" 2>&1)"
EAP_RC=$?
set -e
if [ "$EAP_RC" -ne 0 ]; then
  record_check "sandbox-boundary-empty-allow-paths" 2 "sourcing phase-03/sandbox/config.env failed (rc=$EAP_RC): $EAP_VALUE"
elif [ -z "$EAP_VALUE" ]; then
  record_check "sandbox-boundary-empty-allow-paths" 0
else
  record_check "sandbox-boundary-empty-allow-paths" 1 "EXTRA_ALLOW_PATHS='$EAP_VALUE' (expected empty)"
fi
vlog ""

# ---------------------------------------------------------------------------
# Assertion 8: log growth watch. launchd never rotates these four files —
# the job here is to make unbounded growth VISIBLE, never to rotate it
# silently. Oversize is a WARN, not a FAIL: this check always PASSes once it
# has successfully measured all four files.
# ---------------------------------------------------------------------------
vlog "--- log growth watch (\$SERVICE_LOG_DIR=$SERVICE_LOG_DIR) ---"
LOG_FILES=("kanban.log" "kanban.err" "telegram-connect.log" "telegram-connect.err")
LOG_WATCH_OK=1
for f in "${LOG_FILES[@]}"; do
  path="$SERVICE_LOG_DIR/$f"
  if [ -f "$path" ]; then
    sz="$(stat -f%z "$path" 2>/dev/null || echo "")"
  else
    sz=""
  fi
  if [ -z "$sz" ]; then
    vlog "log-size: $f = <missing, treated as 0>"
    sz=0
  else
    vlog "log-size: $f = ${sz} bytes"
  fi
  if [ "$sz" -gt 10485760 ]; then
    vlog "WARN: $f exceeds 10 MB ($sz bytes) — launchd does not rotate this file"
  fi
done
record_check "log-growth-watch" 0
vlog ""

# ---------------------------------------------------------------------------
# Assertion 9: mirror freshness (SVC-05, standing). Both labels must appear
# in ~/local-llm-settings/sync.sh's LABELS array, and both mirrored plists
# must stay byte-identical to the live ones.
# ---------------------------------------------------------------------------
vlog "--- mirror freshness ---"
if [ ! -f "$SYNC_SH" ]; then
  record_check "mirror-labels-tracked" 2 "sync.sh not found at $SYNC_SH"
else
  LABELS_OK=1
  for LBL in "$KANBAN_LABEL" "$TELEGRAM_LABEL"; do
    grep -q -- "$LBL" "$SYNC_SH" || LABELS_OK=0
  done
  if [ "$LABELS_OK" -eq 1 ]; then
    record_check "mirror-labels-tracked" 0
  else
    record_check "mirror-labels-tracked" 1 "one or both labels missing from $SYNC_SH's LABELS array"
  fi
fi

MIRROR_OK=1
MIRROR_DETAIL=""
for LBL in "$KANBAN_LABEL" "$TELEGRAM_LABEL"; do
  LIVE="$LAUNCH_AGENTS_DIR/$LBL.plist"
  MIRROR="$MIRROR_AGENTS_DIR/$LBL.plist"
  if [ ! -f "$MIRROR" ] || ! cmp -s "$LIVE" "$MIRROR"; then
    MIRROR_OK=0
    MIRROR_DETAIL="$MIRROR_DETAIL $LBL"
  fi
done
if [ "$MIRROR_OK" -eq 1 ]; then
  record_check "mirror-plists-byte-identical" 0
else
  record_check "mirror-plists-byte-identical" 1 "mismatched or missing mirror for:$MIRROR_DETAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# Final verdict.
# ---------------------------------------------------------------------------
TOTAL=${#CASE_IDS[@]}
PASSED=0
FAILED=0
CRASHED=0
for i in "${!CASE_RCS[@]}"; do
  rc="${CASE_RCS[$i]}"
  if [ "$rc" = "0" ]; then
    PASSED=$((PASSED + 1))
  elif [ "$rc" = "2" ]; then
    CRASHED=$((CRASHED + 1))
    FAILED=$((FAILED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

vlog "CASES $PASSED/$TOTAL"
vlog "CRASHED $CRASHED"

if [ "$CRASHED" -gt 0 ]; then
  vlog "VERIFY_SERVICES: INCONCLUSIVE (crashed=$CRASHED)"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 2
elif [ "$FAILED" -gt 0 ]; then
  vlog "VERIFY_SERVICES: FAIL"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 1
else
  vlog "VERIFY_SERVICES: PASS"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 0
fi
