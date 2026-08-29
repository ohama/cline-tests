#!/usr/bin/env bash
# run_headless.sh — the shipped, one-shot headless `cline` wrapper (HLS-01/02/03).
#
# USAGE:
#   run_headless.sh [--out-dir <dir>] [--timeout <secs>] [--] <prompt>
#
# ENV:
#   HEADLESS_DRY=1        offline mode: copy a fixture NDJSON instead of invoking cline
#   DRY_FIXTURE=<path>    which fixture to copy under HEADLESS_DRY=1
#                         (default: phase-04/fixtures/success_no_tools.ndjson)
#   RESULTS_ROOT=<dir>    parent directory for the timestamped results dir
#                         (default: phase-04/results, from phase-04/config.env)
#   SKIP_SANDBOX_GATE=1   skip Preflight B (the standing sandbox gate) — for
#                         fast offline iteration only, never for a live run
#   WRAPPER_TIMEOUT=<s>   same as --timeout; --timeout wins if both given
#
# EXIT-CODE CONTRACT (inherited verbatim from phase-04/classify_run.py):
#   0 = success                       4 = run_aborted
#   2 = sandbox_denied                5 = context_overflow_terminal
#   3 = tty_approval_rejected         6 = other
#                                     7 = crashed / inconclusive
#   1 = preflight abort (this wrapper itself, before any classification)
#
# ---------------------------------------------------------------------------
# SHIPPED LIMITATION (stated, not hidden): in cline 3.0.53, `--auto-approve
# false` in `--json` / no-TTY mode does NOT pause for approval. It rejects
# EVERY tool call outright with `Tool "<name>" requires approval in a TTY
# session`, and the run self-aborts after a few iterations (see
# 04-RESEARCH.md Pitfall 2). This wrapper is therefore intentionally
# SAFE-BUT-INERT for tool-using prompts: it will refuse to act rather than
# act unsupervised. A prompt needing no tools completes normally. That is
# what HLS-02 taken literally produces; it is a real, shipped limitation, in
# scope for this milestone's one-shot smoke test, and it is Phase 5's to
# revisit when the surfaces go live. Do NOT "fix" it by flipping the flag.
#
# ---------------------------------------------------------------------------
# THE CWD RULE (04-RESEARCH.md Pitfall 1): the OS-level process cwd must be
# inside `workspace/ALLOWED_REPOS.json` or Bun dies at startup with a
# path-less generic error (`error: An unknown error occurred (Unexpected)`),
# before a single line of cline's own code runs. `cline -c/--cwd` is a
# SEPARATE, ADDITIONAL flag and does NOT substitute for the real process
# cwd. A future launchd/cron caller with no explicit `WorkingDirectory` will
# resurrect this exact crash, and it will look, superficially, identical to
# a sandbox tightening — hence the explicit assertion in step 5 below.
#
# ---------------------------------------------------------------------------
# `phase-04/verify_sandbox_via_cline.sh` (04-03) is a deliberately DIFFERENT,
# auto-approve-TRUE, TEST-ONLY invocation that proves the sandbox
# boundary (criterion 3) using a prompt that needs tool use to fail with
# EPERM. This wrapper must never call it, and must never itself pass the
# approve-all flag with a `true` value — this file's job is the
# safe-by-default shipped surface, not the sandbox-boundary proof.
#
# ---------------------------------------------------------------------------
# NEVER WIDEN THE SANDBOX FROM HERE. `phase-03/sandbox/config.env`'s
# `EXTRA_ALLOW_PATHS` is the only sanctioned widening point, it is empty,
# and this wrapper's cwd fix did not need it and never will. If a live run
# fails, this wrapper records a verdict — it does not reach for a
# punch-through. That boundary decision belongs to a human, not this script.
#
# ---------------------------------------------------------------------------
# macOS /bin/bash is 3.2: indexed arrays only, no `declare -A`. This script
# is bash — never source it from zsh (Phase 1 decision 01-05: zsh does not
# word-split unquoted flag variables the way bash does).

set -uo pipefail
# NOTE: deliberately NOT `set -e` around the live cline run — a non-zero
# cline exit code is DATA to be classified, exactly as
# phase-01/run_regression.sh documents. Preflight steps below still check
# their own exit codes explicitly and abort on failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Captured BEFORE step 5's `cd "$SANDBOX_WORKDIR"` so a relative DRY_FIXTURE
# (as every caller in this plan passes it, e.g. "phase-04/fixtures/x.ndjson"
# run from the repo root) resolves against the invocation cwd, not against
# the sandbox working directory we cd into later.
ORIG_PWD="$PWD"

# shellcheck source=config.env
source "$PROJECT_ROOT/phase-04/config.env"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/phase-01/config/cline-invocation.env"

RUN_SANDBOXED="$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh"

