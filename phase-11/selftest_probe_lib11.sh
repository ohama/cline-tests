#!/usr/bin/env bash
# phase-11/selftest_probe_lib11.sh — offline negative controls proving the
# CORRECTED providers.json invariant (delegated to
# phase-01/config/verify_config.sh, judged on model/contextWindow, NEVER on
# sha256) still discriminates a real change from a legitimate updatedAt-only
# rewrite. Zero live model requests. Never writes to the real providers.json
# — every mutant below is a scratch copy under a temp directory, and the
# real file's model/contextWindow are asserted unchanged at the end.
#
# bash 3.2 compatible. NOTE: sourcing probe_lib11.sh turns `set -e` on in
# this shell (it sources phase-09/probe_lib.sh, which sets it) — see
# probe_lib11.sh's own header comment. Every command below that is allowed
# to fail is guarded with `cmd || var=$?` or an `if`/`||` wrapper.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/probe_lib11.sh"

REAL_PROVIDERS="$PROVIDERS"

RUN="$(new_run_dir11 selftest)"
echo "Run dir: $RUN"

echo "=== real providers.json BEFORE this selftest (for the final unchanged-assertion) ==="
providers_fields "$RUN/real-providers-before.txt"
REAL_MODEL_BEFORE="$PROV_MODEL"
REAL_CTXWIN_BEFORE="$PROV_CTXWIN"
echo "real model=$REAL_MODEL_BEFORE contextWindow=$REAL_CTXWIN_BEFORE"

TMPBASE="$(mktemp -d "${TMPDIR:-/tmp}/selftest11.XXXXXX")"
trap 'rm -rf "$TMPBASE"' EXIT

TSV="$RUN/providers-selftest.tsv"
printf 'mutant\tdescription\texpected\tobserved_exit\tverdict\n' > "$TSV"

ALL_OK=1

# ---- run_case <name> <mutant_json_path> <expected PASS|FAIL> <description> -
# Invokes the REAL phase-01/config/verify_config.sh against the mutant copy,
# via PROVIDERS_JSON=<path>, with VERIFY_CONFIG_NO_WRAPPER_CHECK=1 (this
# selftest is about the providers.json section only — the wrapper section is
# a different plan-11-03 concern, and PROVIDERS_JSON!=default already
# suppresses it on its own; NO_WRAPPER_CHECK is added for belt-and-braces
# clarity that this run is not exercising that section at all).
run_case() {
  local name="$1" path="$2" expected="$3" desc="$4"
  local out status=0
  out="$(PROVIDERS_JSON="$path" VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash "$VERIFY_CONFIG_SH" 2>&1)" || status=$?
  local observed
  if [ "$status" -eq 0 ]; then observed="PASS"; else observed="FAIL"; fi
  local verdict
  if [ "$observed" = "$expected" ]; then verdict="OK"; else verdict="MISMATCH"; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$desc" "$expected" "$status" "$verdict" >> "$TSV"
  echo "$name: expected=$expected observed=$observed (exit=$status) -> $verdict"
  echo "  --- verify_config.sh output ---"
  echo "$out" | sed 's/^/  /'
  [ "$verdict" = "OK" ]
}

# --- MUTANT-A: updatedAt-only change. Must PASS -- this is the exact case
# the OLD hash-based rule (phase-10/probe_lib10.sh's postflight10) got
# wrong. ---
A="$TMPBASE/mutant-a.json"
python3 -c "
import json
d = json.load(open('$REAL_PROVIDERS'))
d['providers']['openai-compatible']['updatedAt'] = '2099-01-01T00:00:00.000Z'
json.dump(d, open('$A', 'w'))
"
run_case "MUTANT-A" "$A" "PASS" "updatedAt-only-change" || ALL_OK=0

# --- MUTANT-B: settings.model changed. Must FAIL. ---
B="$TMPBASE/mutant-b.json"
python3 -c "
import json
d = json.load(open('$REAL_PROVIDERS'))
d['providers']['openai-compatible']['settings']['model'] = 'flashnext-plan'
json.dump(d, open('$B', 'w'))
"
run_case "MUTANT-B" "$B" "FAIL" "model-changed-to-flashnext-plan" || ALL_OK=0

