#!/usr/bin/env bash
# test_harness_dryrun.sh — offline proof that run_regression.sh's plumbing is wired
# correctly, so Plan 06's live run is spent measuring the model, not debugging the
# harness. Never invokes the model. Never modifies phase-01/config/observed.env
# (Plan 05's file, read-only via the OBSERVED_ENV_PATH indirection everywhere here).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This file lives at phase-01/tests/ - repo root is two levels up.
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

FAILURES=0
fail() {
  echo "FAIL: $*"
  FAILURES=$((FAILURES + 1))
}
pass() {
  echo "OK: $*"
}

# This is the ONLY place this test may reference Plan 05's real file, and only
# for reading (existence + shasum), to prove this test never touched it.
PLAN05_ENV="phase-01/config/observed.env"

TMP_DIR="phase-01/tests/tmp"
DRYRUN_RESULTS_ROOT="phase-01/results/dryrun"
mkdir -p "$TMP_DIR" "$DRYRUN_RESULTS_ROOT"

SCRATCH_OBSERVED="$TMP_DIR/observed.env"
printf 'export CLINE_OBSERVED_MAX_TOKENS=2048\n' > "$SCRATCH_OBSERVED"

# --- Pre-flight evidence: capture state we must never have touched ---

FLASHNEXT_ERR_LOG="$HOME/llm-system/services/logs/flashnext.err"
LOG_SIZE_BEFORE=0
LOG_SHA_BEFORE=""
if [ -f "$FLASHNEXT_ERR_LOG" ]; then
  LOG_SIZE_BEFORE="$(wc -c < "$FLASHNEXT_ERR_LOG" | tr -d ' ')"
fi

PLAN05_EXISTED_BEFORE=0
PLAN05_SHA_BEFORE=""
if [ -f "$PLAN05_ENV" ]; then
  PLAN05_EXISTED_BEFORE=1
  PLAN05_SHA_BEFORE="$(shasum "$PLAN05_ENV" | cut -d' ' -f1)"
fi

# --- Live contextWindow / trigger, computed independently of run_regression.sh ---

PROVIDERS_JSON_DEFAULT="$HOME/.cline/data/settings/providers.json"
CONTEXT_WINDOW="$(python3 -c "
import json
with open('$PROVIDERS_JSON_DEFAULT') as f:
    data = json.load(f)
# 2026-08-30 정정: 최상위 contextWindow 가 CLI 가 읽는 경로다 (models[] 아님)
print(data['providers']['openai-compatible']['settings']['contextWindow'])
")"
# 최상위 contextWindow -> maxInputTokens 직행이므로 x0.9 한 번 (run_regression.sh 와 동일)
EXPECTED_TRIGGER="$(python3 -c "print(int($CONTEXT_WINDOW * 0.9))")"

MAX_KV_SIZE="$(grep -m1 '^export CLINE_SERVER_MAX_KV_SIZE=' phase-01/config/cline-invocation.env | cut -d= -f2)"

echo "=== Test: exit codes 0/2/3 for the three classifier fixtures ==="

# bash 3.2 (macOS default) has no associative arrays - use parallel indexed arrays instead.
FIXTURES=(
  "phase-01/tests/fixtures/outcome1_compacted.ndjson"
  "phase-01/tests/fixtures/outcome2_server400.ndjson"
  "phase-01/tests/fixtures/outcome3_below_trigger.ndjson"
)
EXPECTED_EXITS=(0 2 3)

RESULTS_DIRS=()

for idx in "${!FIXTURES[@]}"; do
  fixture="${FIXTURES[$idx]}"
  expected="${EXPECTED_EXITS[$idx]}"
  before_dirs="$(ls -1 "$DRYRUN_RESULTS_ROOT" 2>/dev/null || true)"

  OUTPUT="$(OBSERVED_ENV_PATH="$SCRATCH_OBSERVED" RESULTS_ROOT="$DRYRUN_RESULTS_ROOT" \
            DRY_FIXTURE="$fixture" RUN_DRY=1 bash phase-01/run_regression.sh 2>&1)"
  actual=$?

  if [ "$actual" -eq "$expected" ]; then
    pass "fixture $fixture -> exit $actual (expected $expected)"
  else
    fail "fixture $fixture -> exit $actual (expected $expected). Output:\n$OUTPUT"
  fi

  new_dir="$(comm -13 <(echo "$before_dirs" | sort) <(ls -1 "$DRYRUN_RESULTS_ROOT" 2>/dev/null | sort))"
  if [ -z "$new_dir" ]; then
    fail "fixture $fixture: no new results dir appeared under $DRYRUN_RESULTS_ROOT"
    continue
  fi
  RESULTS_DIRS+=("$DRYRUN_RESULTS_ROOT/$new_dir")
