#!/bin/bash
# phase-07/bench/verify_bench.sh -- re-runnable, read-only verifier over a cline-bench run
# directory. Standing gate for Phase 8 (same house `CHECK: PASS|FAIL <id>` + `CASES n/m`
# contract as phase-06/net/verify_network.sh / phase-05/services/verify_services.sh).
#
# Usage: verify_bench.sh [--run-dir <path>] [--out <transcript-path>]
#   --run-dir <path>  Defaults to $CURRENT_RUN_FILE's contents.
#   --out <path>      Optional: also tee the full transcript to this file. The ONLY thing this
#                      script ever writes besides that optional transcript.
#
# Exit code contract:
#   0 = every CHECK line PASSed
#   1 = at least one CHECK FAILed and nothing crashed
#   2 = this script itself could not complete (bad args, config.env missing) -- never a pass
#
# Read-only, by construction: no check below mutates the run directory, no check restarts a
# service, no check sends a signal, no check writes to the sandbox/network/services config this
# project already owns. The only sub-gate invoked (B7) is itself read-only
# (phase-03/sandbox/verify_sandbox.sh).
#
# macOS /bin/bash is 3.2 (no declare -A) -- no associative arrays used below.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "verify_bench.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

RUN_DIR_OVERRIDE=""
OUT_TRANSCRIPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir)
      RUN_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
    --out)
      OUT_TRANSCRIPT="${2:-}"
      shift 2
      ;;
    *)
      echo "verify_bench.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -n "$RUN_DIR_OVERRIDE" ]; then
  RUN="$RUN_DIR_OVERRIDE"
elif [ -f "$CURRENT_RUN_FILE" ] && [ -s "$CURRENT_RUN_FILE" ]; then
  RUN="$(cat "$CURRENT_RUN_FILE")"
else
  RUN="${CURRENT_RUN_FILE}.unset"
fi

if [ -n "$OUT_TRANSCRIPT" ]; then
  : > "$OUT_TRANSCRIPT"
  vlog() { printf '%s\n' "$@" | tee -a "$OUT_TRANSCRIPT"; }
else
  vlog() { printf '%s\n' "$@"; }
fi

