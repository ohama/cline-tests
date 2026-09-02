#!/usr/bin/env bash
# phase-11/run_ab.sh — Plan 11-05 Task 2 / reused by plan 11-06's main run.
#
# The re-runnable, resumable, budget-capped USE-03 A/B runner. Reuses
# phase-11/probe_lib11.sh (preflight11/postflight11, wait_idle11,
# assert_budget/log_budget_row) and phase-11/grade_ab.py against the fixed
# task set in phase-11/tasks/MANIFEST.tsv. Arms and invocation shape are
# phase-11/AB-PROTOCOL.md §1's literal design; this script does not decide
# them, only executes them.
#
# Usage:
#   run_ab.sh --tasks <id,id,...|all> --arms <A,B,C> --reps <n> --out <run-dir> \
#             --cap <n> [--resume] [--sizing-note "<free text for manifest.txt>"]
#
# --cap has NO built-in default. AB-PROTOCOL.md §4 states the cap must come
# from a written number (the pilot's for plan 11-05, the sizing rule's
# resolved number for plan 11-06) — silently defaulting this script's cap to
# some arbitrary constant would let a caller skip the one written-down
# number this whole plan exists to produce. Omitting --cap is a usage error.
#
# ---- design notes, read before modifying ----
#
# 1. Cell order: task-major, arm-minor, per AB-PROTOCOL.md §3 ("Order").
#    Cells are generated as: for each task id (ascending, as given by
#    --tasks); for each arm (in the order given by --arms); for each rep
#    (1..N). This means, for one task, all of arm A's reps run, then all of
#    arm B's (normally just 1), then all of arm C's — but the NEXT task's
#    arm-A cells run immediately after, never after every task's arm A has
#    already run. This is what keeps "do not run all of arm A and then all
#    of arm C" true across the whole cell list, not just within one task.
#
# 2. Watermark attribution is BYTE-offset based (wc -c / tail -c +N), not
#    line-count based, for this script's own per-cell prompt_tokens /
#    completion_tokens / finish_reason extraction — deliberately more
#    precise than probe_lib11.sh's line-count watermark (which this script
#    also uses, unmodified, for the shared request-budget count via
#    assert_budget/log_budget_row, since that counter is plan-wide and
#    owned by 11-04's file, not this script's to reinvent). Two watermark
#    mechanisms, two different jobs: one counts requests against a budget,
#    the other attributes token/finish_reason detail to one specific cell.
#
# 3. Retry policy is OPERATIONAL-FAILURE ONLY: non-zero cline exit, an
#    empty captured stream, or a connection-refused/ENOENT-shaped stderr.
#    A cell that ran cleanly and graded `incorrect` or `no-answer` is never
#    retried — retrying on a disappointing verdict would be optional-stopping
#    on outcome, exactly what AB-TASKSET.md's own outcome-neutrality stance
#    forbids elsewhere in this phase.
#
# 4. Runaway guard: if a single cell's OWN watermark window shows more than
#    3 `Generation queued` lines, this is no longer the single-turn
#    instrument the protocol describes (an agent loop started) — the run
#    aborts immediately rather than silently averaging over a different task
#    shape than the one that was designed.
#
# bash 3.2 compatible: no declare -A, no ${var^^}; every array expansion
# guards against "unbound variable" under set -u with "${arr[@]:-}".
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
MANIFEST="$HERE/tasks/MANIFEST.tsv"
VERIFY_CONFIG_SH="$REPO_ROOT/phase-01/config/verify_config.sh"

# ---- WRAPPER_CLINE_BIN: READ ONLY from phase-11/wrapper.env -----------------
# We do not invoke the wrappers themselves (AB-PROTOCOL.md §2 -- the A/B
# measures the alias, not the wrapper), but we reuse wrapper.env's single
# source of truth for the absolute binary path rather than hardcoding it a
# second time in this file. This is a READ of wrapper.env, never a write --
# hard constraint 3 of plan 11-05 forbids editing it.
# shellcheck source=/dev/null
source "$HERE/wrapper.env"
CLINE_BIN="$WRAPPER_CLINE_BIN"

