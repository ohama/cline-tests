#!/bin/bash
# phase-07/bench/make_summary.sh -- builds the BCH-03 pass/fail + duration table from harbor's
# own reward.txt/result.json (via run_task.sh's own meta/<task>.json records -- this script
# never re-derives pass/fail from a transcript or hand-writes a grader; it only reads what
# run_task.sh already extracted from verifier/reward.txt).
#
# Usage: make_summary.sh [--run-dir <path>]
#   --run-dir <path>  Defaults to $CURRENT_RUN_FILE's contents.
#
# Writes <RUN>/summary.md. Read-mostly: the only write this script performs is that one file.
#
# macOS /bin/bash is 3.2 (no declare -A) -- no associative arrays used below.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "make_summary.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

RUN_DIR_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir)
      RUN_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
    *)
      echo "make_summary.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -n "$RUN_DIR_OVERRIDE" ]; then
  RUN="$RUN_DIR_OVERRIDE"
elif [ -f "$CURRENT_RUN_FILE" ] && [ -s "$CURRENT_RUN_FILE" ]; then
  RUN="$(cat "$CURRENT_RUN_FILE")"
else
  echo "make_summary.sh: FATAL -- no --run-dir given and $CURRENT_RUN_FILE is absent/empty" >&2
  exit 2
fi

if [ ! -d "$RUN" ]; then
  echo "make_summary.sh: FATAL -- run directory does not exist: $RUN" >&2
  exit 2
fi

mkdir -p "$RUN/meta" 2>/dev/null

# ---------------------------------------------------------------------------
# Live facts, measured now (not a stale prior snapshot).
# ---------------------------------------------------------------------------
LIVE_TASK_POOL_SIZE="$(find "$BENCH_REPO/tasks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
CLINE_BENCH_SHA="$(git -C "$BENCH_REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
HARBOR_VERSION="$(harbor --version 2>/dev/null || echo unknown)"