PASSED=0
TOTAL=0
record() {
  # $1=id  $2=rc (0 pass / nonzero fail)  $3=detail (optional, printed on FAIL)
  # $4=pass_note (optional, appended to a PASS line -- e.g. B3's "(N task(s)
  # excused as fail-infra)" note, so an exemption is visible in the gate
  # output rather than silent, without ever printing two separate PASS
  # lines for the same check id).
  local id="$1" rc="$2" detail="${3:-}" pass_note="${4:-}"
  TOTAL=$((TOTAL + 1))
  if [ "$rc" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    if [ -n "$pass_note" ]; then
      vlog "CHECK: PASS $id $pass_note"
    else
      vlog "CHECK: PASS $id"
    fi
  else
    if [ -n "$detail" ]; then
      vlog "CHECK: FAIL $id -- $detail"
    else
      vlog "CHECK: FAIL $id"
    fi
  fi
}

vlog "=== phase-07/bench/verify_bench.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog "RUN=$RUN"
vlog ""

# ---------------------------------------------------------------------------
# B1: the run directory exists and config.json in it names harbor version,
# cline-bench SHA, model spec and BASE_URL.
# ---------------------------------------------------------------------------
vlog "--- B1: run directory + config.json ---"
if [ ! -d "$RUN" ]; then
  record "B1" 1 "run directory does not exist: $RUN"
elif [ ! -f "$RUN/config.json" ]; then
  record "B1" 1 "config.json missing under $RUN"
else
  B1_CHECK="$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print('PARSE-ERROR ' + str(e))
    sys.exit(1)
required = ['harbor_version', 'cline_bench_commit_sha', 'model_spec', 'base_url']
missing = [k for k in required if not d.get(k) or d.get(k) == 'unknown']
if missing:
    print('MISSING-FIELDS ' + ','.join(missing))
    sys.exit(1)
print('OK')
sys.exit(0)
" "$RUN/config.json" 2>&1)"
  if [ "$B1_CHECK" = "OK" ]; then
    record "B1" 0
  else
    record "B1" 1 "$B1_CHECK"
  fi
fi
vlog ""

# From here on, every check that walks meta/*.json degrades gracefully when
# the run directory itself is absent (the /nonexistent negative-control
# path) -- each individually reports FAIL rather than crashing the script,
# so a single missing run directory produces a full, honest FAIL sweep
# instead of an early script-level abort.
META_FILES=()
if [ -d "$RUN/meta" ]; then
  for f in "$RUN"/meta/*.json; do
    [ -f "$f" ] && META_FILES+=("$f")
  done
fi
META_COUNT="${#META_FILES[@]}"

# ---------------------------------------------------------------------------
# B2: meta/*.json count >= 1 and every one parses as JSON with a verdict in
# the allowed set.
# ---------------------------------------------------------------------------
vlog "--- B2: meta/*.json count >= 1, each parses, verdict in allowed set ---"
if [ "$META_COUNT" -lt 1 ]; then
  record "B2" 1 "meta/*.json count is $META_COUNT (need >= 1)"
else
  B2_BAD=""
  for f in "${META_FILES[@]}"; do
    V="$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('verdict', ''))
except Exception:
    print('PARSE-ERROR')
" "$f")"
    case "$V" in
      # fail-oom added 07-13 gap closure (classify_lib.sh's classify_verdict) --
      # distinguishes a memory/GPU exhaustion death with zero model turns from
      # both fail-context (a genuine MAX_KV_SIZE rejection) and the
      # zero-evidence fail-infra catch-all. Admitting it here is a vocabulary
      # widening only; it does not weaken this check for any existing verdict.
      pass|fail-task|fail-context|fail-oom|fail-infra) : ;;
      *) B2_BAD="$B2_BAD $(basename "$f")=$V;" ;;
    esac
  done
  if [ -z "$B2_BAD" ]; then
    record "B2" 0
  else
    record "B2" 1 "bad verdict/parse:$B2_BAD"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# B3: BCH-02 (prompt half). For EVERY task with a meta record:
#   prompts/<task>/instruction.md exists and is non-empty, AND
#   (prompts/<task>/agent-command.txt exists and is non-empty, OR
#    prompts/<task>/CAPTURE-GAPS.txt names the missing file AND that task's
#    meta verdict is fail-infra).
# The escape valve is scoped tight: instruction.md is unconditional (this
# phase copies it itself, before the run -- nothing harbor does can prevent
# that). The valve is accepted ONLY for fail-infra. agent/cline.txt (the
# transcript) is NEVER an acceptable substitute for agent-command.txt, valve
# or no valve -- a transcript alone does not satisfy BCH-02's prompt half.
# ---------------------------------------------------------------------------
vlog "--- B3: BCH-02 prompt half (instruction.md unconditional; agent-command.txt required unless excused as fail-infra) ---"
B3_FAIL=""
B3_EXCUSED=0
# Guarded with [ "$META_COUNT" -gt 0 ] before iterating: bash 3.2 (macOS
# /bin/bash) raises "unbound variable" on `"${ARR[@]}"` for a truly empty
# array under `set -u`, even though `${#ARR[@]}` itself is always safe.
if [ "$META_COUNT" -gt 0 ]; then
  for f in "${META_FILES[@]}"; do
    TASK_N="$(python3 -c "import json; print(json.load(open('$f')).get('task','?'))" 2>/dev/null)"
    VERDICT_N="$(python3 -c "import json; print(json.load(open('$f')).get('verdict','?'))" 2>/dev/null)"
    PDIR="$RUN/prompts/$TASK_N"

    if [ ! -s "$PDIR/instruction.md" ]; then
      B3_FAIL="$B3_FAIL $TASK_N:instruction.md-missing-or-empty;"
      continue
    fi

    if [ -s "$PDIR/agent-command.txt" ]; then
      continue
    fi

    # agent-command.txt missing/empty -- only acceptable if CAPTURE-GAPS.txt
    # names it AND this task's verdict is fail-infra. A transcript
    # (agent/cline.txt under jobs/) is NEVER accepted as a substitute here,
    # under the valve or otherwise -- deliberately not even consulted below.
    if [ "$VERDICT_N" = "fail-infra" ] && [ -f "$PDIR/CAPTURE-GAPS.txt" ] && grep -q 'agent-command.txt' "$PDIR/CAPTURE-GAPS.txt" 2>/dev/null; then
      B3_EXCUSED=$((B3_EXCUSED + 1))
      continue
    fi

    B3_FAIL="$B3_FAIL $TASK_N:agent-command.txt-missing-and-not-excused(verdict=$VERDICT_N);"
  done
fi
if [ "$META_COUNT" -ge 1 ] && [ -z "$B3_FAIL" ]; then
  if [ "$B3_EXCUSED" -gt 0 ]; then
    record "B3" 0 "" "($B3_EXCUSED task(s) excused as fail-infra)"
  else
    record "B3" 0
  fi
elif [ "$META_COUNT" -lt 1 ]; then
  record "B3" 1 "no meta records to check (META_COUNT=$META_COUNT)"
else
  record "B3" 1 "$B3_FAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# B4: BCH-02 (result half). For every task, jobs/<task>/**/verifier/
# reward.txt exists, or a CAPTURE-GAPS.txt explains why not.
# ---------------------------------------------------------------------------
vlog "--- B4: BCH-02 result half (verifier/reward.txt, or an explained gap) ---"
B4_FAIL=""
if [ "$META_COUNT" -gt 0 ]; then
  for f in "${META_FILES[@]}"; do
    TASK_N="$(python3 -c "import json; print(json.load(open('$f')).get('task','?'))" 2>/dev/null)"
    REWARD_FOUND="$(find "$RUN/jobs/$TASK_N" -path '*/verifier/reward.txt' 2>/dev/null | head -1)"
    if [ -n "$REWARD_FOUND" ]; then
      continue
    fi
    if [ -s "$RUN/prompts/$TASK_N/CAPTURE-GAPS.txt" ] && grep -qi 'reward' "$RUN/prompts/$TASK_N/CAPTURE-GAPS.txt" 2>/dev/null; then
      continue
    fi
    B4_FAIL="$B4_FAIL $TASK_N:no-reward.txt-and-no-explained-gap;"
  done
fi
if [ "$META_COUNT" -ge 1 ] && [ -z "$B4_FAIL" ]; then
  record "B4" 0
elif [ "$META_COUNT" -lt 1 ]; then
  record "B4" 1 "no meta records to check (META_COUNT=$META_COUNT)"
else
  record "B4" 1 "$B4_FAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# B5: BCH-03. summary.md exists, contains a table, and its DATA-row count
# (rows for tasks actually attempted -- i.e. excluding the "not-run" rows
# make_summary.sh's own <action> spec requires for every unattempted live
# task) equals the meta record count.
#
# WORDING NOTE (house rule 9 -- reported, not silently reconciled): this
# plan's <action> text for make_summary.sh requires "no task is ever
# omitted from the table" (every live-pool task gets a row, including a
# "not-run" row for tasks not attempted in this run directory), while this
# same plan's B5 text says the table's "data-row count equals the meta
# record count." Taken as a literal whole-table row count, those two
# requirements are mutually exclusive whenever any task is not-run (true
# for any partial run of the 12-task live pool). Resolution applied here,
# matching the precedent already set in 07-01's Task 3 SUMMARY (satisfy the
# literal, mechanically-checked count while preserving the substance):
# "data rows" = rows for tasks that were actually attempted (verdict !=
# not-run); the not-run rows remain in the table (required, and genuinely
# useful -- "no task ever omitted"), but are not counted as "data rows" for
# this specific equality check.
# ---------------------------------------------------------------------------
vlog "--- B5: BCH-03 (summary.md table; attempted-task data-row count == meta record count) ---"
if [ ! -s "$RUN/summary.md" ]; then
  record "B5" 1 "summary.md missing or empty"
else
  # Every markdown table line (header, separator, and every data row) starts
  # with "| " -- explicitly exclude the header line ("| task | ...") and the
  # "| --- | --- | ..." separator line by pattern, rather than a hardcoded
  # line-count subtraction that would silently drift if the table's own
  # formatting ever changes.
  TABLE_ALL_ROWS="$(grep -cE '^\| ' "$RUN/summary.md" | tr -d ' ')"
  TABLE_HEADER_ROWS="$(grep -cE '^\| task \|' "$RUN/summary.md" | tr -d ' ')"
  TABLE_SEP_ROWS="$(grep -cE '^\| --- \|' "$RUN/summary.md" | tr -d ' ')"
  TABLE_NOT_RUN_ROWS="$(grep -cE '^\| .* \| not-run \|' "$RUN/summary.md" | tr -d ' ')"
  ATTEMPTED_ROWS=$((TABLE_ALL_ROWS - TABLE_HEADER_ROWS - TABLE_SEP_ROWS - TABLE_NOT_RUN_ROWS))
  if [ "$TABLE_ALL_ROWS" -gt 0 ] && [ "$ATTEMPTED_ROWS" -eq "$META_COUNT" ]; then
    record "B5" 0
  else
    record "B5" 1 "attempted-rows=$ATTEMPTED_ROWS meta-count=$META_COUNT (raw-table-lines=$TABLE_ALL_ROWS not-run-rows=$TABLE_NOT_RUN_ROWS)"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# B6: server-log/<task>.flashnext.err.txt exists for every task.
# ---------------------------------------------------------------------------
vlog "--- B6: server-log/<task>.flashnext.err.txt exists for every task ---"
B6_FAIL=""
if [ "$META_COUNT" -gt 0 ]; then
  for f in "${META_FILES[@]}"; do
    TASK_N="$(python3 -c "import json; print(json.load(open('$f')).get('task','?'))" 2>/dev/null)"
    if [ ! -f "$RUN/server-log/$TASK_N.flashnext.err.txt" ]; then
      B6_FAIL="$B6_FAIL $TASK_N:server-log-missing;"
    fi
  done
fi
if [ "$META_COUNT" -ge 1 ] && [ -z "$B6_FAIL" ]; then
  record "B6" 0
elif [ "$META_COUNT" -lt 1 ]; then
  record "B6" 1 "no meta records to check (META_COUNT=$META_COUNT)"
else
  record "B6" 1 "$B6_FAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# B7: SBX-04 re-assertion -- phase-03's standing sandbox gate still exits 0
# and its SBX-04 criterion is PASS (bench/runs/CANARY.txt still unreadable
# from inside the sandbox after this phase wrote results next to it).
# ---------------------------------------------------------------------------
vlog "--- B7: phase-03/sandbox/verify_sandbox.sh (SBX-04 re-assertion) ---"
# A fixed tempdir, NOT under $RUN -- this check is a general standing-gate
# re-assertion independent of any one run directory, and must not fail
# merely because $RUN itself doesn't exist (e.g. the --run-dir /nonexistent
# negative control) or isn't writable.
B7_OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/verify_bench-b7-sandbox.XXXXXX")"
B7_OUT="$(bash "$PROJECT_ROOT/phase-03/sandbox/verify_sandbox.sh" --out-dir "$B7_OUT_DIR" 2>&1)"
B7_RC=$?
rm -rf "$B7_OUT_DIR" 2>/dev/null
B7_SBX04="$(printf '%s\n' "$B7_OUT" | grep -E '^CRITERION 4 ' | tail -1)"
case "$B7_SBX04" in
  *": PASS"*|*": PASS "*) B7_SBX04_OK=0 ;;
  *) B7_SBX04_OK=1 ;;
