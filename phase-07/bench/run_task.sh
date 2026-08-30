#!/bin/bash
# phase-07/bench/run_task.sh -- one cline-bench task in, one committed evidence bundle out.
#
# Usage:
#   run_task.sh <task-dir-name-or-suffix> [--run-dir <path>] [--dry-run]
#
#   <task-dir-name-or-suffix>  Either the full ULID-prefixed task directory name
#                              (e.g. 01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror)
#                              or just its suffix (e.g. discord-trivia-approval-keyerror),
#                              resolved against $BENCH_REPO/tasks/.
#   --run-dir <path>           Override the run directory this task's evidence lands in.
#                              Default: $CURRENT_RUN_FILE's contents, or a freshly created
#                              bench/runs/<UTC>-phase07/ (whose path is then written to
#                              $CURRENT_RUN_FILE) -- ALL tasks in this phase land in ONE run
#                              directory unless --run-dir is explicitly overridden.
#   --dry-run                  Print the exact `harbor run` command this script WOULD run and
#                              exit 0. Creates no run directory, starts no container, invokes
#                              no pre-guards. Safe to call with zero model/cline/harbor budget.
#
# macOS /bin/bash is 3.2 (no declare -A) -- config.env's LIVE_PIDS/LIVE_PID_LABELS/
# LIVE_PID_SUBSTR are parallel indexed arrays walked by index, same idiom preflight.sh already
# uses. The executing shell is zsh; this script is always invoked as `bash run_task.sh ...`.
#
# House rule 4: this NEVER wraps `harbor run` in the project's sandbox-exec launcher script --
# harbor is a plain host process talking to Docker, not this project's own `cline` binary, so
# there is nothing for that wrapper to wrap (07-RESEARCH.md Pitfall 6).
#
# Exit code contract: 0 = evidence bundle complete (or already existed -- see skip-if-done).
# 1 = a pre-guard aborted before anything mutating happened, or a post-guard detected a
# regression during the run. 2 = usage/setup error (bad args, config.env missing, task not
# found).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "run_task.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

DRY_RUN=0
RUN_DIR_OVERRIDE=""
TASK_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir)
      RUN_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -*)
      echo "run_task.sh: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$TASK_ARG" ]; then
        TASK_ARG="$1"
        shift
      else
        echo "run_task.sh: unexpected extra argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$TASK_ARG" ]; then
  echo "run_task.sh: usage: run_task.sh <task-dir-name-or-suffix> [--run-dir <path>] [--dry-run]" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve the task directory under $BENCH_REPO/tasks/. Accepts either the
# full ULID-prefixed name or the bare suffix (config.env's own convention,
# e.g. SMOKE_SUFFIX).
# ---------------------------------------------------------------------------
TASKS_ROOT="$BENCH_REPO/tasks"
TASK_DIR_FULL=""

if [ -d "$TASKS_ROOT/$TASK_ARG" ]; then
  TASK_DIR_FULL="$TASK_ARG"
