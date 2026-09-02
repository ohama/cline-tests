#!/usr/bin/env bash
# probe_vrf04_cline.sh — Phase 10 Plan 05, Task 1.
#
# VRF-04: run the REAL `cline` binary (not curl) against `flashnext-plan` and
# a control alias, capture the complete raw `--json` NDJSON stream for each,
# and report -- as an observation, not a hypothesis test -- whether a
# reasoning event surfaces in Cline's own agent-loop output. Everything
# measured before this plan (CFG-16, VRF-01/02/03) used curl: that proves the
# GATEWAY forwards the injected parameters. It says nothing about whether
# Cline's own client code reads and surfaces them. Phase 9 never launched
# `cline` at all (GATE-VERDICT.md, deferral approved by the human) -- this is
# the first real-consumer exercise in the milestone.
#
# 🔴 VERSION DRIFT WARNING, load-bearing for how this script is written.
# Phase 9's source reading of the NDJSON shape (content_start / contentType
# ==reasoning / .event.reasoning) was made at cli-v3.0.53. The binary
# installed when this script was written reports 3.0.60 (CLINE_NO_AUTO_UPDATE
# does not reliably prevent this -- CFG-05, unresolved, carried to v1.2+).
# For this reason this script does NOT rely on one hardcoded jq path: it
# extracts via the documented v3.0.53 path AND independently via a
# text-level substring scan and an event-type histogram, so a renamed or
# renested field cannot silently read as "no reasoning" (a false negative,
# the expensive kind of error here).
#
# Outcome neutrality (ROADMAP criterion 6, VRF-04): a negative observation
# (no reasoning event in either stream) is a fully valid, satisfying result.
# This script never retries a run because its CONTENT was disappointing --
# only for an OPERATIONAL failure (non-zero exit, timeout, empty stream),
# and only once.
#
# bash 3.2 compatible (no declare -A, no ${var^^}).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib10.sh
source "$SCRIPT_DIR/probe_lib10.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root, so phase-10/results/... paths resolve

CURRENT_RUN_PTR="phase-10/results/CURRENT_VRF04_RUN"
LIVE_CFG_SHA="$(shasum -a 256 "$LIVE_CFG" | awk '{print $1}')"

# One fixed prompt, verbatim in every run -- short arithmetic, no tool call
# needed (so nothing can block on an approval prompt in a headless run), and
# identical across runs so the streams are actually comparable.
PROMPT="1부터 20까지의 소수를 모두 더하면 얼마인가? 계산 과정을 간단히 보이고 답을 마지막 줄에 써라."

# ---- wait_idle10: same pattern as probe_cfg16.sh -- confirm in_flight=0 ---
wait_idle10() {
  local attempt=0 idle_ok=0 last=""
  while [ "$attempt" -lt 10 ]; do
    last=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    case "$last" in
      *"in_flight=0"*) idle_ok=1; break ;;
    esac
    attempt=$((attempt + 1))
    sleep 3
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle before next cline invocation (last: $last)" >&2
    return 1
  fi
}

