#!/bin/bash
# phase-07/bench/preflight.sh — the standing Phase 7 pre-install gate.
#
# Purpose: Phase 7 is the only phase that installs third-party software on
# this machine and the only phase that drives real load through the shared
# model server. This script proves every gate this project already owns is
# green, plus Phase-7-specific facts (disk, colima, docker, sandbox
# exclusion), BEFORE a single byte of harbor/cline-bench is installed. If
# any check fails, install_bench.sh must not run.
#
# Strictly read-only, re-runnable: this script starts nothing, stops
# nothing, installs nothing, mutates no plist/config/whitelist. It only
# invokes each project's own already-standing gate script and a handful of
# read-only probes (ps, lsof, df, colima list, docker info). It never
# invokes harbor, docker run, or cline.
#
# macOS /bin/bash is 3.2 (no declare -A) — config.env's LIVE_PIDS/
# LIVE_PID_LABELS/LIVE_PID_SUBSTR are parallel indexed arrays, walked by
# index only, same idiom verify_sandbox.sh/verify_services.sh/
# verify_network.sh already established.
#
# Usage:
#   preflight.sh [--out <dir>] [--baseline <path>]
#
#   --out <dir>       tee the full transcript here (default:
#                      phase-07/results/<UTC>-preflight)
#   --baseline <path> overrides config.env's NET_BASELINE for check P5
#                      ONLY. This flag exists solely so this gate's own
#                      negative control can prove P5 is able to FAIL (house
#                      rule 10 — a gate that cannot fail proves nothing). It
#                      is never passed during a real preflight run.
#
# Exit code contract (this script's OWN contract — distinct from the
# per-check 0/1/2 discipline the sub-gates it calls use internally):
#   0 = all eleven CHECK lines PASSed
#   1 = at least one CHECK FAILed, nothing about this script itself crashed
#   2 = this script itself could not complete (e.g. config.env missing,
#       python3 missing, OUT_DIR not writable) — never report as a pass
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "preflight.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

if ! command -v python3 >/dev/null 2>&1; then
  echo "preflight.sh: FATAL -- python3 not on PATH" >&2
  exit 2
fi

OUT_DIR=""
BASELINE_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --baseline)
      BASELINE_OVERRIDE="${2:-}"
      shift 2
      ;;
    *)
      echo "preflight.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-preflight"
fi
mkdir -p "$OUT_DIR" 2>/dev/null
if [ ! -d "$OUT_DIR" ]; then
  echo "preflight.sh: FATAL -- could not create $OUT_DIR" >&2
  exit 2
fi

TRANSCRIPT="$OUT_DIR/preflight-transcript.txt"
: > "$TRANSCRIPT"

vlog() { printf '%s\n' "$@" | tee -a "$TRANSCRIPT"; }

# EFFECTIVE_BASELINE: the value P5 actually uses. Only ever differs from
# config.env's NET_BASELINE when --baseline was explicitly passed (the
# negative-control path).
EFFECTIVE_BASELINE="${BASELINE_OVERRIDE:-$NET_BASELINE}"