else
  MATCHES=()
  for d in "$TASKS_ROOT"/*"-$TASK_ARG"; do
    [ -d "$d" ] && MATCHES+=("$(basename "$d")")
  done
  if [ "${#MATCHES[@]}" -eq 1 ]; then
    TASK_DIR_FULL="${MATCHES[0]}"
  elif [ "${#MATCHES[@]}" -gt 1 ]; then
    echo "run_task.sh: FATAL -- '$TASK_ARG' matches multiple task dirs under $TASKS_ROOT: ${MATCHES[*]}" >&2
    exit 2
  fi
fi

if [ -z "$TASK_DIR_FULL" ]; then
  echo "run_task.sh: FATAL -- no task directory matching '$TASK_ARG' under $TASKS_ROOT" >&2
  exit 2
fi

# Canonical short name used for prompts/<TASK>, meta/<TASK>.json, etc. -- the
# suffix, regardless of which form the caller passed.
if [ "$TASK_ARG" = "$TASK_DIR_FULL" ]; then
  TASK="${TASK_DIR_FULL#*-}"
else
  TASK="$TASK_ARG"
fi

# ---------------------------------------------------------------------------
# The exact harbor invocation. Built once, used by both --dry-run (printed,
# never executed) and the real run (executed via `bash -c`, since it embeds
# inline env-var assignments the same way the plan's own <action> text does).
# ---------------------------------------------------------------------------
# No internal quoting around the individual values below -- every one of them
# (agent id, model spec, cline version, base url, api key placeholder) is a
# plain token with no spaces/shell-metacharacters, and this string doubles as
# the --dry-run output that must contain grep-checkable literal substrings
# like `-a cline-cli` and `BASE_URL=http://host.docker.internal:4000/v1`
# verbatim (a quote character immediately after `=` would break that).
build_harbor_cmd() {
  printf '%s' "cd $BENCH_REPO && API_KEY=$HARBOR_API_KEY BASE_URL=$HARBOR_BASE_URL harbor run -p tasks/$TASK_DIR_FULL -a $HARBOR_AGENT -m $HARBOR_MODEL_SPEC --agent-kwarg cline-version=$HARBOR_CLINE_VERSION $HARBOR_EXTRA_ARGS --env docker"
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "run_task.sh --dry-run: resolved task dir = $TASK_DIR_FULL (task=$TASK)"
  echo "DRY-RUN COMMAND:"
  build_harbor_cmd
  echo ""
  echo ""
  echo "DRY-RUN: no run directory created, no container started, no model/cline/harbor budget spent."
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. Run directory (real run only). All tasks in this phase land in ONE run
#    directory unless --run-dir overrides it.
# ---------------------------------------------------------------------------
if [ -n "$RUN_DIR_OVERRIDE" ]; then
  RUN="$RUN_DIR_OVERRIDE"
elif [ -f "$CURRENT_RUN_FILE" ] && [ -s "$CURRENT_RUN_FILE" ]; then
  RUN="$(cat "$CURRENT_RUN_FILE")"
else
  RUN="$RUNS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-phase07"
  mkdir -p "$RUN" 2>/dev/null
  printf '%s\n' "$RUN" > "$CURRENT_RUN_FILE"
fi
mkdir -p "$RUN/meta" "$RUN/prompts/$TASK" "$RUN/logs" "$RUN/jobs" "$RUN/server-log" 2>/dev/null

MANIFEST="$RUN/MANIFEST.txt"
manifest_add() { printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$MANIFEST"; }

# Run-level config.json -- written once per run directory (idempotent:
# skipped if already present), independent of which task triggers its
# creation. Names harbor version, cline-bench commit SHA, model spec and
# BASE_URL so verify_bench.sh (07-02 Task 3, check B1) can confirm this run
# directory identifies exactly what was run, matching the outer-wrapper
# shape ARCHITECTURE.md's own layout already anticipated for `bench/runs/`.
if [ ! -f "$RUN/config.json" ]; then
  CLINE_BENCH_SHA="$(git -C "$BENCH_REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
  HARBOR_VERSION_STR="$(harbor --version 2>/dev/null || echo unknown)"
  python3 - "$RUN/config.json" <<PYEOF
import json, sys
data = {
    "harbor_version": "$HARBOR_VERSION_STR",
    "cline_bench_commit_sha": "$CLINE_BENCH_SHA",
    "model_spec": "$HARBOR_MODEL_SPEC",
    "base_url": "$HARBOR_BASE_URL",
    "agent": "$HARBOR_AGENT",
    "cline_version": "$HARBOR_CLINE_VERSION",
    "cw_injection": "${CW_INJECTION:-unset}",
    "injection_mechanism": "${INJECTION_MECHANISM:-unset}",
    "injection_evidence": "${INJECTION_EVIDENCE:-unset}",
    "created_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  manifest_add "config.json (harbor version, cline-bench SHA, model spec, BASE_URL)"
fi

# Skip-if-done: makes the batch resumable after an interruption without
# re-burning model time.
if [ -f "$RUN/meta/$TASK.json" ]; then
  echo "unchanged: $TASK"
  exit 0
fi

echo "run_task.sh: RUN=$RUN TASK=$TASK TASK_DIR=$TASK_DIR_FULL"

# ---------------------------------------------------------------------------
# 2. Pre-guards. Abort (do not run) on any failure.
# ---------------------------------------------------------------------------
guard_fail() {
  echo "GUARD-FAIL: $1" >&2
  exit 1
}

# 2a. Six live pids present, by pid AND by expected command-line substring
#     (same two-oracle idiom preflight.sh's P1 already uses -- a pid alone
#     does not prove it is still the SAME process).
for i in "${!LIVE_PIDS[@]}"; do
  pid="${LIVE_PIDS[$i]}"
  label="${LIVE_PID_LABELS[$i]}"
  substr="${LIVE_PID_SUBSTR[$i]}"
  CMD="$(ps -ww -p "$pid" -o command= 2>/dev/null)"
  if [ -z "$CMD" ]; then
    guard_fail "pre-guard pid: $label pid=$pid MISSING"
  fi
  case "$CMD" in
    *"$substr"*) : ;;
    *) guard_fail "pre-guard pid: $label pid=$pid cmd does not contain '$substr': $CMD" ;;
  esac
done
echo "pre-guard: six live pids OK"

# 2b. Port 3000 unbound.
P3000="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
if [ -n "$P3000" ]; then
  guard_fail "pre-guard: port 3000 IS bound: $P3000"
fi
echo "pre-guard: port 3000 unbound OK"

# 2c. Free disk >= MIN_FREE_GIB.
DF_LINE="$(df -g "$PROJECT_ROOT" 2>/dev/null | tail -1)"
AVAIL_GIB="$(printf '%s\n' "$DF_LINE" | awk '{print $4}')"
if [ -z "${AVAIL_GIB:-}" ] || ! [ "$AVAIL_GIB" -ge "$MIN_FREE_GIB" ] 2>/dev/null; then
  guard_fail "pre-guard: free disk ${AVAIL_GIB:-unknown}GiB < floor ${MIN_FREE_GIB}GiB"
fi
echo "pre-guard: free disk ${AVAIL_GIB}GiB >= ${MIN_FREE_GIB}GiB OK"

# 2d. Task directory exists (already required by resolution above; re-assert
#     explicitly so this guard is visible in the transcript on its own).
if [ ! -d "$TASKS_ROOT/$TASK_DIR_FULL" ]; then
  guard_fail "pre-guard: task directory vanished: $TASKS_ROOT/$TASK_DIR_FULL"
fi
echo "pre-guard: task directory present OK"

# 2e. Server-side oracle log readable.
if [ ! -r "$FLASHNEXT_ERR_LOG" ]; then
  guard_fail "pre-guard: FLASHNEXT_ERR_LOG not readable: $FLASHNEXT_ERR_LOG"
fi
echo "pre-guard: FLASHNEXT_ERR_LOG readable OK"

# 2f. Pre-run injection assertion (07-07 gap closure). A run whose injection provably cannot
#     land must not cost harbor's ~4 minutes.
#
#     Branch B (CW_INJECTION=not-achievable): refuse unconditionally, before touching anything
#     else, and point at TERMINAL.md rather than attempting a mechanism 07-07 already recorded
#     as not working.
#
#     Branch A: replay the REAL compose merge (base + our overlay + harbor's own auto-generated
#     env/mounts override files) by calling injection_probe.sh's own R1 rung -- reused, never
#     copied -- and require it confirm the resolved config for the service harbor execs into
#     contains the mechanism's mount target and env var with a fully-resolved absolute source
#     path (R1's own has_env/has_mount checks, see injection_probe.sh). If R1 does not PASS,
#     `harbor run` cannot possibly reach the model this invocation -- exit non-zero WITHOUT
#     invoking it.
if [ "${CW_INJECTION:-unset}" = "not-achievable" ]; then
  guard_fail "pre-run assertion: CW_INJECTION=not-achievable -- see phase-07/results/*-injection-fix/TERMINAL.md for every mechanism tried and why; refusing to invoke harbor run"
fi

PREASSERT_DIR="$RUN/preassert/$TASK"
mkdir -p "$PREASSERT_DIR" 2>/dev/null
PREASSERT_OUT="$(bash "$SCRIPT_DIR/injection_probe.sh" --rung R1 --results-dir "$PREASSERT_DIR" 2>&1)"
PREASSERT_RC=$?
printf '%s\n' "$PREASSERT_OUT" > "$PREASSERT_DIR/R1-output.txt"
if [ "$PREASSERT_RC" -ne 0 ] || ! printf '%s\n' "$PREASSERT_OUT" | grep -q 'CHECK: PASS R1-compose-merge-replay'; then
  guard_fail "pre-run assertion: injection_probe.sh --rung R1 (compose-merge-replay) did not confirm the mechanism's mount+env resolve with a fully-resolved absolute source path -- see $PREASSERT_DIR/R1-output.txt; refusing to invoke harbor run (would cost ~4 minutes it cannot possibly reach the model with)"
fi
manifest_add "preassert/$TASK/ (pre-run compose-merge-replay assertion, reused injection_probe.sh --rung R1, rc=$PREASSERT_RC)"
echo "pre-guard: pre-run injection assertion (R1 compose-merge-replay) OK"

# ---------------------------------------------------------------------------
# 3. Server-log offset, BEFORE the run.
# ---------------------------------------------------------------------------
OFF_BEFORE="$(wc -c < "$FLASHNEXT_ERR_LOG" | tr -d ' ')"
echo "server-log offset before run: $OFF_BEFORE bytes"

# ---------------------------------------------------------------------------
# 4. Prompt capture, BEFORE the run, so it exists even if the run dies.
# ---------------------------------------------------------------------------
TASK_SRC="$TASKS_ROOT/$TASK_DIR_FULL"
cp "$TASK_SRC/instruction.md" "$RUN/prompts/$TASK/instruction.md"
manifest_add "prompts/$TASK/instruction.md (verbatim copy of instruction.md, pre-run)"
cp "$TASK_SRC/task.toml" "$RUN/prompts/$TASK/task.toml"
manifest_add "prompts/$TASK/task.toml (verbatim copy of task.toml, pre-run)"

: > "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"

# ---------------------------------------------------------------------------
# 5. The run. Timed. Exit code captured without set -e aborting (this
#    script never sets -e). NOT wrapped in the sandbox-exec launcher script (house rule 4).
# ---------------------------------------------------------------------------
RUN_START_EPOCH=$(date +%s)
JOBS_MARKER_EPOCH="$RUN_START_EPOCH"

HARBOR_CMD="$(build_harbor_cmd)"
echo "run_task.sh: invoking: $HARBOR_CMD"
manifest_add "logs/$TASK.harbor.log (tee of the harbor run invocation)"

bash -c "$HARBOR_CMD" 2>&1 | tee "$RUN/logs/$TASK.harbor.log"
HARBOR_RC="${PIPESTATUS[0]}"
RUN_END_EPOCH=$(date +%s)
WALL_CLOCK_SEC=$((RUN_END_EPOCH - RUN_START_EPOCH))
echo "run_task.sh: harbor exit code=$HARBOR_RC wall_clock=${WALL_CLOCK_SEC}s"

# ---------------------------------------------------------------------------
# 6. Post-guards. A regression here is a finding to record, not silently
#    absorb -- but it must not crash this script before step 9 writes the
#    meta record.
# ---------------------------------------------------------------------------
POST_GUARD_NOTES=""

P3000_AFTER="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
if [ -n "$P3000_AFTER" ]; then
  echo "POST-GUARD-FAIL: port 3000 became bound during the run: $P3000_AFTER" >&2
  POST_GUARD_NOTES="${POST_GUARD_NOTES}port-3000-bound-after-run:${P3000_AFTER};"
else
  echo "post-guard: port 3000 still unbound OK"
fi

for i in "${!LIVE_PIDS[@]}"; do
  pid="${LIVE_PIDS[$i]}"
  label="${LIVE_PID_LABELS[$i]}"
  substr="${LIVE_PID_SUBSTR[$i]}"
  CMD="$(ps -ww -p "$pid" -o command= 2>/dev/null)"
  case "$CMD" in
    *"$substr"*) : ;;
    *)
      echo "POST-GUARD-FAIL: $label pid=$pid changed/vanished (was cmd~='$substr', now='$CMD')" >&2
      POST_GUARD_NOTES="${POST_GUARD_NOTES}pid-changed:$label;"
      ;;
  esac
done
if [ -z "$POST_GUARD_NOTES" ]; then
  echo "post-guard: six live pids unchanged OK"
fi

# ---------------------------------------------------------------------------
# 7. Collect harbor's own output verbatim. Find the newest jobs/<timestamp>/
#    created since the run started.
#
# NOTE: NOT `-newermt "@$JOBS_MARKER_EPOCH"` (strict "newer than", one-second
# resolution on macOS/BSD find) -- observed live 2026-08-30, smoke run:
# harbor created jobs/2026-08-30__18-36-57/ at mtime 18:36:58, the SAME
# second (one second after) JOBS_MARKER_EPOCH was captured at 18:36:57,
# which a strict "newer than" comparison does not count as newer, so
# resolution silently found nothing and the whole evidence bundle (jobs/,
# agent-command.txt, system-prompt-probe.txt, reward/duration in meta.json)
# was lost even though harbor genuinely completed a job. Harbor's own job
# directory naming convention (`%Y-%m-%d__%H-%M-%S`) sorts lexicographically
# in creation order, so prefer that; guard against picking up a stale
# leftover directory from a much earlier invocation with a loose (30s)
# epoch sanity check derived from the directory's own name, not its mtime.
JOB_DIR=""
if [ -d "$BENCH_REPO/jobs" ]; then
  CANDIDATE="$(find "$BENCH_REPO/jobs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
  if [ -n "$CANDIDATE" ]; then
    CAND_NAME="$(basename "$CANDIDATE")"
    CAND_EPOCH="$(date -j -f '%Y-%m-%d__%H-%M-%S' "$CAND_NAME" +%s 2>/dev/null || echo 0)"
    if [ "$CAND_EPOCH" -ge $((JOBS_MARKER_EPOCH - 30)) ] 2>/dev/null; then
      JOB_DIR="$CANDIDATE"
    fi
  fi
fi

if [ -z "$JOB_DIR" ] || [ ! -d "$JOB_DIR" ]; then
  echo "MISSING $BENCH_REPO/jobs/<new-job-dir> (harbor produced no new job directory)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
  echo "MISSING jobs/$TASK (no harbor job directory copied)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
else
  mkdir -p "$RUN/jobs/$TASK"
  cp -R "$JOB_DIR"/. "$RUN/jobs/$TASK/" 2>/dev/null
  manifest_add "jobs/$TASK/ (verbatim copy of $JOB_DIR)"

  # Find the trial subdirectory for this task inside the copied job dir --
  # the only subdirectory that isn't harbor's own top-level config.json/result.json.
  TRIAL_DIR="$(find "$RUN/jobs/$TASK" -mindepth 1 -maxdepth 1 -type d | head -1)"

  if [ -n "$TRIAL_DIR" ] && [ -d "$TRIAL_DIR/agent" ]; then
    CMD_FILES="$(find "$TRIAL_DIR/agent" -mindepth 1 -maxdepth 1 -type d -name 'command-*' 2>/dev/null | sort)"
    if [ -n "$CMD_FILES" ]; then
      : > "$RUN/prompts/$TASK/agent-command.txt"
      for cd_ in $CMD_FILES; do
        if [ -f "$cd_/command.txt" ]; then
          {
            echo "=== $cd_/command.txt ==="
            cat "$cd_/command.txt"
            echo ""
          } >> "$RUN/prompts/$TASK/agent-command.txt"
        fi
      done
      if [ -s "$RUN/prompts/$TASK/agent-command.txt" ]; then
        manifest_add "prompts/$TASK/agent-command.txt (concatenation of agent/command-*/command.txt)"
      else
        rm -f "$RUN/prompts/$TASK/agent-command.txt"
        echo "MISSING prompts/$TASK/agent-command.txt (command-*/ dirs present but no command.txt files inside)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
      fi
    else
      # Fallback: harbor does not always create agent/command-*/ (observed
      # live 2026-08-30, smoke run -- a NonZeroAgentExitCodeError trial had
      # none), but the exact resolved `cline -P ... --json --yolo -- <prompt>`
      # invocation still appears verbatim in the trial's own trial.log, as
      # the single "Running command: ...cline -P ..." block up to the next
      # "Command outputs captured"/"Command failed" terminator. Extract that
      # block rather than silently leaving the prompt-capture requirement
      # unmet whenever a trial fails before harbor writes command-*/.
      if [ -f "$TRIAL_DIR/trial.log" ] && grep -q '^Running command:.*cline -P ' "$TRIAL_DIR/trial.log" 2>/dev/null; then
        {
          echo "=== extracted from $TRIAL_DIR/trial.log (no agent/command-*/ dirs present) ==="
          # -E (POSIX extended regex): BSD/macOS sed's default basic-regex
          # mode does NOT support GNU's `\|` alternation extension -- a bare
          # BRE `\|` between the two end patterns silently fails to match
          # either, so the range never closes and reads to EOF (observed
          # live 2026-08-30, smoke run backfill: agent-command.txt ran on
          # past the intended single command block into the next one).
          sed -n -E '/^Running command:.*cline -P /,/^(Command failed|Command outputs captured)$/p' "$TRIAL_DIR/trial.log"
        } > "$RUN/prompts/$TASK/agent-command.txt"
        if [ -s "$RUN/prompts/$TASK/agent-command.txt" ]; then
          manifest_add "prompts/$TASK/agent-command.txt (fallback: extracted from trial.log's 'Running command:' block -- no agent/command-*/ dirs this trial)"
        else
          rm -f "$RUN/prompts/$TASK/agent-command.txt"
          echo "MISSING prompts/$TASK/agent-command.txt (no agent/command-*/ directories, and trial.log extraction produced nothing)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
        fi
      else
        echo "MISSING prompts/$TASK/agent-command.txt (no agent/command-*/ directories in this trial, and trial.log has no matching 'cline -P' line)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
      fi
    fi

    if [ -f "$TRIAL_DIR/agent/cline.txt" ]; then
      {
        echo "# System-prompt probe over agent/cline.txt (case-insensitive grep, with line numbers)"
        grep -inE 'you are cline|<system>|system_prompt' "$TRIAL_DIR/agent/cline.txt" || echo "(no matches)"
      } > "$RUN/prompts/$TASK/system-prompt-probe.txt"
      if grep -qiE 'you are cline|<system>|system_prompt' "$TRIAL_DIR/agent/cline.txt"; then
        echo "SYSTEM_PROMPT_IN_TRANSCRIPT: yes" >> "$RUN/prompts/$TASK/system-prompt-probe.txt"
      else
        echo "SYSTEM_PROMPT_IN_TRANSCRIPT: no" >> "$RUN/prompts/$TASK/system-prompt-probe.txt"
      fi
      manifest_add "prompts/$TASK/system-prompt-probe.txt"
    else
      echo "MISSING agent/cline.txt (no transcript to probe for a system-prompt marker)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
    fi
  else
    echo "MISSING $TRIAL_DIR/agent/ (no trial/agent directory found under the copied job)" >> "$RUN/prompts/$TASK/CAPTURE-GAPS.txt"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Server-side oracle slice -- passive read of a log the model server