# ---- extract_run <run_label> <ndjson_log> ---------------------------------
# Writes reasoning-events-<run_label>.jsonl (documented v3.0.53 path),
# reasoning-textscan-<run_label>.jsonl (broad substring net),
# event-types-<run_label>.txt (histogram), final-text-tail-<run_label>.txt
# (best-effort peek, NOT authoritative -- schema is not assumed).
# Echoes one TSV row on stdout: run\tline_count\tdoc_events\tdoc_reasoning_chars\ttextscan_hits\tgrep_reasoning\tgrep_reasoning_content\tevent_types
extract_run() {
  local run_label="$1" ndjson_log="$2"
  local line_count doc_events doc_chars textscan_hits grep_r grep_rc event_types

  line_count=$(wc -l < "$ndjson_log" 2>/dev/null | tr -d ' ')
  [ -z "$line_count" ] && line_count=0

  # 1. The documented path (v3.0.53). May legitimately find 0 events if the
  #    shape moved in 3.0.60 -- that is exactly what the broader net below is
  #    for, not a reason to trust this path alone.
  jq -c 'select(.event.type=="content_start" and .event.contentType=="reasoning")' \
    "$ndjson_log" > "$RUN/reasoning-events-${run_label}.jsonl" 2>"$RUN/jq-doc-err-${run_label}.txt"
  doc_events=$(wc -l < "$RUN/reasoning-events-${run_label}.jsonl" 2>/dev/null | tr -d ' ')
  [ -z "$doc_events" ] && doc_events=0
  doc_chars=$(jq -s '[.[] | (.event.reasoning // "" | length)] | add // 0' \
    "$RUN/reasoning-events-${run_label}.jsonl" 2>/dev/null)
  [ -z "$doc_chars" ] && doc_chars=0

  # 2. Broader net: any line whose JSON, stringified, contains "reasoning"
  #    ANYWHERE -- independent of the documented path's structural assumption.
  jq -c 'select((tostring) | test("reasoning"))' "$ndjson_log" 2>"$RUN/jq-scan-err-${run_label}.txt" \
    | head -50 > "$RUN/reasoning-textscan-${run_label}.jsonl"
  textscan_hits=$(wc -l < "$RUN/reasoning-textscan-${run_label}.jsonl" 2>/dev/null | tr -d ' ')
  [ -z "$textscan_hits" ] && textscan_hits=0

  # Raw line-level grep counts, both spellings, no jq/JSON-shape assumption
  # at all -- the most shape-independent net available.
  grep_r=$(grep -c 'reasoning' "$ndjson_log" 2>/dev/null || true)
  [ -z "$grep_r" ] && grep_r=0
  grep_rc=$(grep -c 'reasoning_content' "$ndjson_log" 2>/dev/null || true)
  [ -z "$grep_rc" ] && grep_rc=0

  # Distinct .event.type values seen -- lets a reader tell "a stream that
  # carried no reasoning" from "a stream that carried nothing at all".
  jq -r '.event.type? // "NO_EVENT_TYPE"' "$ndjson_log" 2>/dev/null | sort | uniq -c \
    > "$RUN/event-types-${run_label}.txt"
  event_types=$(tr '\n' ';' < "$RUN/event-types-${run_label}.txt" | tr -s ' ' | sed 's/^;*//;s/;*$//')

  # Best-effort, NOT authoritative: any string value under any key literally
  # named "text" anywhere in the nested JSON, last few matches, as a peek at
  # what the assistant said. Schema is not assumed -- this is a convenience
  # for a human reader, not evidence.
  jq -r '.. | .text? // empty' "$ndjson_log" 2>/dev/null | tail -5 \
    > "$RUN/final-text-tail-${run_label}.txt"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$run_label" "$line_count" "$doc_events" "$doc_chars" "$textscan_hits" "$grep_r" "$grep_rc" "$event_types"
}

# ---- validate_ndjson <log> -> prints "OK" or "BAD:<n bad lines>" ----------
validate_ndjson() {
  local log="$1" total=0 bad=0
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    total=$((total + 1))
    if ! echo "$l" | jq -e . >/dev/null 2>&1; then
      bad=$((bad + 1))
    fi
  done < "$log"
  if [ "$bad" -eq 0 ]; then
    echo "OK (total=$total)"
  else
    echo "BAD:$bad (total=$total)"
  fi
}

echo "=== VRF-04: real cline execution against flashnext-plan + control ===" >&2

RUN="$(new_run_dir10 vrf04)"
echo "$RUN" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN" >&2

preflight10 "$RUN" || { echo "FATAL: preflight10 failed" >&2; exit 1; }

cline --version > "$RUN"/cline-version-before.txt 2>&1
echo "cline --version (before): $(cat "$RUN"/cline-version-before.txt)" >&2
shasum -a 256 "$PROVIDERS" > "$RUN"/providers-before.txt

printf 'run\thttp_or_exit\tduration_s\tline_count\tdoc_event_count\tdoc_reasoning_chars\ttextscan_hits\tgrep_reasoning\tgrep_reasoning_content\tevent_types\tnote\n' \
  > "$RUN"/vrf04.tsv

# ============================================================================
# Run 1 -- the subject: flashnext-plan (et-medium injected by the alias,
# nothing reasoning-related in the client body -- Cline never sends
# reasoning_effort/enable_thinking itself; the injection is entirely at the
# litellm alias-definition level, per REACH-PROOF.md).
# ============================================================================
echo "--- Run 1: flashnext-plan (subject) ---" >&2
wait_idle10 || { postflight10 "$RUN" "$LIVE_CFG_SHA" 0 || true; exit 1; }

T0=$(date +%s)
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan \
  --compaction agentic --json -t 600 "$PROMPT" \
  > "$RUN"/ndjson-plan.log 2> "$RUN"/stderr-plan.log