usage() {
  cat >&2 <<'EOF'
usage: run_ab.sh --tasks <id,id,...|all> --arms <A,B,C> --reps <n> --out <run-dir> \
                  --cap <n> [--resume] [--sizing-note "<text>"]

  --tasks   comma-separated task ids from phase-11/tasks/MANIFEST.tsv, or "all"
  --arms    comma-separated subset of A,B,C (arm letters, AB-PROTOCOL.md §1)
  --reps    repetitions per (task, arm) cell (arm B is conventionally run at
            reps=1 regardless of this value -- pass --arms without B, or a
            separate B-only invocation with --reps 1, to honour the
            reduced-replication design; this script does not special-case B)
  --out     run directory (created if missing)
  --cap     hard request cap for THIS invocation (no default -- see header)
  --resume  skip any (task_id, arm, rep) cell already present in ab.tsv
  --sizing-note   free-text line recorded in manifest.txt describing what
            sizing decision (if any) this invocation's cap/task/rep choice
            reflects (e.g. "pilot run -- sizing not yet decided")
EOF
  exit 2
}

TASKS_ARG=""
ARMS_ARG=""
REPS=""
OUT_DIR=""
CAP=""
RESUME=0
SIZING_NOTE="(not specified)"

while [ $# -gt 0 ]; do
  case "$1" in
    --tasks) TASKS_ARG="${2:-}"; shift 2 ;;
    --arms) ARMS_ARG="${2:-}"; shift 2 ;;
    --reps) REPS="${2:-}"; shift 2 ;;
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    --cap) CAP="${2:-}"; shift 2 ;;
    --resume) RESUME=1; shift ;;
    --sizing-note) SIZING_NOTE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unrecognised argument: $1" >&2; usage ;;
  esac
done

[ -z "$TASKS_ARG" ] && { echo "ERROR: --tasks required" >&2; usage; }
[ -z "$ARMS_ARG" ] && { echo "ERROR: --arms required" >&2; usage; }
[ -z "$REPS" ] && { echo "ERROR: --reps required" >&2; usage; }
[ -z "$OUT_DIR" ] && { echo "ERROR: --out required" >&2; usage; }
[ -z "$CAP" ] && { echo "ERROR: --cap required -- no built-in default, see this script's own header comment" >&2; usage; }

case "$REPS" in
  ''|*[!0-9]*) echo "ERROR: --reps must be a non-negative integer, got '$REPS'" >&2; exit 2 ;;
esac
case "$CAP" in
  ''|*[!0-9]*) echo "ERROR: --cap must be a non-negative integer, got '$CAP'" >&2; exit 2 ;;
esac

# ---- export the cap BEFORE sourcing probe_lib11.sh --------------------------
# probe_lib11.sh does `RUN_REQ_CAP="${RUN_REQ_CAP:-14}"` at source time, so an
# already-exported value wins over its own internal default.
export RUN_REQ_CAP="$CAP"
# shellcheck source=/dev/null
source "$HERE/probe_lib11.sh"

alias_for() {
  case "$1" in
    A) printf '%s' "flashnext" ;;
    B) printf '%s' "flashnext-act" ;;
    C) printf '%s' "flashnext-plan" ;;
    *) echo "ERROR: unknown arm '$1' (must be A, B, or C -- AB-PROTOCOL.md §1)" >&2; return 1 ;;
  esac
}

manifest_field() {
  # manifest_field <task_id> <column_name>
  local id="$1" col="$2"
  awk -F'\t' -v id="$id" -v col="$col" '
    NR==1 { for (i=1;i<=NF;i++) idx[$i]=i; next }
    $1==id { print $(idx[col]) }
  ' "$MANIFEST"
}

if [ "$TASKS_ARG" = "all" ]; then
  TASK_ID_LIST="$(awk -F'\t' 'NR>1{print $1}' "$MANIFEST")"
else
  TASK_ID_LIST="$(printf '%s' "$TASKS_ARG" | tr ',' '\n')"
fi

ARM_LIST="$(printf '%s' "$ARMS_ARG" | tr ',' '\n')"

mkdir -p "$OUT_DIR/streams"
AB_TSV="$OUT_DIR/ab.tsv"