# ---- arg parsing ------------------------------------------------------------
OUT_DIR_FLAG=""
TIMEOUT_FLAG=""
PROMPT=""
PROMPT_SET=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out-dir)
      OUT_DIR_FLAG="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_FLAG="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ge 1 ]; then
  PROMPT="$1"
  PROMPT_SET=1
fi

if [ "$PROMPT_SET" -ne 1 ] || [ -z "$PROMPT" ]; then
  echo "Usage: run_headless.sh [--out-dir <dir>] [--timeout <secs>] [--] <prompt>" >&2
  exit 1
fi

WRAPPER_TIMEOUT="${TIMEOUT_FLAG:-${WRAPPER_TIMEOUT:-1800}}"

# ---- step 2: results directory ----------------------------------------------
# PID suffix (same convention as phase-01/run_regression.sh's "-$$") so two
# invocations landing in the same wall-clock second (observed live during
# this plan's Task 2 fixture loop) get distinct evidence directories instead
# of silently clobbering each other's ndjson.log/outcome.json.
if [ -n "$OUT_DIR_FLAG" ]; then
  RESULTS_DIR="$OUT_DIR_FLAG"
else
  RESULTS_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$-headless"
fi
mkdir -p "$RESULTS_DIR"

# From here on, ALL diagnostics go to stderr. stdout is reserved for NDJSON
# only, so a caller can pipe this wrapper straight into a parser.
echo "run_headless.sh: results dir: $RESULTS_DIR" >&2

# ---- step 3: Preflight A — config guard --------------------------------------
echo "=== Preflight A: config guard (verify_config.sh) ===" >&2
bash "$PROJECT_ROOT/phase-01/config/verify_config.sh" \
  2>&1 | tee "$RESULTS_DIR/config_pre.txt" >&2
A_STATUS="${PIPESTATUS[0]}"
if [ "$A_STATUS" -ne 0 ]; then
  echo "NOTICE: verify_config.sh failed (exit $A_STATUS) — healing via apply_provider_config.sh (Pitfall 5, expected)." >&2
  bash "$PROJECT_ROOT/phase-01/config/apply_provider_config.sh" >&2
  bash "$PROJECT_ROOT/phase-01/config/verify_config.sh" \
    2>&1 | tee -a "$RESULTS_DIR/config_pre.txt" >&2
  A_STATUS="${PIPESTATUS[0]}"
  if [ "$A_STATUS" -ne 0 ]; then
    echo "ABORT: providers.json still fails verify_config.sh after healing." >&2
    exit 1
  fi
fi

# ---- step 4: Preflight B — sandbox standing gate -----------------------------
if [ "${SKIP_SANDBOX_GATE:-0}" = "1" ]; then
  echo "=== Preflight B: sandbox gate SKIPPED (SKIP_SANDBOX_GATE=1) ===" >&2
else
  echo "=== Preflight B: sandbox standing gate (verify_sandbox.sh) ===" >&2
  bash "$PROJECT_ROOT/phase-03/sandbox/verify_sandbox.sh" --out-dir "$RESULTS_DIR/sandbox-gate" \
    2>&1 | tee "$RESULTS_DIR/sandbox-gate-console.txt" >&2
  B_STATUS="${PIPESTATUS[0]}"
  if [ "$B_STATUS" -ne 0 ]; then
    echo "ABORT: verify_sandbox.sh did not exit 0 (exit $B_STATUS) — refusing to trust run_sandboxed.sh." >&2
    exit 1
  fi
fi

# ---- step 5: working directory — THE CWD RULE --------------------------------
mkdir -p "$SANDBOX_WORKDIR"
cd "$SANDBOX_WORKDIR"

WORKDIR_OK="$(python3 -c '
import json, os, sys

pwd = os.path.realpath(sys.argv[1])
allowed_repos_json = sys.argv[2]

with open(allowed_repos_json) as f:
    data = json.load(f)

repos = data.get("repos", [])
for r in repos:
    rp = os.path.realpath(r)
    if pwd == rp or pwd.startswith(rp + os.sep):
        print("OK")
        sys.exit(0)

print("FAIL")
sys.exit(1)
' "$PWD" "$ALLOWED_REPOS_JSON")"
WORKDIR_STATUS=$?

{
  echo "PWD=$PWD"
  echo "ALLOWED_REPOS_JSON=$ALLOWED_REPOS_JSON"
  echo "WORKDIR_OK=$WORKDIR_OK"
} > "$RESULTS_DIR/workdir.txt"

if [ "$WORKDIR_STATUS" -ne 0 ] || [ "$WORKDIR_OK" != "OK" ]; then
  echo "ABORT: process cwd ($PWD) is not a prefix match of any repos[] entry in $ALLOWED_REPOS_JSON — refusing to invoke cline (THE CWD RULE, 04-RESEARCH.md Pitfall 1)." >&2
  exit 1
