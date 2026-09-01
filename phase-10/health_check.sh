#!/usr/bin/env bash
# health_check.sh <label-for-log>
#
# Multi-sample post-restart health gate for com.ohama.litellm. Closes the
# blind spot 09-RESEARCH.md flagged: restart_service.sh's port-bound branch
# accepts state=running AND port listening on the FIRST sample, so a job
# that binds the port briefly and then crashes under KeepAlive could report
# a false success. This script never trusts a single sample of anything:
#
#   1. launchctl print, sampled TWICE >=10s apart -- both must show
#      state=running and the SAME pid.
#   2. curl /v1/models, 3 times >=5s apart -- all must succeed and each
#      response must list "flashnext".
#   3. litellm.err.log scanned from a pre-restart watermark to EOF for
#      Traceback / ValidationError / Error loading.
#   4. ONE end-to-end completion through the unmodified flashnext alias,
#      only after confirming in_flight=0 -- max_tokens:4, never
#      flashnext-codex (kills the model server).
#
# Exit non-zero if any of the four fails. Writes "$RUN"/health-<label>.tsv
# and the raw response bodies.
#
# bash 3.2 compatible.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
  echo "usage: health_check.sh <label-for-log> [log-watermark]" >&2
  exit 2
fi
LABEL="$1"
LOG_WATERMARK_ARG="${2:-}"

if [ ! -f "$HERE/results/CURRENT_MAINTENANCE_RUN" ]; then
  echo "FATAL: $HERE/results/CURRENT_MAINTENANCE_RUN not found -- run Task 1's Restart A sequence first" >&2
  exit 2
fi
RUN=$(cat "$HERE/results/CURRENT_MAINTENANCE_RUN")
if [ ! -d "$RUN" ]; then
  echo "FATAL: run dir $RUN (from CURRENT_MAINTENANCE_RUN) does not exist" >&2
  exit 2
fi

ERR_LOG="/Users/ohama/agent-stack/litellm/litellm.err.log"
FLASHNEXT_LOG="$HOME/llm-system/services/logs/flashnext.err"
UID_NUM="$(id -u)"
LABEL_LC="com.ohama.litellm"

TSV="$RUN/health-${LABEL}.tsv"
: > "$TSV"
printf 'check\tresult\tdetail\n' >> "$TSV"

OK=1

echo "=== health_check.sh $LABEL === run dir: $RUN"

# ==========================================================================
# Check 1: two launchctl samples, >=10s apart, same pid, both running
# ==========================================================================
sample_launchctl() {
  launchctl print "gui/$UID_NUM/$LABEL_LC" 2>&1 | grep -E 'pid = |state = '
}

SAMPLE1=$(sample_launchctl)
PID1=$(printf '%s\n' "$SAMPLE1" | awk -F'= ' '/pid = /{print $2; exit}')
STATE1=$(printf '%s\n' "$SAMPLE1" | awk -F'= ' '/state = /{print $2; exit}')
echo "launchctl sample 1: pid=$PID1 state=$STATE1"
echo "waiting 10s before re-sampling for stability..." >&2
sleep 10
SAMPLE2=$(sample_launchctl)
PID2=$(printf '%s\n' "$SAMPLE2" | awk -F'= ' '/pid = /{print $2; exit}')
STATE2=$(printf '%s\n' "$SAMPLE2" | awk -F'= ' '/state = /{print $2; exit}')
echo "launchctl sample 2 (+10s): pid=$PID2 state=$STATE2"

{
  echo "--- launchctl sample 1 ---"; echo "$SAMPLE1"
  echo "--- launchctl sample 2 (+10s) ---"; echo "$SAMPLE2"
} > "$RUN/health-${LABEL}-launchctl.txt"

if [ "$STATE1" = "running" ] && [ "$STATE2" = "running" ] && [ -n "$PID1" ] && [ "$PID1" = "$PID2" ]; then
  printf 'launchctl-pid-stability\tPASS\tpid=%s stable across two samples >=10s apart, both state=running\n' "$PID1" >> "$TSV"
else
  printf 'launchctl-pid-stability\tFAIL\tsample1(pid=%s state=%s) sample2(pid=%s state=%s)\n' "$PID1" "$STATE1" "$PID2" "$STATE2" >> "$TSV"
  OK=0
fi