# ---- ORCHESTRATOR-DIRECTED DEVIATION (plan 11-06, not part of the original plan text) -------
# `cline -m flashnext-plan` has been reproduced TWICE (11-04 Open Item 3, 11-05's own pilot,
# both cline 3.0.61) persistently rewriting providers.json's `model` field. probe_lib11.sh's
# postflight11 treats this as a hard-fail-no-self-repair condition -- correct for a probe, but
# this run makes 40 flashnext-plan (arm C) invocations, so as written it would halt at the very
# first C-arm cell, leaving the file drifted AND producing no A/B. Per explicit orchestrator
# instruction for this run only: repair immediately after every invocation instead of halting on
# `model` drift, and log every occurrence (cell, arm, alias, observed value, restore outcome) to
# providers-drift.tsv -- this count is evidence for plan 11-07, not noise to suppress.
# contextWindow drift is NOT auto-repaired -- it has never been observed; treat it as a hard stop.
DRIFT_TSV="$OUT_DIR/providers-drift.tsv"
if [ ! -s "$DRIFT_TSV" ]; then
  # append-only across invocations of the same --out directory, same rationale as manifest.txt
  # above (a --resume re-invocation must never destroy a prior invocation's real drift record).
  printf 'cell\tarm\talias\tobserved_model\trestore_outcome\tobserved_contextWindow\n' > "$DRIFT_TSV"
fi
DRIFT_COUNT=0