#    already writes. No service configuration is changed, nothing restarted.
#    NOTE: this log is shared across every surface hitting flashnext, so it
#    bounds rather than isolates this task's own turns.
# ---------------------------------------------------------------------------
tail -c +$((OFF_BEFORE + 1)) "$FLASHNEXT_ERR_LOG" > "$RUN/server-log/$TASK.flashnext.err.txt"
manifest_add "server-log/$TASK.flashnext.err.txt (byte-offset slice of \$FLASHNEXT_ERR_LOG for this task's wall-clock window)"

# NOTE: deliberately NOT `grep -c ... || echo 0` -- `grep -c` on zero
# matches already prints "0" to stdout but still exits 1 (no match found),
# which would make the `||` fallback print a SECOND "0" on its own line,
# turning this into a two-line value ("0\n0") that corrupts the meta.json
# heredoc below (observed live 2026-08-30, smoke run: "invalid syntax.
# Perhaps you forgot a comma?" at the model_turns line). `${VAR:-0}`
# catches the genuinely-empty case (file missing/unreadable) without
# double-counting grep's own legitimate "0".
MODEL_TURN_COUNT="$(grep -c 'Request completed:' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null)"
MODEL_TURN_COUNT="${MODEL_TURN_COUNT:-0}"
MAX_PROMPT_TOKENS="$(grep -oE 'prompt_tokens=[0-9]+' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
MAX_PROMPT_TOKENS="${MAX_PROMPT_TOKENS:-0}"