esac
if [ "$B7_RC" -eq 0 ] && [ "$B7_SBX04_OK" -eq 0 ]; then
  record "B7" 0
else
  record "B7" 1 "rc=$B7_RC ${B7_SBX04:-no CRITERION 4 line}"
fi
vlog ""

# ---------------------------------------------------------------------------
# B8: workspace/ALLOWED_REPOS.json repos[] still excludes bench/ and the
# repo root. Same wording-collision-aware parse as preflight.sh's P11
# (ALLOWED_REPOS.json's own _comment field legitimately contains the word
# "bench" while explaining SBX-04 -- a naive whole-file grep would be a
# permanent false positive).
# ---------------------------------------------------------------------------
vlog "--- B8: ALLOWED_REPOS.json repos[] excludes bench/ and the repo root ---"
ALLOWED_JSON="$PROJECT_ROOT/workspace/ALLOWED_REPOS.json"
B8_OUT="$(python3 - "$ALLOWED_JSON" "$PROJECT_ROOT" <<'PY'
import json, os, sys
path, project_root = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print("PARSE-ERROR " + str(e))
    sys.exit(1)
repos = data.get("repos", [])
project_real = os.path.realpath(project_root)
bad = []
for r in repos:
    real = os.path.realpath(r)
    if "bench" in r or "bench" in real:
        bad.append("bench-entry:" + r)
    if real == project_real:
        bad.append("repo-root-entry:" + r)