check_and_repair_providers() {
  # check_and_repair_providers <cell_label> <arm> <alias>
  # Returns 0 if compliant (no drift, or drift repaired). Returns 2 on a condition that must
  # HALT the whole run (contextWindow drift, or a failed repair) -- caller must abort on non-zero.
  local cell="$1" arm="$2" alias="$3"
  providers_fields "$OUT_DIR/.providers-check-tmp.txt"
  local observed_model="$PROV_MODEL" observed_ctxwin="$PROV_CTXWIN"

  if [ "$observed_ctxwin" != "29000" ]; then
    echo "HALT[CONTEXTWINDOW]: providers.json contextWindow drifted to '$observed_ctxwin' after $cell -- this has never been observed before and is NOT auto-repaired (orchestrator instruction: halt and report, do not guess at a fix for something new)" >&2
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cell" "$arm" "$alias" "$observed_model" "HALT-CONTEXTWINDOW" "$observed_ctxwin" >> "$DRIFT_TSV"
    return 2
  fi

  if [ "$observed_model" != "flashnext" ]; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    echo "  [providers-drift #$DRIFT_COUNT] $cell: providers.json model drifted to '$observed_model' -- repairing via phase-01/config/apply_provider_config.sh" >&2
    local repair_status=0
    bash "$REPO_ROOT/phase-01/config/apply_provider_config.sh" > "$OUT_DIR/providers-repair-${cell//\//_}.log" 2>&1 || repair_status=$?
    providers_fields "$OUT_DIR/.providers-check-tmp.txt"
    if [ "$PROV_MODEL" = "flashnext" ] && [ "$PROV_CTXWIN" = "29000" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cell" "$arm" "$alias" "$observed_model" "repaired" "$PROV_CTXWIN" >> "$DRIFT_TSV"
      echo "  [providers-drift #$DRIFT_COUNT] repair OK: model restored to flashnext (contextWindow=$PROV_CTXWIN)" >&2
      return 0
    else
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cell" "$arm" "$alias" "$observed_model" "REPAIR-FAILED(model=$PROV_MODEL,ctxwin=$PROV_CTXWIN,apply_exit=$repair_status)" "$PROV_CTXWIN" >> "$DRIFT_TSV"
      echo "HALT[REPAIR-FAILED]: apply_provider_config.sh (exit=$repair_status) did not restore providers.json after $cell -- observed model='$PROV_MODEL' contextWindow='$PROV_CTXWIN'" >&2
      return 2
    fi
  fi
  return 0
}

if [ ! -f "$AB_TSV" ]; then
  printf 'task_id\tarm\talias\trep\texit_code\tduration_s\tprompt_tokens\tcompletion_tokens\tfinish_reason\tverdict\tqualifier\textracted_answer\texpected\tstream_path\trequests_this_cell\trunning_total\tmax_tokens\tretried\n' > "$AB_TSV"
elif [ "$RESUME" -ne 1 ]; then
  existing_data_rows=$(($(wc -l < "$AB_TSV" | tr -d ' ') - 1))
  if [ "$existing_data_rows" -gt 0 ]; then
    echo "ERROR: $AB_TSV already has $existing_data_rows data row(s) and --resume was not given." >&2
    echo "       Pass --resume to continue this run, or use a different --out directory." >&2
    exit 2
  fi
fi

already_done() {
  # already_done <task_id> <arm> <rep> -- true (0) if that exact cell already
  # has a data row in ab.tsv (resume support).
  local id="$1" arm="$2" rep="$3"
  awk -F'\t' -v id="$id" -v arm="$arm" -v rep="$rep" \
    'NR>1 && $1==id && $2==arm && $4==rep { found=1 } END { exit found?0:1 }' "$AB_TSV"
}

echo "=== run_ab.sh starting $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "run dir: $OUT_DIR"
echo "tasks: $(printf '%s' "$TASK_ID_LIST" | tr '\n' ',' | sed 's/,$//')"
echo "arms: $ARMS_ARG   reps: $REPS   cap: $CAP   resume: $RESUME"

if ! preflight11 "$OUT_DIR"; then
  echo "ABORT: preflight11 failed -- see $OUT_DIR/preflight.txt" >&2
  exit 1
fi

TRIGGER_LINE="$(VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash "$VERIFY_CONFIG_SH" 2>&1 | grep '^trigger' || true)"

# manifest.txt is APPEND-ONLY across invocations of the same --out directory.
# A --resume re-invocation must never destroy the ORIGINAL invocation's record
# (the one that actually fired the live requests) -- each invocation gets its
# own timestamped block, never overwriting a prior one. (Bug found and fixed
# during this plan's own pilot run: an early version used a truncating `>`
# here, and a --resume re-invocation silently wiped the first run's real
# cells_this_invocation and live_compaction_trigger values.)
{
  echo "=== phase-11/run_ab.sh manifest -- invocation at $(date -u +%Y-%m-%dT%H:%M:%SZ) (resume=$RESUME) ==="
  echo "run_dir=$OUT_DIR"
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "tasks=$(printf '%s' "$TASK_ID_LIST" | tr '\n' ',' | sed 's/,$//')"
  echo "arms=$ARMS_ARG"
  echo "reps=$REPS"
  echo "cap=$CAP"
  echo "timeout=600"
  echo "alias_A=flashnext"
  echo "alias_B=flashnext-act"
  echo "alias_C=flashnext-plan"
  echo "sizing_note=$SIZING_NOTE"
  echo "live_compaction_trigger: $TRIGGER_LINE"
  echo "cline_version_before=$(cat "$OUT_DIR/cline-version-before.txt" 2>/dev/null)"
} >> "$OUT_DIR/manifest.txt"

SEQ=0
CELL_COUNT=0
ABORTED=0

for TASK_ID in $TASK_ID_LIST; do
  PROMPT_FILE="$(manifest_field "$TASK_ID" prompt_file)"
  EXPECTED_FILE="$(manifest_field "$TASK_ID" expected_file)"
  if [ -z "$PROMPT_FILE" ] || [ -z "$EXPECTED_FILE" ]; then
    echo "ABORT: task id '$TASK_ID' not found in $MANIFEST" >&2
    ABORTED=1
    break
  fi
  PROMPT_TEXT="$(cat "$REPO_ROOT/$PROMPT_FILE")"
  EXPECTED_ABS="$REPO_ROOT/$EXPECTED_FILE"

  for ARM in $ARM_LIST; do
    ALIAS="$(alias_for "$ARM")" || { ABORTED=1; break 2; }

    REP=1
    while [ "$REP" -le "$REPS" ]; do
      SEQ=$((SEQ + 1))
      CELL_LABEL="${TASK_ID}-${ARM}-r${REP}"

      if [ "$RESUME" -eq 1 ] && already_done "$TASK_ID" "$ARM" "$REP"; then
        echo "[$SEQ] $CELL_LABEL -- already in ab.tsv, skipping (resume), 0 new requests"
        REP=$((REP + 1))
        continue
      fi

      echo "[$SEQ] $CELL_LABEL -- alias=$ALIAS"

      if ! wait_idle11; then
        echo "ABORT: model not idle before cell $CELL_LABEL" >&2
        ABORTED=1
        break 3
      fi
      assert_budget "$OUT_DIR"   # exits the whole script (exit 1) if already at cap

      STREAM_PATH="$OUT_DIR/streams/${CELL_LABEL}.ndjson"
      ERR_PATH="$OUT_DIR/streams/${CELL_LABEL}.stderr"

      RETRIED="no"
      ATTEMPT=1
      while :; do
        CELL_BYTE_OFFSET="$(wc -c < "$FLASHNEXT_LOG" | tr -d ' ')"
        START_S="$(date +%s)"
        EXIT_CODE=0
        CLINE_NO_AUTO_UPDATE=1 "$CLINE_BIN" -P openai-compatible -m "$ALIAS" \
          --compaction agentic --json -t 600 "$PROMPT_TEXT" \
          > "$STREAM_PATH" 2> "$ERR_PATH" || EXIT_CODE=$?
        END_S="$(date +%s)"
        DURATION=$((END_S - START_S))

        STREAM_BYTES=0
        [ -f "$STREAM_PATH" ] && STREAM_BYTES=$(wc -c < "$STREAM_PATH" | tr -d ' ')

        # ---- ORCHESTRATOR-DIRECTED DEVIATION: check+repair providers.json after THIS
        # invocation, regardless of whether it was operationally successful -- see the
        # check_and_repair_providers() definition above for the full reasoning. This must run
        # after every real cline call, including a retry attempt, per the orchestrator's
        # instruction ("after each cline invocation").
        if ! check_and_repair_providers "${CELL_LABEL}-attempt${ATTEMPT}" "$ARM" "$ALIAS"; then
          ABORTED=1
          break 4
        fi

        OPERATIONAL_FAIL=0
        if [ "$EXIT_CODE" -ne 0 ] || [ "$STREAM_BYTES" -eq 0 ]; then
          OPERATIONAL_FAIL=1
        elif grep -qiE 'ECONNREFUSED|Connection refused|ENOENT|command not found|No such file or directory' "$ERR_PATH" 2>/dev/null; then
          OPERATIONAL_FAIL=1
        fi

        if [ "$OPERATIONAL_FAIL" -eq 1 ] && [ "$ATTEMPT" -eq 1 ]; then
          echo "  operational failure (exit=$EXIT_CODE stream_bytes=$STREAM_BYTES) -- retrying once" >&2
          cp "$STREAM_PATH" "${STREAM_PATH}.attempt1" 2>/dev/null || true
          cp "$ERR_PATH" "${ERR_PATH}.attempt1" 2>/dev/null || true
          RETRIED="yes"
          ATTEMPT=2
          if ! wait_idle11; then
            echo "ABORT: model not idle before retry of $CELL_LABEL" >&2
            ABORTED=1
            break 4
          fi
          assert_budget "$OUT_DIR"
          continue
        fi
        break
      done

      NEW_LOG_TEXT="$(tail -c "+$((CELL_BYTE_OFFSET + 1))" "$FLASHNEXT_LOG" 2>/dev/null || true)"
      REQUESTS_THIS_CELL=$(printf '%s\n' "$NEW_LOG_TEXT" | grep -c 'Generation queued') || true
      [ -z "${REQUESTS_THIS_CELL:-}" ] && REQUESTS_THIS_CELL=0

      QUEUED_LINE="$(printf '%s\n' "$NEW_LOG_TEXT" | grep 'Generation queued' | head -1 || true)"
      REQ_ID=""
      PROMPT_TOKENS=""
      MAX_TOKENS=""
      if [ -n "$QUEUED_LINE" ]; then
        REQ_ID="$(printf '%s' "$QUEUED_LINE" | sed -n 's/.*request=\([0-9a-f]*\).*/\1/p')"
        PROMPT_TOKENS="$(printf '%s' "$QUEUED_LINE" | sed -n 's/.*prompt_tokens=\([0-9]*\).*/\1/p')"
        MAX_TOKENS="$(printf '%s' "$QUEUED_LINE" | sed -n 's/.*max_tokens=\([0-9]*\).*/\1/p')"
      fi
      COMPLETION_TOKENS=""
      FINISH_REASON=""
      if [ -n "$REQ_ID" ]; then
        DECODE_LINE="$(printf '%s\n' "$NEW_LOG_TEXT" | grep "Decode completed: request=$REQ_ID" | head -1 || true)"
        if [ -n "$DECODE_LINE" ]; then
          COMPLETION_TOKENS="$(printf '%s' "$DECODE_LINE" | sed -n 's/.*generated_tokens=\([0-9]*\).*/\1/p')"
          FINISH_REASON="$(printf '%s' "$DECODE_LINE" | sed -n 's/.*finish_reason=\([a-zA-Z_]*\).*/\1/p')"
        fi
      fi

      if [ "$REQUESTS_THIS_CELL" -gt 3 ]; then
        echo "ABORT[RUNAWAY]: cell $CELL_LABEL produced $REQUESTS_THIS_CELL Generation-queued lines (>3) -- this is no longer a single-turn instrument" >&2
        log_budget_row "$OUT_DIR" "$SEQ" "$CELL_LABEL-RUNAWAY" "$REQUESTS_THIS_CELL"
        ABORTED=1
        break 3
      fi

      log_budget_row "$OUT_DIR" "$SEQ" "$CELL_LABEL" "$REQUESTS_THIS_CELL"
      BASELINE="$(cat "$BUDGET_STATE_FILE")"
      RUNNING_TOTAL="$(count_requests_since "$BASELINE")"

      GRADE_JSON="$(python3 "$HERE/grade_ab.py" --ndjson "$STREAM_PATH" --expected "$EXPECTED_ABS" --json 2>>"$ERR_PATH")"
      grade_field() {
        python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get(sys.argv[2], ''))
" "$GRADE_JSON" "$1"
      }
      VERDICT="$(grade_field verdict)"
      QUALIFIER="$(grade_field qualifier)"
      EXTRACTED="$(grade_field extracted_answer)"
      EXPECTED_VAL="$(grade_field expected)"

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$TASK_ID" "$ARM" "$ALIAS" "$REP" "$EXIT_CODE" "$DURATION" \
        "$PROMPT_TOKENS" "$COMPLETION_TOKENS" "$FINISH_REASON" \
        "$VERDICT" "$QUALIFIER" "$EXTRACTED" "$EXPECTED_VAL" \
        "$STREAM_PATH" "$REQUESTS_THIS_CELL" "$RUNNING_TOTAL" "$MAX_TOKENS" "$RETRIED" \
        >> "$AB_TSV"

      echo "  -> exit=$EXIT_CODE dur=${DURATION}s prompt_tokens=$PROMPT_TOKENS completion_tokens=$COMPLETION_TOKENS max_tokens=$MAX_TOKENS finish_reason=$FINISH_REASON verdict=$VERDICT requests_this_cell=$REQUESTS_THIS_CELL running_total=$RUNNING_TOTAL retried=$RETRIED"
      CELL_COUNT=$((CELL_COUNT + 1))

      REP=$((REP + 1))
    done
  done
