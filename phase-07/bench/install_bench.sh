#!/bin/bash
# phase-07/bench/install_bench.sh — idempotent installer for the
# cline-bench checkout + its pinned uv venv + harbor.
#
# Safe to re-run: a second run must change nothing and print `unchanged:`
# lines for the checkout. NEVER `git pull`s an existing checkout -- the
# commit SHA is this run's pin; a silent mid-phase update would invalidate
# whatever config.json a later run records against it.
#
# Reads phase-07/bench/config.env for every path/version constant. Writes
# nothing outside bench/cline-bench/ (the checkout itself, gitignored),
# uv's own tool/python dirs (outside this repo entirely), and its own
# --out <dir>.
#
# macOS /bin/bash is 3.2 (no declare -A) -- LIVE_PIDS/LIVE_PID_LABELS from
# config.env are parallel indexed arrays, walked by index.
#
# Usage: install_bench.sh --out <dir>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "install_bench.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

OUT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "install_bench.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done
if [ -z "$OUT_DIR" ]; then
  echo "install_bench.sh: FATAL -- --out <dir> is required" >&2
  exit 2
fi
mkdir -p "$OUT_DIR" 2>/dev/null
if [ ! -d "$OUT_DIR" ]; then
  echo "install_bench.sh: FATAL -- could not create $OUT_DIR" >&2
  exit 2
fi

LOG="$OUT_DIR/install-log.txt"
: > "$LOG"
vlog() { printf '%s\n' "$@" | tee -a "$LOG"; }
COMMANDS_RUN="$OUT_DIR/commands-run.txt"
: > "$COMMANDS_RUN"
record_cmd() { printf '%s\n' "$*" >> "$COMMANDS_RUN"; }

vlog "=== phase-07/bench/install_bench.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog "BENCH_REPO=$BENCH_REPO"
vlog ""

# ---------------------------------------------------------------------------
# Step 1: disk floor, re-checked here (preflight.sh already checked it once,
# but time may have passed and this is the step that actually pulls bytes).
# ---------------------------------------------------------------------------
DF_BEFORE_LINE="$(df -g "$PROJECT_ROOT" 2>/dev/null | tail -1)"
AVAIL_BEFORE="$(printf '%s\n' "$DF_BEFORE_LINE" | awk '{print $4}')"
vlog "disk free before: ${AVAIL_BEFORE:-unknown} GiB (floor ${MIN_FREE_GIB} GiB)"
if [ -z "${AVAIL_BEFORE:-}" ] || [ "$AVAIL_BEFORE" -lt "$MIN_FREE_GIB" ] 2>/dev/null; then
  vlog "FATAL: free disk ${AVAIL_BEFORE:-unknown} GiB below floor ${MIN_FREE_GIB} GiB -- aborting, nothing pulled"
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2 + 3: cline-bench checkout. Clone once; never pull an existing one.
# ---------------------------------------------------------------------------
mkdir -p "$BENCH_ROOT"
if [ -d "$BENCH_REPO/.git" ]; then
  vlog "unchanged: cline-bench checkout ($BENCH_REPO already has .git)"
else
  vlog "cloning $CLINE_BENCH_URL -> $BENCH_REPO"
  record_cmd "git clone \"$CLINE_BENCH_URL\" \"$BENCH_REPO\""
  if ! git clone "$CLINE_BENCH_URL" "$BENCH_REPO" >>"$LOG" 2>&1; then
    vlog "FATAL: git clone failed -- see $LOG"
    exit 2
  fi
fi

BENCH_SHA="$(git -C "$BENCH_REPO" rev-parse HEAD 2>/dev/null)"
BENCH_LOG_LINE="$(git -C "$BENCH_REPO" log -1 --date=iso --format='%H %cd %s' 2>/dev/null)"
vlog "cline-bench HEAD: $BENCH_SHA"
vlog "cline-bench log:  $BENCH_LOG_LINE"
printf '%s\n' "$BENCH_LOG_LINE" > "$OUT_DIR/cline-bench-commit.txt"