HTTP_400_SEEN=0
if grep -qE '\b400\b' "$RUN/server-log/$TASK.flashnext.err.txt" 2>/dev/null; then
  HTTP_400_SEEN=1
fi
if [ -n "${TRIAL_DIR:-}" ] && [ -f "$TRIAL_DIR/agent/cline.txt" ] && grep -qE '\b400\b' "$TRIAL_DIR/agent/cline.txt" 2>/dev/null; then
  HTTP_400_SEEN=1
fi

SYSTEM_PROMPT_IN_TRANSCRIPT="unknown"
if [ -f "$RUN/prompts/$TASK/system-prompt-probe.txt" ]; then
  if grep -q 'SYSTEM_PROMPT_IN_TRANSCRIPT: yes' "$RUN/prompts/$TASK/system-prompt-probe.txt"; then
    SYSTEM_PROMPT_IN_TRANSCRIPT="yes"
  else
    SYSTEM_PROMPT_IN_TRANSCRIPT="no"
  fi
fi

REWARD="null"
DURATION_SEC_JOBS="null"
if [ -n "${TRIAL_DIR:-}" ] && [ -f "$TRIAL_DIR/verifier/reward.txt" ]; then
  REWARD="$(tr -d '[:space:]' < "$TRIAL_DIR/verifier/reward.txt")"
