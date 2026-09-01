#!/usr/bin/env bash
# probe_prb03_oracle.sh — Phase 9 Plan 02, Task 1.
#
# Re-measures the PRB-03 prompt_tokens oracle from scratch: a fixed request
# body ("hi", max_tokens=4, :8011 direct) with only reasoning_effort /
# enable_thinking varying, six arms:
#   unspecified, medium, low, xhigh, et-true, et-medium
#
# et-true / et-medium were added 2026-09-01 when the alias design changed:
# `flashnext-plan` will ship enable_thinking:true + reasoning_effort:medium
# together (CFG-11), not effort alone, so the oracle must cover that shipped
# combination (et-medium) and its enable_thinking-alone control (et-true,
# which tests VALIDATED.md sec4's claim that enable_thinking:true == xhigh).
#
# Unlike 09-RESEARCH.md's `tail -N` attribution (which infers "this response
# belongs to this request" from ordering -- silently wrong if Kanban/Telegram
# fire a concurrent request into the same window), every sample here is
# attributed by an explicit log watermark: record wc -l immediately before
# firing, read only the lines appended since, and require EXACTLY ONE
# "Prefill started" line in that window before trusting its prompt_tokens.
#
# The sweep runs twice back-to-back (A, B) -- not for statistical noise
# (prompt_tokens is a deterministic function of tokenized text) but to catch
# the gpu-stream flake or any incidental drift. If A and B disagree on any
# arm, that disagreement IS the finding: this script runs a third sweep (C)
# and leaves all three on the record rather than picking a winner.
#
# This script does NOT declare a gate verdict (PRB-03 is not a gate). It also
# deliberately leaves postflight() uncalled -- Task 2 (probe_multiturn_growth.py)
# reuses this same run directory and calls postflight once, at the very end of
# the whole plan's burst.
#
# NOTE: written for macOS's default /bin/bash (3.2, no `declare -A`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib.sh
source "$SCRIPT_DIR/probe_lib.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root, so phase-09/results/... paths resolve

CURRENT_RUN_PTR="phase-09/results/CURRENT_PRB03_RUN"
ARMS="unspecified medium low xhigh et-true et-medium"
ATTEMPT_MAX=3

wait_idle() {
  local attempt=0 idle_ok=0 last=""
  while [ "$attempt" -lt 10 ]; do
    last=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    if [[ "$last" == *"in_flight=0"* ]]; then
      idle_ok=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle before next probe (last: $last)" >&2
    return 1
  fi
}

# build_prb03_body <arm> -> echoes the fixed-shape JSON body for that arm.
# Only reasoning_effort/enable_thinking presence+value vary; everything else
# (model, single "hi" user message, max_tokens=4) is held fixed across the
# whole sweep -- that is what isolates the effort-driven part of prompt_tokens.
build_prb03_body() {
  local arm="$1"
  case "$arm" in
    unspecified)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4}"
      ;;
    medium)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"reasoning_effort\":\"medium\"}"
      ;;
    low)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"reasoning_effort\":\"low\"}"
      ;;
    xhigh)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"reasoning_effort\":\"xhigh\"}"
      ;;
    et-true)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"enable_thinking\":true}"
      ;;
    et-medium)
      echo "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"enable_thinking\":true,\"reasoning_effort\":\"medium\"}"
      ;;
    *)
      echo "FATAL: unknown arm '$arm'" >&2
      return 1
      ;;
  esac
}