if bad:
    print("FAIL " + " ".join(bad))
    sys.exit(1)
print("OK entries=%d" % len(repos))
sys.exit(0)
PY
)"
B8_RC=$?
if [ "$B8_RC" -eq 0 ]; then
  record "B8" 0
else
  record "B8" 1 "$B8_OUT"
fi
vlog ""

# ---------------------------------------------------------------------------
# B9: bench/runs/CANARY.txt still exists with its original single line.
# ---------------------------------------------------------------------------
vlog "--- B9: bench/runs/CANARY.txt unchanged ---"
CANARY_PATH="$PROJECT_ROOT/bench/runs/CANARY.txt"
if [ -f "$CANARY_PATH" ] && [ "$(wc -l < "$CANARY_PATH" | tr -d ' ')" -le 1 ] && grep -q 'SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX' "$CANARY_PATH" 2>/dev/null; then
  record "B9" 0
else
  record "B9" 1 "CANARY.txt missing, multi-line, or content changed: $CANARY_PATH"
fi
vlog ""

# ---------------------------------------------------------------------------
# B10: port 3000 unbound; six pids present.
# ---------------------------------------------------------------------------
vlog "--- B10: port 3000 unbound; six live pids present ---"
B10_FAIL=""
P3000="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
if [ -n "$P3000" ]; then
  B10_FAIL="port-3000-bound:$P3000;"