fi
if [ -n "${TRIAL_DIR:-}" ] && [ -f "$TRIAL_DIR/result.json" ]; then
  DURATION_SEC_JOBS="$(python3 -c "import json,sys
try:
    print(json.load(open(sys.argv[1])).get('duration_sec','null'))
except Exception:
    print('null')" "$TRIAL_DIR/result.json" 2>/dev/null || echo "null")"
fi

# ---------------------------------------------------------------------------
# 9. Meta record. Verdict rule (auditable classification, exactly one of):
#      pass          reward == 1
#      fail-task     reward == 0 and no 400 and the agent visibly worked
#      fail-context  a 400 / context-window rejection is present, OR
#                     max_prompt_tokens >= 32768
#      fail-infra    harbor failed before any model request (image build,
#                     OOM, harness error) -- i.e. no model turns were seen
#                     at all in the server-log slice.
# ---------------------------------------------------------------------------
VERDICT="fail-infra"
if [ "$HTTP_400_SEEN" -eq 1 ] || [ "$MAX_PROMPT_TOKENS" -ge 32768 ] 2>/dev/null; then
  VERDICT="fail-context"
elif [ "$REWARD" = "1" ]; then
  VERDICT="pass"
elif [ "$REWARD" = "0" ] && [ "$MODEL_TURN_COUNT" -gt 0 ] 2>/dev/null; then
  VERDICT="fail-task"