PASSED=0
TOTAL=0
record() {
  # $1=id  $2=rc (0 pass / nonzero fail)  $3=detail (optional, printed on FAIL)
  local id="$1" rc="$2" detail="${3:-}"
  TOTAL=$((TOTAL + 1))
  if [ "$rc" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    vlog "CHECK: PASS $id"
  else
    if [ -n "$detail" ]; then
      vlog "CHECK: FAIL $id -- $detail"
    else
      vlog "CHECK: FAIL $id"
    fi
  fi
}

vlog "=== phase-07/bench/preflight.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog "PROJECT_ROOT=$PROJECT_ROOT"
vlog "EFFECTIVE_BASELINE=$EFFECTIVE_BASELINE (override=${BASELINE_OVERRIDE:-none})"
vlog ""

# ---------------------------------------------------------------------------
# P1: six live pids present, by pid AND by expected process-name substring.
# A pid existing alone does not prove it is still the SAME process (pids
# get reused) -- the command-line substring is the second, independent
# oracle.
# ---------------------------------------------------------------------------
vlog "--- P1: six live pids (pid + command substring) ---"
P1_RC=0
P1_DETAIL=""
for i in "${!LIVE_PIDS[@]}"; do
  pid="${LIVE_PIDS[$i]}"
  label="${LIVE_PID_LABELS[$i]}"
  substr="${LIVE_PID_SUBSTR[$i]}"
  CMD="$(ps -ww -p "$pid" -o command= 2>/dev/null)"
  if [ -z "$CMD" ]; then
    P1_RC=1
    P1_DETAIL="$P1_DETAIL $label(pid=$pid MISSING);"
    vlog "  $label pid=$pid: MISSING"
    continue
  fi
  case "$CMD" in
    *"$substr"*)
      vlog "  $label pid=$pid: present, cmd matches '$substr'"
      ;;
    *)
      P1_RC=1
      P1_DETAIL="$P1_DETAIL $label(pid=$pid cmd-mismatch expected='$substr');"
      vlog "  $label pid=$pid: PRESENT BUT cmd does not contain '$substr' -- $CMD"
      ;;
  esac
done
record "P1-live-pids" "$P1_RC" "$P1_DETAIL"
vlog ""

# ---------------------------------------------------------------------------
# P2: port 3000 stays unbound, always.
# ---------------------------------------------------------------------------
vlog "--- P2: port 3000 unbound ---"
P2_OUT="$(lsof -nP -iTCP:3000 -sTCP:LISTEN 2>/dev/null || true)"
if [ -z "$P2_OUT" ]; then
  record "P2-port-3000-unbound" 0
else
  record "P2-port-3000-unbound" 1 "port 3000 IS bound: $P2_OUT"
fi
vlog ""

# ---------------------------------------------------------------------------
# P3: phase-05 standing services gate.
# ---------------------------------------------------------------------------
vlog "--- P3: phase-05/services/verify_services.sh ---"
P3_OUT="$(bash "$PROJECT_ROOT/phase-05/services/verify_services.sh" --out-dir "$OUT_DIR/p3-services" 2>&1)"
P3_RC=$?
printf '%s\n' "$P3_OUT" > "$OUT_DIR/p3-verify_services.txt"
P3_CASES="$(printf '%s\n' "$P3_OUT" | grep -E '^CASES ' | tail -1)"
vlog "  rc=$P3_RC ${P3_CASES:-no CASES line}"
record "P3-verify-services" "$P3_RC" "rc=$P3_RC ${P3_CASES:-no CASES line}"
vlog ""

# ---------------------------------------------------------------------------
# P4: phase-02 standing no-regression gate (INF-03).
# ---------------------------------------------------------------------------
vlog "--- P4: phase-02/infra/verify_no_regression.sh ---"
P4_OUT="$(bash "$PROJECT_ROOT/phase-02/infra/verify_no_regression.sh" --out-dir "$OUT_DIR/p4-no-regression" 2>&1)"
P4_RC=$?
printf '%s\n' "$P4_OUT" > "$OUT_DIR/p4-verify_no_regression.txt"
P4_VERDICT="$(printf '%s\n' "$P4_OUT" | grep -E '^INF03:' | tail -1)"
vlog "  rc=$P4_RC ${P4_VERDICT:-no INF03 line}"
record "P4-verify-no-regression" "$P4_RC" "rc=$P4_RC ${P4_VERDICT:-no INF03 line}"
vlog ""