fi
for i in "${!LIVE_PIDS[@]}"; do
  pid="${LIVE_PIDS[$i]}"
  label="${LIVE_PID_LABELS[$i]}"
  substr="${LIVE_PID_SUBSTR[$i]}"
  CMD="$(ps -ww -p "$pid" -o command= 2>/dev/null)"
  case "$CMD" in
    *"$substr"*) : ;;
    *) B10_FAIL="${B10_FAIL}${label}(pid=$pid missing-or-mismatched);" ;;
  esac
done
if [ -z "$B10_FAIL" ]; then
  record "B10" 0
else
  record "B10" 1 "$B10_FAIL"
fi
vlog ""

# ---------------------------------------------------------------------------
# B11: reached-the-model assertion (07-07 gap closure). At least one attempted task in this run
# directory has BOTH a non-zero-size server-log/<task>.flashnext.err.txt AND a meta/<task>.json
# with model_turns parsed as an integer > 0 -- the decisive signal, never a green exit code or a
# `pass` verdict alone.
#
# Opt-in per run directory: only evaluated when this run's own config.json names a POST-fix
# cw_injection value. The pre-fix bundle (bench/runs/20260830T093657Z-phase07/, cw_injection=
# "applied") legitimately and honestly has zero such tasks and must keep passing its own gate --
# so for a pre-fix (or missing/unknown) run directory this check is SKIPPED: visible in the
# output as its own CHECK line, but deliberately NOT routed through record() and therefore not
# counted toward PASSED/TOTAL, so it neither manufactures a false PASS nor breaks a pre-fix run
# directory's own honest CASES n/10 signature. Do not silently omit the line either way.
# ---------------------------------------------------------------------------
vlog "--- B11: reached-the-model (non-empty flashnext log slice + model_turns > 0; opt-in per run) ---"
B11_CW_INJECTION="unset"
if [ -f "$RUN/config.json" ]; then
  B11_CW_INJECTION="$(python3 -c "
import json
try:
    v = json.load(open('$RUN/config.json')).get('cw_injection', 'unset')
    print(v if v else 'unset')
except Exception:
    print('unset')
" 2>/dev/null)"
  [ -z "$B11_CW_INJECTION" ] && B11_CW_INJECTION="unset"
fi

case "$B11_CW_INJECTION" in
  applied|unset|"")
    vlog "CHECK: SKIP B11 -- cw_injection='$B11_CW_INJECTION' is a pre-fix (or absent) value; B11 only evaluates post-fix run directories and this line is not counted toward PASSED/TOTAL"
    ;;
  *)
    B11_OK=1
    B11_DETAIL=""
    if [ "$META_COUNT" -gt 0 ]; then
      for f in "${META_FILES[@]}"; do
        TASK_N="$(python3 -c "import json; print(json.load(open('$f')).get('task','?'))" 2>/dev/null)"
        SLICE="$RUN/server-log/$TASK_N.flashnext.err.txt"
        SLICE_BYTES=0
        [ -f "$SLICE" ] && SLICE_BYTES="$(wc -c < "$SLICE" | tr -d ' ')"
        TURNS="$(python3 -c "
import json
try:
    v = json.load(open('$f')).get('model_turns', 0)
    print(int(v))
except Exception:
    print(0)
" 2>/dev/null)"
        TURNS="${TURNS:-0}"
        B11_DETAIL="${B11_DETAIL}${TASK_N}:slice_bytes=${SLICE_BYTES},model_turns=${TURNS};"
        if [ "$SLICE_BYTES" -gt 0 ] 2>/dev/null && [ "$TURNS" -gt 0 ] 2>/dev/null; then
          B11_OK=0
        fi
      done
    fi
    if [ "$META_COUNT" -lt 1 ]; then
      record "B11" 1 "no meta records to check (META_COUNT=$META_COUNT); cw_injection='$B11_CW_INJECTION'"
    elif [ "$B11_OK" -eq 0 ]; then
      record "B11" 0
    else
      record "B11" 1 "no attempted task reached the model (slice_bytes>0 AND model_turns>0): $B11_DETAIL"
    fi
    ;;
esac
vlog ""

vlog "CASES $PASSED/$TOTAL"
if [ "$PASSED" -eq "$TOTAL" ]; then
  vlog "VERIFY_BENCH: PASS"
  exit 0
else
  vlog "VERIFY_BENCH: FAIL"
  exit 1
fi