elif [ "$MODEL_TURN_COUNT" -gt 0 ] 2>/dev/null; then
  # Model was reached and produced turns, but reward is missing/unparseable --
  # still not infra failure; treat conservatively as fail-task rather than
  # silently mislabeling it fail-infra.
  VERDICT="fail-task"
fi

DIFFICULTY="$(python3 -c "
import tomllib, sys
try:
    with open(sys.argv[1], 'rb') as f:
        d = tomllib.load(f)
    print(d.get('metadata', {}).get('difficulty', 'unknown'))
except Exception:
    print('unknown')
" "$TASK_SRC/task.toml" 2>/dev/null || echo "unknown")"
MEMORY_MB="$(python3 -c "
import tomllib, sys
try:
    with open(sys.argv[1], 'rb') as f:
        d = tomllib.load(f)
    print(d.get('environment', {}).get('memory_mb', 'null'))
except Exception:
    print('null')
" "$TASK_SRC/task.toml" 2>/dev/null || echo "null")"
TIMEOUT_SEC="$(python3 -c "
import tomllib, sys
try:
    with open(sys.argv[1], 'rb') as f:
        d = tomllib.load(f)
    print(d.get('agent', {}).get('timeout_sec', 'null'))
except Exception:
    print('null')
" "$TASK_SRC/task.toml" 2>/dev/null || echo "null")"