RC_PLAN=$?
T1=$(date +%s)
DUR_PLAN=$((T1 - T0))
echo "  exit=$RC_PLAN duration=${DUR_PLAN}s lines=$(wc -l < "$RUN"/ndjson-plan.log | tr -d ' ')" >&2

RETRIED_PLAN=0
if [ "$RC_PLAN" -ne 0 ] || [ ! -s "$RUN"/ndjson-plan.log ]; then
  echo "  OPERATIONAL FAILURE (exit=$RC_PLAN, empty=$([ -s "$RUN"/ndjson-plan.log ] && echo no || echo yes)) -- retrying ONCE" >&2
  mv "$RUN"/ndjson-plan.log "$RUN"/ndjson-plan-attempt1.log 2>/dev/null || true
  mv "$RUN"/stderr-plan.log "$RUN"/stderr-plan-attempt1.log 2>/dev/null || true
  wait_idle10 || true
  T0=$(date +%s)
  CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan \
    --compaction agentic --json -t 600 "$PROMPT" \
    > "$RUN"/ndjson-plan.log 2> "$RUN"/stderr-plan.log
  RC_PLAN=$?
  T1=$(date +%s)
  DUR_PLAN=$((T1 - T0))
  RETRIED_PLAN=1
  echo "  retry: exit=$RC_PLAN duration=${DUR_PLAN}s lines=$(wc -l < "$RUN"/ndjson-plan.log | tr -d ' ')" >&2
fi

FLAKE_PLAN=$(flake_window "$RUN")
if [ "$RC_PLAN" -eq 0 ] && [ -s "$RUN"/ndjson-plan.log ]; then
  VERDICT_PLAN=$(record_verdict "$RUN" "vrf04-plan" "expected" "$FLAKE_PLAN")
else
  VERDICT_PLAN=$(record_verdict "$RUN" "vrf04-plan" "unexpected" "$FLAKE_PLAN")
fi
echo "  verdict[plan] = $VERDICT_PLAN (flake=$FLAKE_PLAN, retried=$RETRIED_PLAN)" >&2

NDJSON_VALID_PLAN=$(validate_ndjson "$RUN"/ndjson-plan.log)
PLAN_ROW=$(extract_run "plan" "$RUN"/ndjson-plan.log)
printf '%s\t%s\t%s\t%s\n' "$PLAN_ROW" "$RC_PLAN" "$DUR_PLAN" "retried=$RETRIED_PLAN;ndjson_valid=$NDJSON_VALID_PLAN" \
  | awk -F'\t' 'BEGIN{OFS="\t"} {print $1,$9,$10,$2,$3,$4,$5,$6,$7,$8,$11}' >> "$RUN"/vrf04.tsv

sleep 2

# ============================================================================
# Run 2 -- the control: flashnext (unmodified, no reasoning params anywhere,
# neither client-sent nor alias-injected). Same prompt, sequential, never
# concurrent with run 1.
# ============================================================================
echo "--- Run 2: flashnext (control) ---" >&2
wait_idle10 || { postflight10 "$RUN" "$LIVE_CFG_SHA" 0 || true; exit 1; }

T0=$(date +%s)
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext \
  --compaction agentic --json -t 600 "$PROMPT" \
  > "$RUN"/ndjson-control.log 2> "$RUN"/stderr-control.log
RC_CTRL=$?
T1=$(date +%s)
DUR_CTRL=$((T1 - T0))
echo "  exit=$RC_CTRL duration=${DUR_CTRL}s lines=$(wc -l < "$RUN"/ndjson-control.log | tr -d ' ')" >&2

RETRIED_CTRL=0
if [ "$RC_CTRL" -ne 0 ] || [ ! -s "$RUN"/ndjson-control.log ]; then
  echo "  OPERATIONAL FAILURE (exit=$RC_CTRL, empty=$([ -s "$RUN"/ndjson-control.log ] && echo no || echo yes)) -- retrying ONCE" >&2
  mv "$RUN"/ndjson-control.log "$RUN"/ndjson-control-attempt1.log 2>/dev/null || true
  mv "$RUN"/stderr-control.log "$RUN"/stderr-control-attempt1.log 2>/dev/null || true
  wait_idle10 || true
  T0=$(date +%s)
  CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext \
    --compaction agentic --json -t 600 "$PROMPT" \
    > "$RUN"/ndjson-control.log 2> "$RUN"/stderr-control.log
  RC_CTRL=$?
  T1=$(date +%s)
  DUR_CTRL=$((T1 - T0))
  RETRIED_CTRL=1
  echo "  retry: exit=$RC_CTRL duration=${DUR_CTRL}s lines=$(wc -l < "$RUN"/ndjson-control.log | tr -d ' ')" >&2