# --- MUTANT-C: contextWindow changed. Must FAIL. ---
C="$TMPBASE/mutant-c.json"
python3 -c "
import json
d = json.load(open('$REAL_PROVIDERS'))
d['providers']['openai-compatible']['settings']['contextWindow'] = 128000
json.dump(d, open('$C', 'w'))
"
run_case "MUTANT-C" "$C" "FAIL" "contextWindow-changed-to-128000" || ALL_OK=0

# --- MUTANT-D: settings.models[] added. Must FAIL (the pre-existing
# assertion, confirmed still live after 11-03's edit). ---
D="$TMPBASE/mutant-d.json"
python3 -c "
import json
d = json.load(open('$REAL_PROVIDERS'))
d['providers']['openai-compatible']['settings']['models'] = [{'id': 'flashnext', 'contextWindow': 29000}]
json.dump(d, open('$D', 'w'))
"
run_case "MUTANT-D" "$D" "FAIL" "models[]-added" || ALL_OK=0

# --- CLEAN control: byte-identical copy, same session. Must PASS. ---
CLEAN="$TMPBASE/clean.json"
cp "$REAL_PROVIDERS" "$CLEAN"
run_case "CLEAN" "$CLEAN" "PASS" "unmodified-copy-same-session" || ALL_OK=0

echo ""
echo "=== providers-selftest.tsv ==="
column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"

# --- assert_budget exists and is exercised: fake RUN_REQ_CAP=0, confirm it
# aborts (non-zero exit) rather than silently letting a request through ---
echo ""
echo "=== assert_budget() exercised with RUN_REQ_CAP=0 (must abort) ==="
BUDGET_TEST_DIR="$TMPBASE/budget-test"
mkdir -p "$BUDGET_TEST_DIR"
ASSERT_BUDGET_RC=0
( export RUN_REQ_CAP=0; assert_budget "$BUDGET_TEST_DIR" ) || ASSERT_BUDGET_RC=$?
if [ "$ASSERT_BUDGET_RC" -ne 0 ]; then
  echo "OK: assert_budget aborted (exit=$ASSERT_BUDGET_RC) when running_total >= cap=0, as required"
else
  echo "FAIL: assert_budget did NOT abort with RUN_REQ_CAP=0 -- the cap enforcement is not working" >&2
  ALL_OK=0
fi
if [ -f "$BUDGET_TEST_DIR/budget.tsv" ] && grep -q 'ABORT' "$BUDGET_TEST_DIR/budget.tsv"; then
  echo "OK: assert_budget recorded an ABORT row in budget.tsv"
else
  echo "FAIL: assert_budget did not record an ABORT row" >&2
  ALL_OK=0
fi

# --- the real providers.json must be untouched by this entire selftest ---
providers_fields "$RUN/real-providers-after.txt"
REAL_MODEL_AFTER="$PROV_MODEL"
REAL_CTXWIN_AFTER="$PROV_CTXWIN"
if [ "$REAL_MODEL_BEFORE" = "$REAL_MODEL_AFTER" ] && [ "$REAL_CTXWIN_BEFORE" = "$REAL_CTXWIN_AFTER" ]; then
  echo "OK: real providers.json model/contextWindow unchanged by this selftest ($REAL_MODEL_AFTER / $REAL_CTXWIN_AFTER)"
else
  echo "FAIL: real providers.json model/contextWindow CHANGED by this selftest ($REAL_MODEL_BEFORE/$REAL_CTXWIN_BEFORE -> $REAL_MODEL_AFTER/$REAL_CTXWIN_AFTER) -- this must never happen" >&2
  ALL_OK=0
fi

# --- no live model request was issued by this task ---
FLASHNEXT_LINES_NOW=$(wc -l < "$FLASHNEXT_LOG" | tr -d ' ')
echo "flashnext.err line count at end of selftest: $FLASHNEXT_LINES_NOW -- this script issues ZERO live requests by construction (every check above runs verify_config.sh against a scratch file, never a live cline/curl call)"

echo ""
if [ "$ALL_OK" -eq 1 ]; then
  echo "selftest_probe_lib11.sh: ALL CHECKS PASSED"
  exit 0
else
  echo "selftest_probe_lib11.sh: ONE OR MORE CHECKS FAILED -- see above" >&2
  exit 1
fi