# ==========================================================================
# Check 2: three /v1/models calls, >=5s apart, all succeed, list flashnext
# ==========================================================================
MODELS_OK=1
for i in 1 2 3; do
  BODY_FILE="$RUN/health-${LABEL}-models-${i}.json"
  HTTP_CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' http://127.0.0.1:4000/v1/models)
  if [ "$HTTP_CODE" = "200" ] && grep -q '"flashnext"' "$BODY_FILE"; then
    echo "  /v1/models sample $i: HTTP $HTTP_CODE, flashnext present -- PASS"
  else
    echo "  /v1/models sample $i: HTTP $HTTP_CODE -- FAIL"
    MODELS_OK=0
  fi
  if [ "$i" -lt 3 ]; then
    sleep 5
  fi
done
if [ "$MODELS_OK" -eq 1 ]; then
  printf 'v1-models-x3\tPASS\t3 samples >=5s apart, all HTTP 200 with flashnext listed\n' >> "$TSV"
else
  printf 'v1-models-x3\tFAIL\tsee %s/health-%s-models-*.json\n' "$RUN" "$LABEL" >> "$TSV"
  OK=0
fi

# ==========================================================================
# Check 3: error-log scan from watermark to EOF
# ==========================================================================
WATERMARK="${LOG_WATERMARK_ARG:-0}"
SCAN_OUT="$RUN/health-${LABEL}-errlog-scan.txt"
if [ -f "$ERR_LOG" ]; then
  TOTAL_LINES=$(wc -l < "$ERR_LOG" | tr -d ' ')
  if [ "$WATERMARK" -gt "$TOTAL_LINES" ]; then
    WATERMARK=0
  fi
  sed -n "$((WATERMARK + 1)),\$p" "$ERR_LOG" > "$SCAN_OUT" 2>/dev/null || : > "$SCAN_OUT"
  HITS=$(grep -Ec 'Traceback|ValidationError|Error loading' "$SCAN_OUT" || true)
  if [ "$HITS" -eq 0 ]; then
    printf 'errlog-scan\tPASS\tno Traceback/ValidationError/Error-loading from watermark %s to EOF (%s new lines scanned)\n' "$WATERMARK" "$(wc -l < "$SCAN_OUT" | tr -d ' ')" >> "$TSV"
  else
    printf 'errlog-scan\tFAIL\t%s hit(s) found -- see %s\n' "$HITS" "$SCAN_OUT" >> "$TSV"
    OK=0
  fi
else
  printf 'errlog-scan\tPASS\t%s does not exist (nothing written yet) -- treated as clean\n' "$ERR_LOG" >> "$TSV"
fi

# ==========================================================================
# Check 4: one end-to-end completion through the UNMODIFIED flashnext alias,
# only after confirming in_flight=0. NEVER flashnext-codex.
# ==========================================================================
INFLIGHT_OK=0
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  LAST_INFLIGHT=$(grep 'in_flight=' "$FLASHNEXT_LOG" 2>/dev/null | tail -1 || true)
  case "$LAST_INFLIGHT" in
    *"in_flight=0"*)
      INFLIGHT_OK=1
      break
      ;;
  esac
  sleep 3
done

if [ "$INFLIGHT_OK" -ne 1 ]; then
  printf 'e2e-completion\tFAIL\tmodel not idle before completion attempt (last: %s)\n' "$LAST_INFLIGHT" >> "$TSV"
  OK=0
else
  COMPLETION_BODY="$RUN/health-${LABEL}-completion.json"
  HTTP_CODE=$(curl -s -o "$COMPLETION_BODY" -w '%{http_code}' \
    http://127.0.0.1:4000/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"flashnext","messages":[{"role":"user","content":"hi"}],"max_tokens":4}')
  if [ "$HTTP_CODE" = "200" ] && python3 -c "import json,sys; json.load(open('$COMPLETION_BODY'))" 2>/dev/null; then
    printf 'e2e-completion\tPASS\tHTTP 200, parseable JSON body, one POST /v1/chat/completions via flashnext (unmodified alias), see %s\n' "$COMPLETION_BODY" >> "$TSV"
  else
    printf 'e2e-completion\tFAIL\tHTTP %s or unparseable body, see %s\n' "$HTTP_CODE" "$COMPLETION_BODY" >> "$TSV"
    OK=0
  fi
fi

echo ""
echo "=== $TSV ==="
cat "$TSV"

if [ "$OK" -eq 1 ]; then
  echo "HEALTH CHECK ($LABEL): ALL 4 CHECKS PASSED"
  exit 0
else
  echo "HEALTH CHECK ($LABEL): AT LEAST ONE CHECK FAILED -- see $TSV" >&2
  exit 1
fi