python3 - "$RUN/meta/$TASK.json" <<PYEOF
import json
data = {
    "task": "$TASK",
    "task_dir": "$TASK_DIR_FULL",
    "difficulty": "$DIFFICULTY",
    "memory_mb": $MEMORY_MB,
    "timeout_sec": $TIMEOUT_SEC,
    "harbor_exit_code": $HARBOR_RC,
    "wall_clock_sec": $WALL_CLOCK_SEC,
    "reward": ($REWARD if "$REWARD" not in ("null", "") else None),
    "duration_sec_jobs": ($DURATION_SEC_JOBS if "$DURATION_SEC_JOBS" != "null" else None),
    "model_turns": $MODEL_TURN_COUNT,
    "max_prompt_tokens": $MAX_PROMPT_TOKENS,
    "http_400_seen": $([ "$HTTP_400_SEEN" -eq 1 ] && echo True || echo False),
    "system_prompt_in_transcript": "$SYSTEM_PROMPT_IN_TRANSCRIPT",
    "post_guard_notes": "$POST_GUARD_NOTES",
    "verdict": "$VERDICT",
}
import sys
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
manifest_add "meta/$TASK.json (verdict=$VERDICT reward=$REWARD turns=$MODEL_TURN_COUNT max_prompt_tokens=$MAX_PROMPT_TOKENS)"

echo "run_task.sh: DONE task=$TASK verdict=$VERDICT reward=$REWARD wall_clock=${WALL_CLOCK_SEC}s"

if [ -n "$POST_GUARD_NOTES" ]; then
  echo "run_task.sh: WARNING -- post-guard regressions detected: $POST_GUARD_NOTES" >&2
  exit 1
fi

exit 0
