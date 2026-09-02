#!/usr/bin/env bash
# phase-11/probe_wrapper_volume.sh — Open item 3 (plan 11-04, Task 3, Part A0 + Part A).
#
# 11-RESEARCH.md Q5: can repeated `cline -m` calls ever move `model`/
# `contextWindow`, not just `updatedAt`? VRF-04 observed N=1. The wrappers
# this phase built are about to generate a very large number of `-m` calls
# by design -- this is N=6, the wrapper's own first live smoke test.
#
# Part A0 — run 11-03's opt-in WRAPPER_CHECK_ALIAS_LIVE=1 branch of
# phase-11/verify_wrappers.sh exactly once, against the live gateway's own
# /v1/models. This talks ONLY to litellm on :4000 and NEVER reaches the
# model server -- ZERO model requests -- so it is deliberately NOT wrapped
# in assert_budget/log_budget_row, and its cost (zero) is verified, not
# assumed, by comparing the `Generation queued` count immediately before and
# immediately after.
#
# Part A — 6 sequential invocations of the REAL SHIPPED wrappers
# (phase-11/cline-plan / phase-11/cline-act, alternating), each followed by:
#   (a) a REPLAY of the wrapper's own internal suppressed guard command
#       (VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash phase-01/config/verify_config.sh)
#       -- see the 🔴 comment below for exactly why this is a replay and not
#       a literal interception, and why that is the honest, available option.
#   (b) the PROBE's own SEPARATE, UNSUPPRESSED verify_config.sh call (no env
#       overrides) -- THIS is what actually exercises verify_wrappers.sh's
#       Group A/B checks live, and its full stdout is saved so "OK[WRAPPER]"
#       vs "SKIP[WRAPPER]" can be verified from output, not just an exit code
#       (a suppressed-but-passing call and a real-but-passing call both exit
#       0 -- only the printed text tells them apart).
#
# 🔴 Why the wrapper's own internal guard output cannot be captured directly.
# phase-11/wrapper_common.sh (owned by plan 11-01; this plan may not edit it
# -- hard constraint 8) captures its pre-/post-run VERIFY_CONFIG_NO_WRAPPER_CHECK=1
# guard call's stdout into a shell variable and echoes it ONLY on a non-zero
# exit. On a normal, passing run (the expected case for all 6 calls here),
# that output — including the SKIP[WRAPPER] line — is captured and then
# discarded, never touching the wrapper's own external stdout/stderr. There
# is no way to observe it from outside without either editing that file (not
# permitted here) or running the exact same command it runs, at the same
# moment, against the same providers.json state — which is what this script
# does, immediately before and after each wrapper call, and labels
# explicitly as a REPLAY, never claimed as literal interception.
#
# bash 3.2 compatible. NOTE: sourcing probe_lib11.sh turns `set -e` on in
# this shell -- every command below that is allowed to fail uses
# `cmd || var=$?` (var initialised first) or an `if`/`||` wrapper.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/probe_lib11.sh"

cd "$(cd "$HERE/.." && pwd)"   # repo root, so phase-11/... paths resolve

RUN="$(new_run_dir11 volume)"
echo "$RUN" > "phase-11/results/CURRENT_VOLUME_RUN"
echo "Run dir: $RUN"

preflight11 "$RUN" || { echo "FATAL: preflight11 failed" >&2; exit 1; }

# ============================================================================
# Part A0 — opt-in live gateway-alias check, ONCE. Zero model requests.
# ============================================================================
echo ""
echo "=== Part A0: WRAPPER_CHECK_ALIAS_LIVE=1 bash phase-11/verify_wrappers.sh (gateway /v1/models only, 0 model requests) ==="
GQ_BEFORE_A0=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true

A0_STATUS=0
WRAPPER_CHECK_ALIAS_LIVE=1 bash phase-11/verify_wrappers.sh > "$RUN/alias-live-check.txt" 2>&1 || A0_STATUS=$?
echo "$A0_STATUS" > "$RUN/alias-live-check.exit"
curl -sf http://127.0.0.1:4000/v1/models > "$RUN/gateway-models.json" 2>/dev/null || echo "curl to /v1/models failed" | tee "$RUN/gateway-models.json.curlfail" >&2

GQ_AFTER_A0=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true
{
  echo "Generation queued count before Part A0: $GQ_BEFORE_A0"
  echo "Generation queued count after  Part A0: $GQ_AFTER_A0"
} | tee "$RUN/alias-live-check-cost.txt"
if [ "$GQ_BEFORE_A0" != "$GQ_AFTER_A0" ]; then
  echo "FATAL: Part A0 (gateway-only /v1/models check) appears to have caused a model-generation request -- this must never happen" >&2
  exit 1