done

echo "=== Test: expected artifact set in each results dir ==="

EXPECTED_ARTIFACTS=(prompt.txt ndjson.log flashnext_window.log versions.txt env.txt providers.json config_post_run.txt verdict.md)

for d in "${RESULTS_DIRS[@]}"; do
  for artifact in "${EXPECTED_ARTIFACTS[@]}"; do
    if [ -f "$d/$artifact" ]; then
      pass "$d/$artifact exists"
    else
      fail "$d/$artifact MISSING"
    fi
  done
done

echo "=== Test: rendered prompt contains 12 absolute filler paths, no literal placeholder ==="

for d in "${RESULTS_DIRS[@]}"; do
  prompt="$d/prompt.txt"
  [ -f "$prompt" ] || continue

  abs_path_count="$(grep -cE "^${REPO_ROOT}/phase-01/filler/wrapped_[0-9]{2}\.txt$" "$prompt")"
  if [ "$abs_path_count" -eq 12 ]; then
    pass "$prompt lists exactly 12 absolute filler paths"
  else
    fail "$prompt lists $abs_path_count absolute filler paths (expected 12)"
  fi

  if grep -q '{{FILE_LIST}}' "$prompt"; then
    fail "$prompt still contains the literal {{FILE_LIST}} placeholder"
  else
    pass "$prompt has no leftover {{FILE_LIST}} placeholder"
  fi
done

echo "=== Test: budget preflight rejects an over-budget CLINE_OBSERVED_MAX_TOKENS ==="

BAD_OBSERVED="$TMP_DIR/observed_bad.env"
BAD_VALUE=$((MAX_KV_SIZE - EXPECTED_TRIGGER + 1000))
printf 'export CLINE_OBSERVED_MAX_TOKENS=%s\n' "$BAD_VALUE" > "$BAD_OBSERVED"

BUDGET_OUTPUT="$(OBSERVED_ENV_PATH="$BAD_OBSERVED" RESULTS_ROOT="$DRYRUN_RESULTS_ROOT" RUN_DRY=1 bash phase-01/run_regression.sh 2>&1)"
BUDGET_EXIT=$?

if [ "$BUDGET_EXIT" -ne 0 ]; then
  pass "over-budget CLINE_OBSERVED_MAX_TOKENS=$BAD_VALUE aborted with non-zero exit ($BUDGET_EXIT)"
else
  fail "over-budget CLINE_OBSERVED_MAX_TOKENS=$BAD_VALUE did NOT abort (exit 0)"
fi

if echo "$BUDGET_OUTPUT" | grep -qi 'budget'; then
  pass "abort message mentions 'budget'"
else
  fail "abort message does not mention 'budget'. Output:\n$BUDGET_OUTPUT"
fi

for num in "$EXPECTED_TRIGGER" "$BAD_VALUE" "$MAX_KV_SIZE"; do
  if echo "$BUDGET_OUTPUT" | grep -q "$num"; then
    pass "abort message includes $num"
  else
    fail "abort message missing $num. Output:\n$BUDGET_OUTPUT"
  fi
done

echo "=== Test: missing OBSERVED_ENV_PATH target aborts with the exact required message ==="

ABSENT_OUTPUT="$(OBSERVED_ENV_PATH="$TMP_DIR/definitely-absent.env" RESULTS_ROOT="$DRYRUN_RESULTS_ROOT" RUN_DRY=1 bash phase-01/run_regression.sh 2>&1)"
ABSENT_EXIT=$?
if [ "$ABSENT_EXIT" -ne 0 ] && echo "$ABSENT_OUTPUT" | grep -q 'ABORT: CLINE_OBSERVED_MAX_TOKENS unknown'; then
  pass "missing OBSERVED_ENV_PATH target aborts with the exact required message"
else
  fail "missing OBSERVED_ENV_PATH target did not abort correctly. exit=$ABSENT_EXIT Output:\n$ABSENT_OUTPUT"