# ---------------------------------------------------------------------------
# P5: phase-06 standing network gate, inherited baseline, expecting
# CASES 24/24. --baseline (if passed to THIS script) overrides
# EFFECTIVE_BASELINE for this check only -- the negative-control path.
# ---------------------------------------------------------------------------
vlog "--- P5: phase-06/net/verify_network.sh --baseline $EFFECTIVE_BASELINE ---"
# --out-dir is passed explicitly (not left to verify_network.sh's own
# RESULTS_ROOT-derived default) because this process has phase-07's own
# RESULTS_ROOT exported (from config.env, sourced above) -- without an
# explicit --out-dir, the child process would inherit that exported value
# and silently write phase-06's own gate output under phase-07/results/
# instead of phase-06/results/ (confirmed live during authoring: a bare
# `--baseline`-only call produced phase-07/results/<UTC>-net-gate/, not
# phase-06/results/<UTC>-net-gate/). Same reasoning applies to P3/P4/P6
# below, which already pass --out-dir explicitly for the same reason.
P5_OUT="$(bash "$PROJECT_ROOT/phase-06/net/verify_network.sh" --baseline "$EFFECTIVE_BASELINE" --out-dir "$OUT_DIR/p5-network" 2>&1)"
P5_RC=$?
printf '%s\n' "$P5_OUT" > "$OUT_DIR/p5-verify_network.txt"
P5_CASES="$(printf '%s\n' "$P5_OUT" | grep -E '^CASES ' | tail -1)"
vlog "  rc=$P5_RC ${P5_CASES:-no CASES line}"
if [ "$P5_RC" -eq 0 ] && [ "$P5_CASES" = "CASES ${EXPECT_NET_CASES}/${EXPECT_NET_CASES}" ]; then
  record "P5-verify-network" 0
else
  record "P5-verify-network" 1 "rc=$P5_RC ${P5_CASES:-no CASES line} (expected CASES ${EXPECT_NET_CASES}/${EXPECT_NET_CASES} rc=0)"
fi
vlog ""

# ---------------------------------------------------------------------------
# P6: phase-03 standing sandbox gate, SBX-04 criterion specifically.
# ---------------------------------------------------------------------------
vlog "--- P6: phase-03/sandbox/verify_sandbox.sh (SBX-04) ---"
P6_OUT="$(bash "$PROJECT_ROOT/phase-03/sandbox/verify_sandbox.sh" --out-dir "$OUT_DIR/p6-sandbox" 2>&1)"
P6_RC=$?
printf '%s\n' "$P6_OUT" > "$OUT_DIR/p6-verify_sandbox.txt"
P6_SBX04="$(printf '%s\n' "$P6_OUT" | grep -E '^CRITERION 4 ' | tail -1)"
vlog "  rc=$P6_RC ${P6_SBX04:-no CRITERION 4 line}"
case "$P6_SBX04" in
  *": PASS"*|*": PASS "*)
    SBX04_OK=0
    ;;
  *)
    SBX04_OK=1
    ;;
esac
if [ "$P6_RC" -eq 0 ] && [ "$SBX04_OK" -eq 0 ]; then
  record "P6-verify-sandbox-sbx04" 0
else
  record "P6-verify-sandbox-sbx04" 1 "rc=$P6_RC ${P6_SBX04:-no CRITERION 4 line}"
fi
vlog ""

# ---------------------------------------------------------------------------
# P7: phase-01 standing provider-config gate.
# ---------------------------------------------------------------------------
vlog "--- P7: phase-01/config/verify_config.sh ---"
P7_OUT="$(bash "$PROJECT_ROOT/phase-01/config/verify_config.sh" 2>&1)"
P7_RC=$?
printf '%s\n' "$P7_OUT" > "$OUT_DIR/p7-verify_config.txt"
vlog "  rc=$P7_RC"
record "P7-verify-config" "$P7_RC" "rc=$P7_RC (see $OUT_DIR/p7-verify_config.txt)"
vlog ""

# ---------------------------------------------------------------------------
# P8: free space on the volume holding PROJECT_ROOT >= MIN_FREE_GIB.
# ---------------------------------------------------------------------------
vlog "--- P8: free disk >= ${MIN_FREE_GIB} GiB ---"
DF_LINE="$(df -g "$PROJECT_ROOT" 2>/dev/null | tail -1)"
printf '%s\n' "$DF_LINE" > "$OUT_DIR/p8-df.txt"
AVAIL_GIB="$(printf '%s\n' "$DF_LINE" | awk '{print $4}')"
vlog "  df -g $PROJECT_ROOT: $DF_LINE"
vlog "  available=${AVAIL_GIB:-unknown}GiB floor=${MIN_FREE_GIB}GiB"
if [ -n "${AVAIL_GIB:-}" ] && [ "$AVAIL_GIB" -ge "$MIN_FREE_GIB" ] 2>/dev/null; then
  record "P8-disk-floor" 0