# ---------------------------------------------------------------------------
# Step 4: pinned python 3.13 venv. cline-bench requires exactly 3.13; host
# python3 is 3.14.x.
# ---------------------------------------------------------------------------
UV_VENV_DOWNLOAD="no"
if [ -d "$BENCH_REPO/.venv" ]; then
  vlog "unchanged: $BENCH_REPO/.venv already exists"
else
  vlog "creating uv venv --python 3.13 at $BENCH_REPO/.venv"
  record_cmd "uv venv --python 3.13 \"$BENCH_REPO/.venv\""
  UV_VENV_OUT="$(uv venv --python 3.13 "$BENCH_REPO/.venv" 2>&1)"
  UV_VENV_RC=$?
  printf '%s\n' "$UV_VENV_OUT" >> "$LOG"
  if [ "$UV_VENV_RC" -ne 0 ]; then
    vlog "FATAL: uv venv failed -- see $LOG"
    exit 2
  fi
  if printf '%s\n' "$UV_VENV_OUT" | grep -qi "Downloading"; then
    UV_VENV_DOWNLOAD="yes"
  fi
fi
vlog "python 3.13 interpreter downloaded this run: $UV_VENV_DOWNLOAD"
PY313_PATH="$(uv python find 3.13 2>/dev/null || true)"
vlog "python 3.13 interpreter path: ${PY313_PATH:-unknown}"

# ---------------------------------------------------------------------------
# Step 5: uv tool install harbor (idempotent by uv's own semantics).
# ---------------------------------------------------------------------------
vlog ""
vlog "installing harbor via uv tool install"
record_cmd "uv tool install harbor"
UV_TOOL_OUT="$(uv tool install harbor 2>&1)"
UV_TOOL_RC=$?
printf '%s\n' "$UV_TOOL_OUT" >> "$LOG"
if [ "$UV_TOOL_RC" -ne 0 ]; then
  vlog "FATAL: uv tool install harbor failed -- see $LOG"
  exit 2
fi
if printf '%s\n' "$UV_TOOL_OUT" | grep -qiE "already installed|unchanged"; then
  vlog "unchanged: harbor tool install"
else
  vlog "harbor tool install ran (installed or upgraded): see $LOG"
fi

# uv installs tools into an isolated tool venv (typically ~/.local/bin),
# NOT into the just-created project venv above -- this is normal uv
# behavior (`uv tool install` and `uv venv` are deliberately independent),
# not a failure.
HARBOR_BIN="$(command -v harbor 2>/dev/null || true)"
if [ -z "$HARBOR_BIN" ]; then
  # Not on PATH after install -- resolve the absolute path directly rather
  # than editing the user's shell profile.
  CANDIDATE="$HOME/.local/bin/harbor"
  if [ -x "$CANDIDATE" ]; then
    HARBOR_BIN="$CANDIDATE"
    vlog "harbor not on PATH; resolved absolute path: $HARBOR_BIN"
  else
    vlog "FATAL: harbor not found on PATH and not at $CANDIDATE"
    exit 2
  fi
else
  vlog "harbor resolved via PATH: $HARBOR_BIN"
fi

HARBOR_VERSION="$("$HARBOR_BIN" --version 2>&1)"
HARBOR_VERSION_RC=$?
vlog "harbor --version: $HARBOR_VERSION (rc=$HARBOR_VERSION_RC)"

UV_VERSION="$(uv --version 2>&1)"
vlog "uv --version: $UV_VERSION"

DF_AFTER_LINE="$(df -g "$PROJECT_ROOT" 2>/dev/null | tail -1)"
AVAIL_AFTER="$(printf '%s\n' "$DF_AFTER_LINE" | awk '{print $4}')"
vlog "disk free after: ${AVAIL_AFTER:-unknown} GiB"
DISK_DELTA="unknown"
if [ -n "${AVAIL_BEFORE:-}" ] && [ -n "${AVAIL_AFTER:-}" ]; then
  DISK_DELTA="$((AVAIL_BEFORE - AVAIL_AFTER))"