fi

FLAKE_CTRL=$(flake_window "$RUN")
if [ "$RC_CTRL" -eq 0 ] && [ -s "$RUN"/ndjson-control.log ]; then
  VERDICT_CTRL=$(record_verdict "$RUN" "vrf04-control" "expected" "$FLAKE_CTRL")
else
  VERDICT_CTRL=$(record_verdict "$RUN" "vrf04-control" "unexpected" "$FLAKE_CTRL")
fi
echo "  verdict[control] = $VERDICT_CTRL (flake=$FLAKE_CTRL, retried=$RETRIED_CTRL)" >&2

NDJSON_VALID_CTRL=$(validate_ndjson "$RUN"/ndjson-control.log)
CTRL_ROW=$(extract_run "control" "$RUN"/ndjson-control.log)
printf '%s\t%s\t%s\t%s\n' "$CTRL_ROW" "$RC_CTRL" "$DUR_CTRL" "retried=$RETRIED_CTRL;ndjson_valid=$NDJSON_VALID_CTRL" \
  | awk -F'\t' 'BEGIN{OFS="\t"} {print $1,$9,$10,$2,$3,$4,$5,$6,$7,$8,$11}' >> "$RUN"/vrf04.tsv

# ============================================================================
# Run 3 -- OPTIONAL bonus: flashnext-act. Only if both above completed
# cleanly (exit 0, nonempty) and the model is idle. Skipped without penalty
# per the plan -- flashnext-act's own construction rationale
# (ALIAS-DESIGN.md §5) already predicts indistinguishability from flashnext,
# and REACH-PROOF.md §5 already confirmed delta=0 by curl; a third live
# cline invocation here would spend budget without adding to what VRF-04
# specifically needs (a subject + a true control), so it is skipped and
# recorded as skipped rather than run reflexively.
# ============================================================================
echo "--- Run 3 (flashnext-act): SKIPPED -- bonus only, not required by VRF-04 or ROADMAP criterion 6; flashnext already serves as the control; budget kept to the required 2 runs ---" >&2
printf 'act\tSKIPPED\t0\t0\t0\t0\t0\t0\t0\tNO_EVENT_TYPE\tskipped-by-design;see-script-comment\n' >> "$RUN"/vrf04.tsv

echo "" >&2
echo "=== vrf04.tsv ===" >&2
column -t -s $'\t' "$RUN"/vrf04.tsv >&2 || cat "$RUN"/vrf04.tsv >&2

cline --version > "$RUN"/cline-version-after.txt 2>&1
echo "cline --version (after): $(cat "$RUN"/cline-version-after.txt)" >&2
shasum -a 256 "$PROVIDERS" > "$RUN"/providers-after.txt

if ! diff -q "$RUN"/cline-version-before.txt "$RUN"/cline-version-after.txt >/dev/null 2>&1; then
  echo "VERSION DRIFT DETECTED mid-run: before=$(cat "$RUN"/cline-version-before.txt) after=$(cat "$RUN"/cline-version-after.txt) -- the comparison spanned two binaries" \
    | tee -a "$RUN"/vrf04.tsv >&2
else
  echo "cline --version stable across the whole run: $(cat "$RUN"/cline-version-before.txt)" >&2
fi

if ! diff -q "$RUN"/providers-before.txt "$RUN"/providers-after.txt >/dev/null 2>&1; then
  echo "FATAL: providers.json sha256 changed during this script's run -- HARD constraint violated" >&2
  diff "$RUN"/providers-before.txt "$RUN"/providers-after.txt >&2 || true
  exit 1
fi
echo "providers.json sha256 unchanged: $(awk '{print $1}' "$RUN"/providers-before.txt)" >&2

postflight10 "$RUN" "$LIVE_CFG_SHA" 0 || { echo "FATAL: postflight10 failed (see $RUN/postflight.txt)" >&2; exit 1; }

echo "" >&2
echo "=== VRF-04 probe done. See $RUN/vrf04.tsv, ndjson-{plan,control}.log, verdicts.tsv ===" >&2