else
  record "P8-disk-floor" 1 "available=${AVAIL_GIB:-unknown}GiB floor=${MIN_FREE_GIB}GiB"
fi
vlog ""

# ---------------------------------------------------------------------------
# P9: colima default profile Running; record CPUS/MEMORY/DISK verbatim.
# ---------------------------------------------------------------------------
vlog "--- P9: colima default profile Running ---"
COLIMA_OUT="$(colima list 2>&1)"
printf '%s\n' "$COLIMA_OUT" > "$OUT_DIR/p9-colima-list.txt"
COLIMA_LINE="$(printf '%s\n' "$COLIMA_OUT" | awk '$1=="default"{print; found=1} END{if(!found) exit 1}')"
COLIMA_LINE_RC=$?
vlog "  colima list (verbatim): $COLIMA_OUT"
if [ "$COLIMA_LINE_RC" -eq 0 ] && printf '%s\n' "$COLIMA_LINE" | grep -qw "Running"; then
  record "P9-colima-running" 0
else
  record "P9-colima-running" 1 "no 'default ... Running' row: $COLIMA_OUT"
fi
vlog ""

# ---------------------------------------------------------------------------
# P10: docker daemon reachable and is colima's. No harbor/docker run/cline
# invocation happens anywhere in this script -- docker info is the only
# docker subcommand this preflight ever calls.
# ---------------------------------------------------------------------------
vlog "--- P10: docker info reachable, Name: colima ---"
DOCKER_OUT="$(docker info 2>&1)"
DOCKER_RC=$?
printf '%s\n' "$DOCKER_OUT" > "$OUT_DIR/p10-docker-info.txt"
if [ "$DOCKER_RC" -eq 0 ] && printf '%s\n' "$DOCKER_OUT" | grep -q "Name: colima"; then
  record "P10-docker-info-colima" 0
else
  record "P10-docker-info-colima" 1 "rc=$DOCKER_RC (see $OUT_DIR/p10-docker-info.txt)"
fi
vlog ""

# ---------------------------------------------------------------------------
# P11: workspace/ALLOWED_REPOS.json's repos[] array does not include bench/
# or the repo root. Deliberately NOT a naive whole-file grep for the string
# "bench" -- house rule 9's WORDING-COLLISION TRAP applies to this exact
# file: ALLOWED_REPOS.json's own "_comment" field (written in Phase 3,
# commit df088e2, predating this phase) explains SBX-04 in prose and
# necessarily contains the word "bench" while doing so. A bare
# `grep -c bench` over the whole file would always read 1, forever, and
# would not be measuring what SBX-01/SBX-04 actually care about (the
# repos[] array). This check parses that array specifically.
# ---------------------------------------------------------------------------
vlog "--- P11: ALLOWED_REPOS.json repos[] excludes bench/ and the repo root ---"
ALLOWED_JSON="$PROJECT_ROOT/workspace/ALLOWED_REPOS.json"
P11_OUT="$(python3 - "$ALLOWED_JSON" "$PROJECT_ROOT" <<'PY'
import json
import os
import sys

path, project_root = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
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
print("PASS entries=%d %s" % (len(repos), repos))
sys.exit(0)
PY
)"
P11_RC=$?
printf '%s\n' "$P11_OUT" > "$OUT_DIR/p11-allowed-repos.txt"
vlog "  $P11_OUT"
record "P11-allowed-repos-excludes-bench" "$P11_RC" "$P11_OUT"
vlog ""

# ---------------------------------------------------------------------------
# Final tally.
# ---------------------------------------------------------------------------
vlog "CASES $PASSED/$TOTAL"
if [ "$PASSED" -eq "$TOTAL" ]; then
  vlog "PREFLIGHT: PASS"
  OVERALL_RC=0
else
  vlog "PREFLIGHT: FAIL"
  OVERALL_RC=1
fi
vlog "RESULTS_DIR=$OUT_DIR"

exit "$OVERALL_RC"