fi
vlog "measured disk delta (before-after, GiB, positive = consumed): $DISK_DELTA"

# ---------------------------------------------------------------------------
# Step 7: README.md
# ---------------------------------------------------------------------------
README="$OUT_DIR/README.md"
{
  echo "# phase-07/bench/install_bench.sh -- run $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Commands run"
  echo '```'
  cat "$COMMANDS_RUN"
  echo '```'
  echo
  echo "## cline-bench checkout"
  echo "- URL: $CLINE_BENCH_URL"
  echo "- path: $BENCH_REPO"
  echo "- commit: $BENCH_LOG_LINE"
  echo
  echo "## harbor"
  echo "- version: $HARBOR_VERSION"
  echo "- executable: $HARBOR_BIN"
  echo
  echo "## uv / python"
  echo "- uv version: $UV_VERSION"
  echo "- python 3.13 interpreter: ${PY313_PATH:-unknown}"
  echo "- python 3.13 interpreter downloaded this run: $UV_VENV_DOWNLOAD"
  echo
  echo "## Disk"
  echo "- free before: ${AVAIL_BEFORE:-unknown} GiB"
  echo "- free after: ${AVAIL_AFTER:-unknown} GiB"
  echo "- measured delta: $DISK_DELTA GiB"
  echo
  echo "## REMOVAL"
  echo
  echo "Complete, literal removal recipe for everything this script installs:"
  echo
  echo '```bash'
  echo "uv tool uninstall harbor"
  echo "rm -rf /Users/ohama/projs/cline-tests/bench/cline-bench"
  echo '```'
  echo
  echo "Deliberately NOT removed by that recipe: \`bench/runs/\` (this"
  echo "phase's own evidence, including \`bench/runs/CANARY.txt\`, the SBX-04"
  echo "sentinel) is never touched by this removal recipe."
  echo
  echo "Docker images pulled by task Dockerfiles (during a later plan's"
  echo "\`harbor run\`) are reclaimed separately with \`docker image prune\`."
  echo "This script never runs prune automatically -- that is a deliberate,"
  echo "separate decision for whoever is done using the images, not an"
  echo "incidental side effect of installing or removing harbor/cline-bench."
} > "$README"
vlog ""
vlog "wrote $README"

# ---------------------------------------------------------------------------
# Step 8: post-conditions.
# ---------------------------------------------------------------------------
vlog ""
vlog "--- post-condition assertions ---"
PID_OK=0
for i in "${!LIVE_PIDS[@]}"; do
  pid="${LIVE_PIDS[$i]}"
  label="${LIVE_PID_LABELS[$i]}"
  if ! ps -p "$pid" >/dev/null 2>&1; then
    PID_OK=1
    vlog "  PID CHANGED: $label pid=$pid no longer present"
  fi
done
if [ "$PID_OK" -eq 0 ]; then
  vlog "  six live pids: unchanged"
else
  vlog "  FATAL: a live pid changed during install"
fi

PORT3000="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
if [ -z "$PORT3000" ]; then
  vlog "  port 3000: unbound"
else
  vlog "  FATAL: port 3000 IS bound: $PORT3000"
  PID_OK=1
fi

cd "$PROJECT_ROOT"
GIT_BENCH_ENTRY="$(git status --short 2>/dev/null | grep 'bench/cline-bench' || true)"
if [ -z "$GIT_BENCH_ENTRY" ]; then
  vlog "  git status: no bench/cline-bench entry (gitignore working)"
else
  vlog "  FATAL: git status shows a bench/cline-bench entry: $GIT_BENCH_ENTRY"
  PID_OK=1
fi

vlog ""
vlog "RESULTS_DIR=$OUT_DIR"

if [ "$PID_OK" -ne 0 ]; then
  exit 2
fi
exit 0