META_COUNT=0
for f in "$RUN"/meta/*.json; do
  [ -f "$f" ] || continue
  META_COUNT=$((META_COUNT + 1))
done

if [ "$LIVE_TASK_POOL_SIZE" -gt 0 ] 2>/dev/null; then
  RUN_PCT="$(python3 -c "print(f'{100.0*$META_COUNT/$LIVE_TASK_POOL_SIZE:.1f}')" 2>/dev/null || echo "n/a")"
else
  RUN_PCT="n/a"
fi

# ---------------------------------------------------------------------------
# Reached-the-model count (07-09 gap closure, BCH-01 honesty): of the attempted tasks in THIS
# run directory, how many have BOTH a non-zero-size server-log/<task>.flashnext.err.txt slice
# AND a meta/<task>.json model_turns parsed as an integer > 0 -- the same decisive signal
# verify_bench.sh's B11 check already uses, computed here independently (never re-derives
# verdict/pass-fail from a transcript, only reads what run_task.sh already extracted). This
# number is distinct from META_COUNT ("how many ran") and must never be conflated with it.
# ---------------------------------------------------------------------------
REACHED_MODEL_COUNT=0
for f in "$RUN"/meta/*.json; do
  [ -f "$f" ] || continue
  R_TASK="$(python3 -c "import json; print(json.load(open('$f')).get('task','?'))" 2>/dev/null)"
  R_SLICE="$RUN/server-log/$R_TASK.flashnext.err.txt"
  R_SLICE_BYTES=0
  [ -f "$R_SLICE" ] && R_SLICE_BYTES="$(wc -c < "$R_SLICE" | tr -d ' ')"
  R_TURNS="$(python3 -c "
import json
try:
    v = json.load(open('$f')).get('model_turns', 0)
    print(int(v))
except Exception:
    print(0)
" 2>/dev/null)"
  R_TURNS="${R_TURNS:-0}"
  if [ "$R_SLICE_BYTES" -gt 0 ] 2>/dev/null && [ "$R_TURNS" -gt 0 ] 2>/dev/null; then
    REACHED_MODEL_COUNT=$((REACHED_MODEL_COUNT + 1))
  fi
done

OUT="$RUN/summary.md"

{
  echo "# Phase 7 cline-bench run summary"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Run directory: \`$RUN\`"
  echo ""
  echo "- Live task pool size (measured now, \`bench/cline-bench/tasks/\`): **${LIVE_TASK_POOL_SIZE}**"
  echo "- Tasks run in this directory: **${META_COUNT}** (${RUN_PCT}% of the live pool)"
  echo "- cline-bench commit SHA: \`${CLINE_BENCH_SHA}\`"
  echo "- harbor version: \`${HARBOR_VERSION}\`"
  echo "- Model spec: \`${HARBOR_MODEL_SPEC}\`"
  echo "- CW_INJECTION (contextWindow injection mechanism, see phase-07/bench/config.env and"
  echo "  07-02 Task 1's FINDING.md): \`${CW_INJECTION:-unset}\`"
  echo "- **Reached the model (non-empty flashnext server-log slice AND model_turns > 0) in this"
  echo "  directory: ${REACHED_MODEL_COUNT} of ${META_COUNT} attempted** -- this is the number"
  echo "  BCH-01's honesty depends on, distinct from how many tasks merely ran; see verify_bench.sh"
  echo "  check B11 for the same signal re-verified independently."
  echo ""
  echo "## Table"
  echo ""
  echo "| task | difficulty | verdict | reward | wall_clock_s | model_turns | max_prompt_tokens | note |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
} > "$OUT"

PASS_N=0
FAIL_TASK_N=0
FAIL_CONTEXT_N=0
FAIL_INFRA_N=0
NOT_RUN_N=0
TOTAL_WALL_CLOCK=0
RUN_TASK_NAMES_FILE="$(mktemp)"

for f in "$RUN"/meta/*.json; do
  [ -f "$f" ] || continue
  # Tab-separated (not "|||"-separated -- IFS-based `read` splits on each
  # individual character in a multi-char IFS, not the literal 3-char
  # sequence, which silently over-splits) single python3 parse per file.
  ROW="$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print('PARSE-ERROR\t' + str(e))
    sys.exit(0)
task = d.get('task', 'unknown')
difficulty = d.get('difficulty', 'unknown')
verdict = d.get('verdict', 'unknown')
reward = d.get('reward')
reward_s = 'null' if reward is None else str(reward)
wall = d.get('wall_clock_sec', 'null')
turns = d.get('model_turns', 'null')
maxp = d.get('max_prompt_tokens', 'null')
note = (d.get('post_guard_notes', '') or '').replace('\t', ' ')
print(f'{task}\t{difficulty}\t{verdict}\t{reward_s}\t{wall}\t{turns}\t{maxp}\t{note}')
" "$f")"

  if printf '%s' "$ROW" | grep -q '^PARSE-ERROR'; then
    echo "| $(basename "$f" .json) | - | - | - | - | - | - | PARSE-ERROR reading $f |" >> "$OUT"
    continue
  fi

  IFS=$'\t' read -r TASK_N DIFF VERDICT REWARD WALL TURNS MAXP NOTE <<< "$ROW"

  echo "| $TASK_N | $DIFF | $VERDICT | $REWARD | $WALL | $TURNS | $MAXP | ${NOTE:--} |" >> "$OUT"
  echo "$TASK_N" >> "$RUN_TASK_NAMES_FILE"

  case "$VERDICT" in
    pass) PASS_N=$((PASS_N + 1)) ;;
    fail-task) FAIL_TASK_N=$((FAIL_TASK_N + 1)) ;;
    fail-context) FAIL_CONTEXT_N=$((FAIL_CONTEXT_N + 1)) ;;
    fail-infra) FAIL_INFRA_N=$((FAIL_INFRA_N + 1)) ;;
  esac
  if [ "$WALL" != "null" ] && [ -n "$WALL" ]; then
    TOTAL_WALL_CLOCK=$((TOTAL_WALL_CLOCK + WALL))
  fi
done

# ---------------------------------------------------------------------------
# Tasks in the live pool that were NOT attempted in this run directory --
# every one gets its own "not-run" row, with a reason, never silently
# omitted.
# ---------------------------------------------------------------------------
for d in "$BENCH_REPO"/tasks/*/; do
  [ -d "$d" ] || continue
  DIR_NAME="$(basename "$d")"
  SUFFIX="${DIR_NAME#*-}"
  if grep -qxF "$SUFFIX" "$RUN_TASK_NAMES_FILE" 2>/dev/null || grep -qxF "$DIR_NAME" "$RUN_TASK_NAMES_FILE" 2>/dev/null; then
    continue
  fi
  REASON="not-run: not yet attempted in this run directory"
  case " $EXCLUDED_SUFFIXES " in
    *" $SUFFIX "*)
      REASON="not-run: excluded (see config.env EXCLUDED_SUFFIXES -- memory_mb exceeds colima's VM)"
      ;;
  esac
  DIFF_D="$(python3 -c "
import tomllib, sys
try:
    with open(sys.argv[1], 'rb') as f:
        t = tomllib.load(f)
    print(t.get('metadata', {}).get('difficulty', 'unknown'))
except Exception:
    print('unknown')
" "$d/task.toml" 2>/dev/null || echo unknown)"
  echo "| $SUFFIX | $DIFF_D | not-run | - | - | - | - | $REASON |" >> "$OUT"
  NOT_RUN_N=$((NOT_RUN_N + 1))
done

rm -f "$RUN_TASK_NAMES_FILE"

{
  echo ""
  echo "## Totals"
  echo ""
  echo "- pass: $PASS_N"
  echo "- fail-task: $FAIL_TASK_N"
  echo "- fail-context: $FAIL_CONTEXT_N"
  echo "- fail-infra: $FAIL_INFRA_N"
  echo "- not-run: $NOT_RUN_N"
  echo "- total wall-clock (attempted tasks only): ${TOTAL_WALL_CLOCK}s"
  echo ""
  echo "## 한계 (Limitations)"
  echo ""
  echo "A \`fail-context\` row proves the pipeline reached the model and the request was rejected"
  echo "by this stack's 32K ceiling because the container's Cline instance was unconfigured (see"
  echo "07-02 Task 1's FINDING.md) -- it is **NOT** evidence that this stack cannot complete agent"
  echo "tasks. A \`pass\` row is **NOT** evidence that the whole live task pool would pass; only"
  echo "the tasks actually attempted in this run directory are represented above, and \`not-run\`"
  echo "rows above name every task that was not."
} >> "$OUT"

echo "make_summary.sh: wrote $OUT ($META_COUNT attempted, $NOT_RUN_N not-run, pool=$LIVE_TASK_POOL_SIZE)"
exit 0