# run_prb03_request <sweep-label: A|B|C> <arm>
# Fires one request, attributes it to its own "Prefill started" log line via
# watermark (not tail -N), retries on 0-match or >=2-match (bounded at
# ATTEMPT_MAX attempts total), appends a row to prb03.tsv and (on success) the
# matched line to sweep-lines.txt, then closes with flake_window+record_verdict.
run_prb03_request() {
  local sweep="$1" arm="$2"
  local body body_file
  body="$(build_prb03_body "$arm")"
  body_file="$RUN_DIR/raw-prb03-${sweep}-${arm}.json"

  local attempt=1 http_code="" prompt_tokens="" matched_line="" match_count=0 ok=0

  while [ "$attempt" -le "$ATTEMPT_MAX" ]; do
    wait_idle
    local mark
    mark=$(wc -l < "$FLASHNEXT_LOG" | tr -d ' ')

    http_code=$(curl -s -o "$body_file" -w '%{http_code}' http://localhost:8011/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -d "$body")

    # Small settle so the async server-side log write for this request has
    # landed before we read "the lines appended since $mark".
    sleep 0.3

    local new_lines
    new_lines=$(sed -n "$((mark + 1)),\$p" "$FLASHNEXT_LOG")
    match_count=$(printf '%s\n' "$new_lines" | grep -c 'Prefill started' || true)

    if [ "$http_code" = "200" ] && [ "$match_count" -eq 1 ]; then
      matched_line=$(printf '%s\n' "$new_lines" | grep 'Prefill started')
      prompt_tokens=$(printf '%s\n' "$matched_line" | grep -oE 'prompt_tokens=[0-9]+' | cut -d= -f2)
      ok=1
      break
    fi

    if [ "$match_count" -eq 0 ]; then
      echo "  [$sweep-$arm] attempt $attempt: http=$http_code, 0 Prefill-started lines in window -- retrying" >&2
    elif [ "$match_count" -ge 2 ]; then
      echo "  [$sweep-$arm] attempt $attempt: http=$http_code, $match_count Prefill-started lines in window -- another tenant's request landed here, attribution ambiguous, discarding and retrying" >&2
    else
      echo "  [$sweep-$arm] attempt $attempt: http=$http_code -- retrying" >&2
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  printf '%s\t%s\t%s\t%s\t%s\n' "$sweep" "$arm" "$http_code" "${prompt_tokens:-}" "${matched_line:-}" >> "$RUN_DIR/prb03.tsv"

  if [ "$ok" -eq 1 ]; then
    echo "$matched_line" >> "$RUN_DIR/sweep-lines.txt"
  fi

  local flake_state verdict
  flake_state=$(flake_window "$RUN_DIR")
  if [ "$ok" -eq 1 ]; then
    verdict=$(record_verdict "$RUN_DIR" "prb03-${sweep}-${arm}" "expected" "$flake_state")
  else
    verdict=$(record_verdict "$RUN_DIR" "prb03-${sweep}-${arm}" "indeterminate" "")
  fi
  echo "  [$sweep-$arm] http=$http_code prompt_tokens=${prompt_tokens:-N/A} match_count_final=$match_count verdict=$verdict (attempts=$attempt)" >&2

  sleep 1
}

run_sweep() {
  local sweep_label="$1"
  local arm
  for arm in $ARMS; do
    run_prb03_request "$sweep_label" "$arm"
  done
}

echo "=== PRB-03 oracle: six-arm sweep, run twice (A, B) ===" >&2

RUN_DIR="$(new_run_dir prb03)"
echo "$RUN_DIR" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN_DIR" >&2

preflight "$RUN_DIR"

printf 'sweep\tarm\thttp_code\tprompt_tokens\tmatched_line\n' > "$RUN_DIR/prb03.tsv"
: > "$RUN_DIR/sweep-lines.txt"

run_sweep A
run_sweep B

# Sweep A vs sweep B agreement check. prompt_tokens is a deterministic function
# of tokenized text (no sampling involved), so the null hypothesis is zero
# variance -- but this is exactly what a single sweep could never itself prove.
MISMATCH=0
{
  echo "=== sweep A vs sweep B agreement ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
} > "$RUN_DIR/sweep-ab-compare.txt"
for arm in $ARMS; do
  a_val=$(awk -F'\t' -v s="A" -v e="$arm" '$1==s && $2==e {print $4}' "$RUN_DIR/prb03.tsv")
  b_val=$(awk -F'\t' -v s="B" -v e="$arm" '$1==s && $2==e {print $4}' "$RUN_DIR/prb03.tsv")
  if [ "$a_val" != "$b_val" ]; then
    echo "MISMATCH arm=$arm A=$a_val B=$b_val" | tee -a "$RUN_DIR/sweep-ab-compare.txt" >&2
    MISMATCH=1
  else
    echo "agree    arm=$arm A=$a_val B=$b_val" >> "$RUN_DIR/sweep-ab-compare.txt"
  fi
done
echo "$MISMATCH" > "$RUN_DIR/sweep-ab-mismatch.txt"

if [ "$MISMATCH" -eq 1 ]; then
  echo "Sweep A/B disagreement detected -- running a third sweep (C) per plan instructions; all three will be reported, no winner picked." >&2
  {
    echo "sweep A/B disagreed on at least one arm -- running sweep C. See prb03.tsv rows labeled C."
  } >> "$RUN_DIR/sweep-ab-compare.txt"
  run_sweep C
else
  echo "Sweep A and sweep B agree on all $(echo "$ARMS" | wc -w | tr -d ' ') arms." >&2
fi

echo "=== PRB-03 sweep done. postflight() intentionally deferred to Task 2 (probe_multiturn_growth.py), which reuses $RUN_DIR ===" >&2
echo "See $RUN_DIR/prb03.tsv, $RUN_DIR/sweep-lines.txt, $RUN_DIR/sweep-ab-compare.txt, $RUN_DIR/verdicts.tsv" >&2