fi
echo "Part A0 exit status: $A0_STATUS (0=all wrapper assertions incl. live alias check passed; non-zero=see alias-live-check.txt for which assertion, incl. possibly just the live-alias one)"
echo "Part A0 EXCLUDED from budget.tsv by design -- no assert_budget/log_budget_row call was made around it (see comment above); cost proven zero above, not assumed"
echo ""
echo "--- gateway-models.json observed alias ids ---"
python3 -c "
import json, sys
try:
    d = json.load(open('$RUN/gateway-models.json'))
    ids = [m.get('id') for m in d.get('data', [])]
    print('\n'.join(ids))
except Exception as e:
    print('(could not parse gateway-models.json: %s)' % e)
" || true

# ============================================================================
# Part A — 6 live wrapper invocations.
# ============================================================================
echo ""
echo "=== Part A: 6 live wrapper invocations (alternating cline-plan / cline-act) ==="
printf 'seq\twrapper\texit_code\tduration_s\tmodel\tcontextWindow\tupdatedAt\tproviders_sha256\tverify_config_exit\trequests_this_call\trunning_total\n' > "$RUN/volume.tsv"

PROMPT="Reply with exactly one word: OK"
STOP_EARLY=0

for i in 1 2 3 4 5 6; do
  if [ "$STOP_EARLY" -eq 1 ]; then
    echo "STOPPED before call $i -- a judged field or verify_config_exit failed at an earlier call. Not attempting to restore anything." >&2
    break
  fi

  if [ $((i % 2)) -eq 1 ]; then
    WRAPPER="cline-plan"
  else
    WRAPPER="cline-act"
  fi

  wait_idle11 || { echo "FATAL: model not idle before call $i" >&2; exit 1; }
  assert_budget "$RUN"

  # --- (a) REPLAY of the wrapper's own internal PRE-run guard. See header
  # comment: NOT literal interception, but the exact command+env var the
  # wrapper's own pre-run guard executes, run immediately adjacent in time
  # and against the same providers.json state. ---
  VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash phase-01/config/verify_config.sh \
    > "$RUN/wrapper-internal-guard-seq${i}-pre.txt" 2>&1 || true

  GQ_BEFORE=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true
  T0=$(date +%s)
  CALL_RC=0
  phase-11/"$WRAPPER" --timeout 120 "$PROMPT" > "$RUN/call-${i}.stdout" 2> "$RUN/call-${i}.stderr" || CALL_RC=$?
  T1=$(date +%s)
  DUR=$((T1 - T0))
  GQ_AFTER=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true
  REQS_THIS_CALL=$((GQ_AFTER - GQ_BEFORE))

  # --- (a) REPLAY of the wrapper's own internal POST-run guard. ---
  VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash phase-01/config/verify_config.sh \
    > "$RUN/wrapper-internal-guard-seq${i}-post.txt" 2>&1 || true

  log_budget_row "$RUN" "$i" "call-${i}-${WRAPPER}" "$REQS_THIS_CALL"
  RUNNING_TOTAL=$(tail -1 "$RUN/budget.tsv" | awk -F'\t' '{print $4}')

  providers_fields "$RUN/providers-seq${i}.txt"
  MODEL_NOW="$PROV_MODEL"; CTXWIN_NOW="$PROV_CTXWIN"; UPDATEDAT_NOW="$PROV_UPDATEDAT"; SHA_NOW="$PROV_SHA256"

  # --- (b) the probe's OWN SEPARATE UNSUPPRESSED verify_config.sh call.
  # THIS is what actually exercises the live wrapper check -- no
  # VERIFY_CONFIG_NO_WRAPPER_CHECK, no PROVIDERS_JSON override. Full stdout
  # saved so OK[WRAPPER]/SKIP[WRAPPER] can be read from the TEXT, not just
  # the exit code (both a real pass and a silently-skipped-but-fine run
  # exit 0 -- only the text distinguishes them, per this plan's own
  # explicit warning). ---
  VC_LIVE_STATUS=0
  VC_LIVE_OUT="$(bash phase-01/config/verify_config.sh 2>&1)" || VC_LIVE_STATUS=$?
  printf '%s\n' "$VC_LIVE_OUT" > "$RUN/verify_config_live-${i}.txt"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$i" "$WRAPPER" "$CALL_RC" "$DUR" "$MODEL_NOW" "$CTXWIN_NOW" "$UPDATEDAT_NOW" "$SHA_NOW" "$VC_LIVE_STATUS" "$REQS_THIS_CALL" "$RUNNING_TOTAL" \
    >> "$RUN/volume.tsv"

  echo "call $i ($WRAPPER): exit=$CALL_RC dur=${DUR}s model=$MODEL_NOW ctxwin=$CTXWIN_NOW verify_config_live_exit=$VC_LIVE_STATUS requests_this_call=$REQS_THIS_CALL running_total=$RUNNING_TOTAL"

  if [ "$MODEL_NOW" != "flashnext" ] || [ "$CTXWIN_NOW" != "29000" ] || [ "$VC_LIVE_STATUS" -ne 0 ]; then
    echo "🔴 STOP: a judged field OR the live verify_config.sh check failed at call $i (model=$MODEL_NOW contextWindow=$CTXWIN_NOW verify_config_live_exit=$VC_LIVE_STATUS) -- this is a significant finding, NOT attempting to restore providers.json, recording the exact call number and observed values as-is" | tee -a "$RUN/volume.tsv" >&2
    STOP_EARLY=1
  fi
