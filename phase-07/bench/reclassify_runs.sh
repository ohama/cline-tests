#!/bin/bash
# phase-07/bench/reclassify_runs.sh -- offline re-classification of a stored
# cline-bench run directory, using the corrected verdict rule in classify_lib.sh,
# from PRESERVED EVIDENCE ONLY (server-log slices, agent/cline.txt transcripts,
# verifier/reward.txt). Never invokes harbor/cline, never touches a live service.
#
# `meta/` is read-only evidence: this script asserts its own output path can never
# resolve inside it, and writes sidecars to `<run-dir>/meta-reclassified/<task>.json`
# instead. Idempotent -- the output contains no timestamp or other run-varying
# field, so re-running produces byte-identical files.
#
# Usage: reclassify_runs.sh --run-dir <dir>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
# Same shared rule run_task.sh uses -- see classify_lib.sh's header for why this
# file exists and phase-07/results/<UTC>-reclassify/RECLASSIFICATION.md for the
# old-vs-new verdict this script produced for every stored run instance.
source "$SCRIPT_DIR/classify_lib.sh"

RUN_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir)
      RUN_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "reclassify_runs.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$RUN_DIR" ]; then
  echo "reclassify_runs.sh: usage: reclassify_runs.sh --run-dir <dir>" >&2
  exit 2
fi
if [ ! -d "$RUN_DIR" ]; then
  echo "reclassify_runs.sh: FATAL -- run dir not found: $RUN_DIR" >&2
  exit 2
fi
if [ ! -d "$RUN_DIR/meta" ]; then
  echo "reclassify_runs.sh: FATAL -- $RUN_DIR/meta not found (nothing to re-classify)" >&2
  exit 2
fi

RUN_DIR_ABS="$(cd "$RUN_DIR" && pwd)"
META_ABS="$RUN_DIR_ABS/meta"
OUT_DIR="$RUN_DIR_ABS/meta-reclassified"

# Hard assertion: the sidecar output directory must never resolve inside meta/.
# meta/*.json is the original evidence this whole plan is forbidden from mutating
# (07-13-PLAN.md constraint) -- fail loudly rather than silently overwriting it.
case "$OUT_DIR" in
  "$META_ABS"|"$META_ABS"/*)
    echo "reclassify_runs.sh: FATAL -- refusing to write output inside meta/ ($OUT_DIR)" >&2
    exit 2
    ;;
esac

mkdir -p "$OUT_DIR"

COUNT=0
CHANGED_COUNT=0

for META_FILE in "$RUN_DIR_ABS"/meta/*.json; do
  [ -f "$META_FILE" ] || continue
  TASK="$(basename "$META_FILE" .json)"

  OLD_VERDICT="$(python3 -c "
import json
print(json.load(open('$META_FILE')).get('verdict', '?'))
" 2>/dev/null)"
  OLD_VERDICT="${OLD_VERDICT:-?}"

  SERVERLOG="$RUN_DIR_ABS/server-log/$TASK.flashnext.err.txt"
  [ -f "$SERVERLOG" ] || SERVERLOG=""

  TRIAL_DIR=""
  if [ -d "$RUN_DIR_ABS/jobs/$TASK" ]; then
    TRIAL_DIR="$(find "$RUN_DIR_ABS/jobs/$TASK" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -1)"
  fi

  TRANSCRIPT=""
  if [ -n "$TRIAL_DIR" ] && [ -f "$TRIAL_DIR/agent/cline.txt" ]; then
    TRANSCRIPT="$TRIAL_DIR/agent/cline.txt"
  fi

  # Independently re-derived from stored evidence -- NOT trusted from the
  # original meta/*.json record, per this plan's "derive from stored evidence"
  # requirement.
  MODEL_TURN_COUNT="$(count_model_turns "$SERVERLOG")"
  REWARD="$(read_reward "$TRIAL_DIR")"

  MAXKV_S="$(count_maxkv_rejections "$SERVERLOG")"
  MAXKV_T="$(count_maxkv_rejections "$TRANSCRIPT")"
  OOM="$(count_oom_failures "$SERVERLOG")"
  ACCEPTED="$(max_prompt_tokens_accepted "$SERVERLOG")"
  ATTEMPTED="$(max_prompt_tokens_attempted "$SERVERLOG" "$TRANSCRIPT")"

  NEW_VERDICT="$(classify_verdict "$MAXKV_S" "$MAXKV_T" "$OOM" "$REWARD" "$MODEL_TURN_COUNT")"

  CHANGED="False"
  if [ "$OLD_VERDICT" != "$NEW_VERDICT" ]; then
    CHANGED="True"
    CHANGED_COUNT=$((CHANGED_COUNT + 1))
  fi

  python3 - "$OUT_DIR/$TASK.json" <<PYEOF
import json
data = {
    "task": "$TASK",
    "supersedes": "meta/$TASK.json",
    "old_verdict": "$OLD_VERDICT",
    "verdict": "$NEW_VERDICT",
    "changed": $CHANGED,
    "model_turns": $MODEL_TURN_COUNT,
    "reward": ($REWARD if "$REWARD" not in ("null", "") else None),
    "max_prompt_tokens_accepted": $ACCEPTED,
    "max_prompt_tokens_attempted": $ATTEMPTED,
    "maxkv_rejections_serverlog": $MAXKV_S,
    "maxkv_rejections_transcript": $MAXKV_T,
    "oom_failures": $OOM,
}
import sys
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

  COUNT=$((COUNT + 1))
  echo "reclassify_runs.sh: $TASK old=$OLD_VERDICT new=$NEW_VERDICT changed=$CHANGED"
done

echo "reclassify_runs.sh: wrote $COUNT record(s) to $OUT_DIR ($CHANGED_COUNT changed)"
exit 0