fi

echo "=== Test: EFFECTIVE_TRIGGER in env.txt matches an independent int(contextWindow*0.9*0.9) ==="

for d in "${RESULTS_DIRS[@]}"; do
  env_file="$d/env.txt"
  [ -f "$env_file" ] || continue
  recorded="$(grep -m1 '^EFFECTIVE_TRIGGER=' "$env_file" | cut -d= -f2)"
  if [ "$recorded" = "$EXPECTED_TRIGGER" ]; then
    pass "$env_file EFFECTIVE_TRIGGER=$recorded matches independently computed $EXPECTED_TRIGGER"
  else
    fail "$env_file EFFECTIVE_TRIGGER=$recorded does NOT match independently computed $EXPECTED_TRIGGER"
  fi
done

echo "=== Test: source flashnext.err was never opened for writing by run_regression.sh ==="

WRITE_REFS="$(grep -cE '> *"?\$FLASHNEXT_ERR_LOG' phase-01/run_regression.sh)"
if [ "$WRITE_REFS" -eq 0 ]; then
  pass "run_regression.sh contains zero '> \$FLASHNEXT_ERR_LOG' write patterns"
else
  fail "run_regression.sh contains $WRITE_REFS suspicious write pattern(s) against \$FLASHNEXT_ERR_LOG"
fi

LOG_SIZE_AFTER=0
if [ -f "$FLASHNEXT_ERR_LOG" ]; then
  LOG_SIZE_AFTER="$(wc -c < "$FLASHNEXT_ERR_LOG" | tr -d ' ')"
fi
if [ "$LOG_SIZE_AFTER" -ge "$LOG_SIZE_BEFORE" ]; then
  pass "flashnext.err size non-decreasing across the whole test ($LOG_SIZE_BEFORE -> $LOG_SIZE_AFTER)"
else
  fail "flashnext.err SHRANK across the test ($LOG_SIZE_BEFORE -> $LOG_SIZE_AFTER) — something truncated it"
fi

echo "=== Test: run_regression.sh never writes/deletes phase-01/config/observed.env ==="

STATIC_WRITE_REFS="$(grep -cE '(rm|mv|cp|touch|>|>>)[^\n]*phase-01/config/observed\.env' phase-01/run_regression.sh)"
if [ "$STATIC_WRITE_REFS" -eq 0 ]; then
  pass "run_regression.sh contains zero write/delete references to phase-01/config/observed.env"
else
  fail "run_regression.sh contains $STATIC_WRITE_REFS write/delete reference(s) to phase-01/config/observed.env"
fi

# (This script's own zero-write-reference property against phase-01/config/observed.env
# is checked EXTERNALLY, by grepping this file after it is written - see the plan's
# <verify> block - not asserted here, since a self-referential grep for that exact
# pattern would always match the very line performing the check.)

PLAN05_EXISTED_AFTER=0
PLAN05_SHA_AFTER=""
if [ -f "$PLAN05_ENV" ]; then
  PLAN05_EXISTED_AFTER=1
  PLAN05_SHA_AFTER="$(shasum "$PLAN05_ENV" | cut -d' ' -f1)"
fi

if [ "$PLAN05_EXISTED_BEFORE" -eq "$PLAN05_EXISTED_AFTER" ] && [ "$PLAN05_SHA_BEFORE" = "$PLAN05_SHA_AFTER" ]; then
  pass "$PLAN05_ENV existence/content unchanged across the whole test (existed_before=$PLAN05_EXISTED_BEFORE existed_after=$PLAN05_EXISTED_AFTER)"
else
  fail "$PLAN05_ENV changed! existed_before=$PLAN05_EXISTED_BEFORE sha_before=$PLAN05_SHA_BEFORE existed_after=$PLAN05_EXISTED_AFTER sha_after=$PLAN05_SHA_AFTER"
fi

echo "=== Cleanup (only what this test created) ==="
rm -rf "$DRYRUN_RESULTS_ROOT"
rm -rf "$TMP_DIR"
pass "removed $DRYRUN_RESULTS_ROOT and $TMP_DIR"

echo "---"
if [ "$FAILURES" -eq 0 ]; then
  echo "harness dry-run: PASS"
  exit 0
else
  echo "harness dry-run: FAIL ($FAILURES)"
  exit 1
fi