fi
echo "OK: cwd $PWD is inside the whitelist ($ALLOWED_REPOS_JSON)." >&2

# ---- step 6: the run ----------------------------------------------------------
if [ "${HEADLESS_DRY:-0}" = "1" ]; then
  DRY_FIXTURE="${DRY_FIXTURE:-$PROJECT_ROOT/phase-04/fixtures/success_no_tools.ndjson}"
  case "$DRY_FIXTURE" in
    /*) : ;;                                    # already absolute
    *) DRY_FIXTURE="$ORIG_PWD/$DRY_FIXTURE" ;;   # resolve against invocation cwd, not post-cd PWD
  esac
  echo "=== DRY RUN: copying $DRY_FIXTURE instead of invoking cline ===" >&2
  cp "$DRY_FIXTURE" "$RESULTS_DIR/ndjson.log"
  echo "DRY_RUN" > "$RESULTS_DIR/cline_exit.txt"
  : > "$RESULTS_DIR/stderr.log"
  CLINE_EXIT="DRY_RUN"
  # Deliberately NOT echoed to stdout: the classify pipeline (step 8) reads
  # ndjson.log from disk, not from stdout, so dry-run stdout stays empty —
  # correctly vacuous under the "stdout is NDJSON-only" contract even for
  # fixtures (e.g. crashed_truncated.ndjson) whose last line is deliberately
  # not valid JSON.
else
  echo "=== LIVE RUN: reinstall-chain then invoke cline under the sandbox (exactly ONE invocation per budget) ===" >&2
  npm install -g "cline@${CLINE_PINNED_VERSION}" >"$RESULTS_DIR/npm_pin.txt" 2>&1
  echo "npm install -g cline@${CLINE_PINNED_VERSION} — see $RESULTS_DIR/npm_pin.txt" >&2

  CLINE_NO_AUTO_UPDATE=1 "$RUN_SANDBOXED" -- "$CLINE_BIN" $CLINE_COMMON_FLAGS \
    --json --auto-approve false -t "$WRAPPER_TIMEOUT" -c "$SANDBOX_WORKDIR" "$PROMPT" \
    2>"$RESULTS_DIR/stderr.log" | tee "$RESULTS_DIR/ndjson.log"
  CLINE_EXIT="${PIPESTATUS[0]}"
  echo "$CLINE_EXIT" > "$RESULTS_DIR/cline_exit.txt"
  echo "NOTE: cline exited $CLINE_EXIT — this is DATA to be classified, not a wrapper failure." >&2
fi

# ---- step 7: post-run config guard --------------------------------------------
echo "=== Post-run config guard (verify_config.sh) ===" >&2
bash "$PROJECT_ROOT/phase-01/config/verify_config.sh" \
  2>&1 | tee "$RESULTS_DIR/config_post.txt" >&2
POST_STATUS="${PIPESTATUS[0]}"
HEALED="no"
if [ "$POST_STATUS" -ne 0 ]; then
  HEALED="yes"
  echo "NOTICE: verify_config.sh failed post-run (exit $POST_STATUS) — healing via apply_provider_config.sh (expected, not a failure)." >&2
  bash "$PROJECT_ROOT/phase-01/config/apply_provider_config.sh" >&2
  bash "$PROJECT_ROOT/phase-01/config/verify_config.sh" \
    2>&1 | tee -a "$RESULTS_DIR/config_post.txt" >&2
  POST_STATUS="${PIPESTATUS[0]}"
  if [ "$POST_STATUS" -ne 0 ]; then
    echo "WARNING: providers.json still fails verify_config.sh after post-run healing — investigate before the next run." >&2
  fi
fi
echo "healed=$HEALED post_status=$POST_STATUS" >> "$RESULTS_DIR/config_post.txt"

# ---- step 8: classify ----------------------------------------------------------
echo "=== Classifying $RESULTS_DIR/ndjson.log ===" >&2
CLINE_EXIT_ARG=""
if [ "$CLINE_EXIT" != "DRY_RUN" ]; then
  CLINE_EXIT_ARG="--exit-code $CLINE_EXIT"
fi

python3 "$PROJECT_ROOT/phase-04/classify_run.py" \
  --ndjson "$RESULTS_DIR/ndjson.log" \
  $CLINE_EXIT_ARG \
  --stderr "$RESULTS_DIR/stderr.log" \
  --out "$RESULTS_DIR" >&2
CLASSIFY_EXIT=$?

OUTCOME="unknown"
if [ -f "$RESULTS_DIR/outcome.json" ]; then
  OUTCOME="$(python3 -c "import json;print(json.load(open('$RESULTS_DIR/outcome.json'))['outcome'])" 2>/dev/null || echo unknown)"
fi

echo "RESULT: $OUTCOME — $RESULTS_DIR" >&2
exit "$CLASSIFY_EXIT"