done

POSTFLIGHT_STATUS=0
postflight11 "$OUT_DIR" || POSTFLIGHT_STATUS=$?

{
  echo "cline_version_after=$(cat "$OUT_DIR/cline-version-after.txt" 2>/dev/null)"
  echo "ended_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cells_this_invocation=$CELL_COUNT"
  echo "aborted=$ABORTED"
  echo "postflight_status=$POSTFLIGHT_STATUS"
  echo "providers_json_drift_count=${DRIFT_COUNT:-0} (orchestrator-directed per-cell check+repair; see $OUT_DIR/providers-drift.tsv)"
} >> "$OUT_DIR/manifest.txt"

if [ "$ABORTED" -eq 1 ]; then
  echo "run_ab.sh: ABORTED -- see log above and $OUT_DIR/manifest.txt" >&2
  exit 1
fi
if [ "$POSTFLIGHT_STATUS" -ne 0 ]; then
  echo "run_ab.sh: postflight11 reported a HARD failure (status=$POSTFLIGHT_STATUS) -- see $OUT_DIR/postflight.txt" >&2
  exit "$POSTFLIGHT_STATUS"
fi

echo "=== run_ab.sh complete: $CELL_COUNT cell(s) run this invocation, $(wc -l < "$AB_TSV" | tr -d ' ') total data+header line(s) in $AB_TSV, providers.json drift repaired ${DRIFT_COUNT:-0}x this invocation ==="
exit 0