done

echo ""
echo "=== volume.tsv ==="
column -t -s $'\t' "$RUN/volume.tsv" 2>/dev/null || cat "$RUN/volume.tsv"

# ---- updatedAt diversity check ----
DISTINCT_UPDATEDAT=$(awk -F'\t' 'NR>1 && $1 ~ /^[0-9]+$/{print $7}' "$RUN/volume.tsv" | sort -u | wc -l | tr -d ' ')
echo ""
echo "distinct updatedAt values across recorded rows: $DISTINCT_UPDATEDAT"
if [ "$DISTINCT_UPDATEDAT" -lt 2 ]; then
  echo "INVESTIGATE: fewer than 2 distinct updatedAt values observed -- contradicts the Phase 10 observation that cline -m rewrites updatedAt on every call" | tee -a "$RUN/volume.tsv" >&2
else
  echo "OK: >=2 distinct updatedAt values confirms the rewrite is real and being observed each call, not a probe that forgot to re-read the file"
fi

# ---- SKIP[WRAPPER] proof on the 12 internal-guard REPLAY files ----
echo ""
PROXY_SKIP_COUNT=0
for f in "$RUN"/wrapper-internal-guard-seq*-pre.txt "$RUN"/wrapper-internal-guard-seq*-post.txt; do
  [ -f "$f" ] || continue
  if grep -q 'SKIP\[WRAPPER\]: wrapper check suppressed by VERIFY_CONFIG_NO_WRAPPER_CHECK=1' "$f"; then
    PROXY_SKIP_COUNT=$((PROXY_SKIP_COUNT + 1))
  fi
done
echo "internal-guard REPLAY files containing the exact SKIP[WRAPPER] suppression line: $PROXY_SKIP_COUNT (expect 12 = 6 pre + 6 post, one per completed call)"

# ---- OK[WRAPPER] / SKIP[WRAPPER] proof on the live independent calls ----
OK_COUNT_LIVE=0
SKIP_COUNT_LIVE=0
for f in "$RUN"/verify_config_live-*.txt; do
  [ -f "$f" ] || continue
  if grep -q 'OK\[WRAPPER\]' "$f"; then OK_COUNT_LIVE=$((OK_COUNT_LIVE + 1)); fi
  if grep -q 'SKIP\[WRAPPER\]' "$f"; then SKIP_COUNT_LIVE=$((SKIP_COUNT_LIVE + 1)); fi
done
echo "verify_config_live-*.txt files containing OK[WRAPPER]:   $OK_COUNT_LIVE (expect = number of completed calls)"
echo "verify_config_live-*.txt files containing SKIP[WRAPPER]: $SKIP_COUNT_LIVE (MUST be 0 -- any non-zero means the wrapper check was never truly exercised live)"

postflight11 "$RUN" || { echo "FATAL: postflight11 failed (see $RUN/postflight.txt)" >&2; exit 1; }

echo ""
echo "=== budget.tsv ==="
cat "$RUN/budget.tsv"

# Independent cross-check (different arithmetic path than count_requests_since).
SHARED_BASELINE="$(cat "$BUDGET_STATE_FILE")"
TOTAL_GQ=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true
BASELINE_GQ=$(head -n "$SHARED_BASELINE" "$FLASHNEXT_LOG" | grep -c 'Generation queued') || true
INDEP_COUNT=$((TOTAL_GQ - BASELINE_GQ))
FINAL_RUNNING_TOTAL=$(tail -1 "$RUN/budget.tsv" | awk -F'\t' '{print $4}')
echo ""
echo "cross-check (independent arithmetic path): budget.tsv final running_total=$FINAL_RUNNING_TOTAL ; independently recomputed (total_GQ=$TOTAL_GQ - baseline_GQ=$BASELINE_GQ)=$INDEP_COUNT"
if [ "$FINAL_RUNNING_TOTAL" != "$INDEP_COUNT" ]; then
  echo "MISMATCH: budget.tsv running_total does not match the independently recomputed count -- investigate before trusting budget.tsv" >&2
else
  echo "OK: both counting methods agree"
fi

echo ""
echo "probe_wrapper_volume.sh done. See $RUN/"
