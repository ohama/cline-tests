#!/usr/bin/env bash
# selftest_probe_lib10.sh — negative controls proving postflight10 actually
# fails when it should, not merely asserted to. Same standard as Phase 9's
# own envelope self-test: believed only after a seeded mismatch makes it
# exit non-zero.
#
# Four cases, one real preflight10 run shared by all of them (doctoring only
# COPIES of its snapshot files -- never a live pid, never the live config):
#   1. clean control            -> postflight10 must exit 0
#   2. seeded pid mismatch      -> postflight10 must exit non-zero, naming
#                                   com.ohama.flashnext
#   3. seeded config-hash       -> postflight10 must exit non-zero
#      mismatch
#   4. seeded restart-expect.   -> postflight10 must exit non-zero (litellm's
#      mismatch                    pid did not change though a restart was
#                                   claimed to have happened)
#
# Writes "$RUN"/envelope-selftest.tsv (case, expectation, observed exit code,
# verdict). Exits non-zero if any of the four behaves differently than
# expected.
#
# bash 3.2 compatible.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/probe_lib10.sh"

RUN=$(new_run_dir10 "selftest")
echo "run dir: $RUN"

TSV="$RUN/envelope-selftest.tsv"
: > "$TSV"
printf 'case\texpectation\tobserved_exit\tverdict\n' >> "$TSV"

OVERALL_OK=1

record_case() {
  local case_name="$1" expectation="$2" observed="$3"
  local verdict
  if [ "$expectation" = "zero" ] && [ "$observed" -eq 0 ]; then
    verdict="PASS"
  elif [ "$expectation" = "nonzero" ] && [ "$observed" -ne 0 ]; then
    verdict="PASS"
  else
    verdict="FAIL"
    OVERALL_OK=0
  fi
  printf '%s\t%s\t%s\t%s\n' "$case_name" "$expectation" "$observed" "$verdict" >> "$TSV"
  echo "case=$case_name expectation=$expectation observed_exit=$observed verdict=$verdict"
}

echo "--- real preflight10 (shared baseline for all 4 cases) ---"
if ! preflight10 "$RUN"; then
  echo "FATAL: preflight10 itself failed -- cannot self-test on top of a broken preflight" >&2
  exit 1
fi

LIVE_CFG_REAL_SHA=$(shasum -a 256 /Users/ohama/agent-stack/litellm/config.yaml | awk '{print $1}')

# ==========================================================================
# Case 1: clean control -- no doctoring, real hashes/pids, restart_expected=0
# ==========================================================================
CASE1_DIR="$RUN/case1-clean"
mkdir -p "$CASE1_DIR"
cp "$RUN/pids-before.txt" "$CASE1_DIR/pids-before.txt"
cp "$RUN/hashes-before.txt" "$CASE1_DIR/hashes-before.txt"
set +e
postflight10 "$CASE1_DIR" "$LIVE_CFG_REAL_SHA" 0
CASE1_RC=$?
set -e
record_case "clean-control" "zero" "$CASE1_RC"
if [ "$CASE1_RC" -ne 0 ]; then
  echo "  (unexpected -- see $CASE1_DIR/postflight.txt)"
  cat "$CASE1_DIR/postflight.txt"
fi

# ==========================================================================
# Case 2: seeded pid mismatch -- doctor a COPY of pids-before.txt so
# com.ohama.flashnext reads a value that is not the live one.
# ==========================================================================
CASE2_DIR="$RUN/case2-pid-mismatch"
mkdir -p "$CASE2_DIR"
sed 's/^com\.ohama\.flashnext [0-9]*$/com.ohama.flashnext 999999/' "$RUN/pids-before.txt" > "$CASE2_DIR/pids-before.txt"
cp "$RUN/hashes-before.txt" "$CASE2_DIR/hashes-before.txt"
set +e
postflight10 "$CASE2_DIR" "$LIVE_CFG_REAL_SHA" 0
CASE2_RC=$?
set -e
record_case "seeded-pid-mismatch" "nonzero" "$CASE2_RC"
if ! grep -q 'com.ohama.flashnext' "$CASE2_DIR/postflight.txt"; then
  echo "FAIL: case2's postflight.txt does not name com.ohama.flashnext" >&2
  OVERALL_OK=0
fi
if ! grep -q 'FAIL.*com.ohama.flashnext' "$CASE2_DIR/postflight.txt"; then
  echo "FAIL: case2's postflight.txt does not report a FAIL line for com.ohama.flashnext" >&2
  OVERALL_OK=0
fi

# ==========================================================================
# Case 3: seeded config-hash mismatch -- call postflight10 with a bogus
# expected live sha (deadbeef...), pids untouched.
# ==========================================================================
CASE3_DIR="$RUN/case3-hash-mismatch"
mkdir -p "$CASE3_DIR"
cp "$RUN/pids-before.txt" "$CASE3_DIR/pids-before.txt"
cp "$RUN/hashes-before.txt" "$CASE3_DIR/hashes-before.txt"
set +e
postflight10 "$CASE3_DIR" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 0
CASE3_RC=$?
set -e
record_case "seeded-hash-mismatch" "nonzero" "$CASE3_RC"

# ==========================================================================
# Case 4: seeded restart-expectation mismatch -- claim restart_expected=1
# while nothing has actually restarted (litellm's pid is unchanged).
# ==========================================================================
CASE4_DIR="$RUN/case4-restart-expect-mismatch"
mkdir -p "$CASE4_DIR"
cp "$RUN/pids-before.txt" "$CASE4_DIR/pids-before.txt"
cp "$RUN/hashes-before.txt" "$CASE4_DIR/hashes-before.txt"
set +e
postflight10 "$CASE4_DIR" "$LIVE_CFG_REAL_SHA" 1
CASE4_RC=$?
set -e
record_case "seeded-restart-expect-mismatch" "nonzero" "$CASE4_RC"

echo ""
echo "=== envelope-selftest.tsv ==="
cat "$TSV"

if [ "$OVERALL_OK" -eq 1 ]; then
  echo "SELFTEST: all 4 cases behaved as expected (1 exit-0 clean control, 3 exit-nonzero seeded mismatches)"
  exit 0
else
  echo "SELFTEST FAILED: at least one case did not behave as expected -- see $TSV" >&2
  exit 1
fi
