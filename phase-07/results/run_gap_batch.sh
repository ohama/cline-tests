#!/bin/bash
# One-shot driver for 07-09 Task 1: run the SELECTED_TASKS_GAP tasks sequentially into the
# post-fix run directory, with per-task pre-guards, resumability, and a ledger.
set -uo pipefail

cd /Users/ohama/projs/cline-tests
SCRIPT_DIR="phase-07/bench"
source "$SCRIPT_DIR/config.env"

RESULTS="$1"
mkdir -p "$RESULTS/logs"

CURRENT_RUN="$(cat "$CURRENT_RUN_FILE")"
echo "CURRENT_RUN=$CURRENT_RUN"

LEDGER="$RESULTS/ledger.tsv"
if [ ! -f "$LEDGER" ]; then
  printf 'task\tverdict\twall_clock_sec\tmodel_turns\tslice_bytes\tmax_prompt_tokens\n' > "$LEDGER"
fi

TASKS=()
while IFS= read -r line; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  TASKS+=("$line")
done < "$SCRIPT_DIR/SELECTED_TASKS_GAP"

for TASK in "${TASKS[@]}"; do
  echo "=================================================================="
  echo "TASK: $TASK  ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  echo "=================================================================="

  # Resumability: skip if a meta record already exists.
  if [ -f "$CURRENT_RUN/meta/$TASK.json" ]; then
    echo "SKIP (already has meta record): $TASK"
    continue
  fi

  # Re-check disk floor.
  DF_LINE="$(df -g "$PROJECT_ROOT" 2>/dev/null | tail -1)"
  AVAIL_GIB="$(printf '%s\n' "$DF_LINE" | awk '{print $4}')"
  if [ -z "${AVAIL_GIB:-}" ] || ! [ "$AVAIL_GIB" -ge "$MIN_FREE_GIB" ] 2>/dev/null; then
    echo "SKIP-AND-RECORD: disk floor breached before $TASK (${AVAIL_GIB:-unknown}GiB < ${MIN_FREE_GIB}GiB)" | tee -a "$RESULTS/CAPTURE-GAPS.txt"
    continue
  fi

  # Re-check six pids -- abort the whole batch if any is missing.
  PID_FAIL=""
  for i in "${!LIVE_PIDS[@]}"; do
    pid="${LIVE_PIDS[$i]}"
    label="${LIVE_PID_LABELS[$i]}"
    substr="${LIVE_PID_SUBSTR[$i]}"
    CMD="$(ps -ww -p "$pid" -o command= 2>/dev/null)"
    case "$CMD" in
      *"$substr"*) : ;;
      *) PID_FAIL="${PID_FAIL}${label}(pid=$pid missing-or-mismatched);" ;;
    esac
  done
  if [ -n "$PID_FAIL" ]; then
    echo "ABORT: live pid check failed before $TASK: $PID_FAIL" | tee -a "$RESULTS/CAPTURE-GAPS.txt"
    exit 1
  fi

  WALL_START=$(date +%s)
  bash phase-07/bench/run_task.sh "$TASK" 2>&1 | tee "$RESULTS/logs/$TASK.log"
  RC="${PIPESTATUS[0]}"
  WALL_END=$(date +%s)
  WALL_CLOCK=$((WALL_END - WALL_START))
  echo "$WALL_CLOCK" > "$RESULTS/logs/$TASK.wall_clock_sec"
  echo "run_task.sh exit code for $TASK: $RC (wall_clock=${WALL_CLOCK}s)"

  META_FILE="$CURRENT_RUN/meta/$TASK.json"
  if [ ! -f "$META_FILE" ]; then
    echo "CAPTURE-GAP: run_task.sh exited $RC for $TASK and no meta record was produced (harness-level failure, not a task verdict)" | tee -a "$RESULTS/CAPTURE-GAPS.txt"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$TASK" "NO-META-RECORD-rc=$RC" "$WALL_CLOCK" "-" "-" "-" >> "$LEDGER"
    continue
  fi

  VERDICT="$(python3 -c "import json; print(json.load(open('$META_FILE')).get('verdict','?'))")"
  MODEL_TURNS="$(python3 -c "import json; print(json.load(open('$META_FILE')).get('model_turns','?'))")"
  MAX_PROMPT_TOKENS="$(python3 -c "import json; print(json.load(open('$META_FILE')).get('max_prompt_tokens','?'))")"
  SLICE_FILE="$CURRENT_RUN/server-log/$TASK.flashnext.err.txt"
  SLICE_BYTES=0
  [ -f "$SLICE_FILE" ] && SLICE_BYTES="$(wc -c < "$SLICE_FILE" | tr -d ' ')"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$TASK" "$VERDICT" "$WALL_CLOCK" "$MODEL_TURNS" "$SLICE_BYTES" "$MAX_PROMPT_TOKENS" >> "$LEDGER"
  echo "LEDGER: $TASK verdict=$VERDICT wall_clock=${WALL_CLOCK}s model_turns=$MODEL_TURNS slice_bytes=$SLICE_BYTES max_prompt_tokens=$MAX_PROMPT_TOKENS"
done

echo "=================================================================="
echo "BATCH COMPLETE $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=================================================================="
