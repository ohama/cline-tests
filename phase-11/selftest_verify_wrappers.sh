#!/usr/bin/env bash
# phase-11/selftest_verify_wrappers.sh — seeded-mutant proof that the REAL
# phase-01/config/verify_config.sh (not phase-11/verify_wrappers.sh directly) exits non-zero on
# each of seven separately-seeded wrapper defects, USE-02 / ROADMAP Phase 11 criterion 2's actual
# requirement, while a clean control and a legitimately-reverted alias both still pass in the
# same session.
#
# WHY verify_config.sh AND NOT verify_wrappers.sh DIRECTLY: USE-02 and ROADMAP criterion 2 are
# about verify_config.sh catching these defects (it is the standing guard every headless run
# already calls) — so verify_config.sh, with WRAPPER_DIR pointed at each mutant via the
# environment, is what must be observed exiting non-zero. Testing verify_wrappers.sh alone would
# prove a weaker claim.
#
# Mutants are built in a scratch temp directory created by mktemp -d, NEVER under phase-11/ —
# the real phase-11/wrapper.env, wrapper_common.sh, cline-plan, cline-act are only ever read
# (cp'd from), never edited in place (hard constraint 7; plan 11-01 owns those files).
#
# Deliberately NOT `set -e`, for the same reason phase-11/wrapper_argv_test.sh and
# phase-11/verify_wrappers.sh both give: a non-zero exit from a mutant run is DATA to be recorded,
# not a script bug — `set -e` would abort this script on the very condition it exists to observe
# (phase-10/PHASE-10-FINDINGS.md §4.6).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_WRAPPER_DIR="$REPO_ROOT/phase-11"
VERIFY_CONFIG_SH="$REPO_ROOT/phase-01/config/verify_config.sh"
RUN_HEADLESS_SH="$REPO_ROOT/phase-04/run_headless.sh"
RESULTS_ROOT="$REPO_ROOT/phase-11/results"

mkdir -p "$RESULTS_ROOT"

# Reuse this plan's existing wrapcheck run directory if one is already current (Task 2 created
# one); otherwise start a fresh one. Either way CURRENT_WRAPCHECK_RUN ends up pointing at the
# directory this script writes into.
RUN_REL=""
if [ -f "$RESULTS_ROOT/CURRENT_WRAPCHECK_RUN" ]; then
  RUN_REL="$(cat "$RESULTS_ROOT/CURRENT_WRAPCHECK_RUN")"
fi
if [ -n "$RUN_REL" ] && [ -d "$REPO_ROOT/$RUN_REL" ]; then
  RUN="$REPO_ROOT/$RUN_REL"
else
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  RUN_REL="phase-11/results/${TS}-wrapcheck"
  RUN="$REPO_ROOT/$RUN_REL"
  mkdir -p "$RUN"
  echo "$RUN_REL" > "$RESULTS_ROOT/CURRENT_WRAPCHECK_RUN"
fi
mkdir -p "$RUN/mutants"

TSV="$RUN/wrapper-selftest.tsv"
printf 'mutant\twhat_changed\texpected_failing_assertion\texit_code\tmessage_excerpt\tverdict\n' > "$TSV"

MUTROOT="$(mktemp -d "${TMPDIR:-/tmp}/verify-wrappers-selftest.XXXXXX")"
trap 'rm -rf "$MUTROOT"' EXIT

FAIL_ANY=0

copy_base() {
  local dest="$1"
  mkdir -p "$dest"
  cp "$REAL_WRAPPER_DIR/wrapper.env" "$dest/wrapper.env"
  cp "$REAL_WRAPPER_DIR/wrapper_common.sh" "$dest/wrapper_common.sh"
  cp "$REAL_WRAPPER_DIR/cline-plan" "$dest/cline-plan"
  cp "$REAL_WRAPPER_DIR/cline-act" "$dest/cline-act"
  chmod +x "$dest/cline-plan" "$dest/cline-act" "$dest/wrapper_common.sh"
}

require_seed() {
  # $1 = human label, $2 = grep pattern that MUST be present after the sed edit (fails loudly if
  # the seed itself silently no-op'd, the same safety net phase-11/wrapper_argv_test.sh's own
  # MUTANT-SWAP construction uses).
  local label="$1" file="$2" pattern="$3"
  if ! grep -qF -- "$pattern" "$file"; then
    echo "FATAL: mutant seed '$label' did not take — expected to find '$pattern' in $file" >&2
    exit 1
  fi
}

excerpt_of() {
  # $1 = output file, $2 = preferred grep pattern (extended regex), fallback = first FAIL[WRAPPER] line
  local out="$1" pattern="$2" line
  line="$(grep -m1 -E "$pattern" "$out" 2>/dev/null || true)"
  if [ -z "$line" ]; then
    line="$(grep -m1 'FAIL\[WRAPPER\]' "$out" 2>/dev/null || true)"
  fi
  if [ -z "$line" ]; then
    line="(no FAIL[WRAPPER] line found in output)"
  fi
  # collapse to a single line, trim to keep the TSV readable
  printf '%s' "$line" | tr -d '\n' | cut -c1-260
}

record_row() {
  # $1 mutant  $2 changed  $3 expected_assertion  $4 exit_code  $5 excerpt  $6 expect_class(nonzero|zero)
  local mutant="$1" changed="$2" expected="$3" rc="$4" excerpt="$5" expect_class="$6" verdict
  if [ "$expect_class" = "nonzero" ]; then
    if [ "$rc" -ne 0 ]; then verdict="CAUGHT"; else verdict="MISSED"; FAIL_ANY=1; fi
  else
    if [ "$rc" -eq 0 ]; then verdict="PASS"; else verdict="FAIL"; FAIL_ANY=1; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mutant" "$changed" "$expected" "$rc" "$excerpt" "$verdict" >> "$TSV"
  echo "$mutant: exit=$rc verdict=$verdict"
}

run_against_mutant() {
  # $1 = mutant dir, $2 = output file. Runs the REAL verify_config.sh, real environment except
  # WRAPPER_DIR pointed at the mutant. VERIFY_CONFIG_NO_WRAPPER_CHECK is deliberately left unset
  # and PROVIDERS_JSON deliberately left at its default so the wrapper section actually runs.
  local mdir="$1" outfile="$2"
  ( WRAPPER_DIR="$mdir" bash "$VERIFY_CONFIG_SH" ) > "$outfile" 2>&1
  return $?
}

# ---------------------------------------------------------------------------
# M1 — alias-mismatch: cline-plan's WRAPPER_ALIAS points at the ACT alias instead of the plan
# alias. The literal ROADMAP criterion 2 mode/alias-mismatch case.
# ---------------------------------------------------------------------------
M1_DIR="$MUTROOT/m1-alias-mismatch"
copy_base "$M1_DIR"
sed -i.bak 's/WRAPPER_ALIAS="\$WRAPPER_PLAN_ALIAS"/WRAPPER_ALIAS="$WRAPPER_ACT_ALIAS"/' "$M1_DIR/cline-plan"
rm -f "$M1_DIR/cline-plan.bak"
require_seed "M1" "$M1_DIR/cline-plan" 'WRAPPER_ALIAS="$WRAPPER_ACT_ALIAS"'
M1_OUT="$RUN/mutants/M1.out"
run_against_mutant "$M1_DIR" "$M1_OUT"; M1_RC=$?
record_row "M1-alias-mismatch" \
  "cline-plan: WRAPPER_ALIAS=\$WRAPPER_PLAN_ALIAS -> \$WRAPPER_ACT_ALIAS" \
  "Group A alias-source check and/or Group B argv -m plan-alias check" \
  "$M1_RC" "$(excerpt_of "$M1_OUT" 'FAIL\[WRAPPER\].*(alias|mismatch)')" nonzero

# ---------------------------------------------------------------------------
# M2 — mode-flag-dropped: cline-plan's WRAPPER_MODE_FLAG is emptied (loses -p).
# ---------------------------------------------------------------------------
M2_DIR="$MUTROOT/m2-mode-flag-dropped"
copy_base "$M2_DIR"
sed -i.bak 's/WRAPPER_MODE_FLAG="-p"/WRAPPER_MODE_FLAG=""/' "$M2_DIR/cline-plan"
rm -f "$M2_DIR/cline-plan.bak"
require_seed "M2" "$M2_DIR/cline-plan" 'WRAPPER_MODE_FLAG=""'
M2_OUT="$RUN/mutants/M2.out"
run_against_mutant "$M2_DIR" "$M2_OUT"; M2_RC=$?
record_row "M2-mode-flag-dropped" \
  "cline-plan: WRAPPER_MODE_FLAG=\"-p\" -> \"\"" \
  "Group A cline-plan WRAPPER_MODE_FLAG=\"-p\" check and/or Group B argv -p presence check" \
  "$M2_RC" "$(excerpt_of "$M2_OUT" 'FAIL\[WRAPPER\].*(WRAPPER_MODE_FLAG|-p)')" nonzero

# ---------------------------------------------------------------------------
# M3 — mode-flag-added: cline-act's WRAPPER_MODE_FLAG is set to -p (Act must never plan-mode).
# ---------------------------------------------------------------------------
M3_DIR="$MUTROOT/m3-mode-flag-added"
copy_base "$M3_DIR"
sed -i.bak 's/WRAPPER_MODE_FLAG=""/WRAPPER_MODE_FLAG="-p"/' "$M3_DIR/cline-act"
rm -f "$M3_DIR/cline-act.bak"
require_seed "M3" "$M3_DIR/cline-act" 'WRAPPER_MODE_FLAG="-p"'
M3_OUT="$RUN/mutants/M3.out"
run_against_mutant "$M3_DIR" "$M3_OUT"; M3_RC=$?
record_row "M3-mode-flag-added" \
  "cline-act: WRAPPER_MODE_FLAG=\"\" -> \"-p\"" \
  "Group A cline-act WRAPPER_MODE_FLAG=\"\" check and/or no -p/--plan-outside-comments check" \
  "$M3_RC" "$(excerpt_of "$M3_OUT" 'FAIL\[WRAPPER\].*(WRAPPER_MODE_FLAG|-p|--plan)')" nonzero

# ---------------------------------------------------------------------------
# M4/M5 — thinking-leak / model-leak: wrapper_common.sh wholesale-replaced with a naive "$@"
# passthrough (docs/plan-act-reasoning-design.md's own L3 sketch), so caller args reach the real
# binary unfiltered. Modeled on phase-11/results/20260902T041615Z-argv/'s own MUTANT-LEAKY
# (11-01), rebuilt here independently since that file belongs to plan 11-01 and is never edited
# in place. ONE mutant directory, exercised by TWO rows (M4 via --thinking, M5 via -m) from the
# SAME verify_config.sh run, because phase-11/verify_wrappers.sh's Group B already runs both
# probes every time.
# ---------------------------------------------------------------------------
M4_DIR="$MUTROOT/m4-thinking-leak"
copy_base "$M4_DIR"
cat > "$M4_DIR/wrapper_common.sh" <<'LEAKY_EOF'
#!/usr/bin/env bash
# MUTANT-LEAKY (plan 11-03 selftest, M4/M5) — test fixture only, in a scratch temp dir, never
# copied back into phase-11/. Reproduces the naive "$@" passthrough
# docs/plan-act-reasoning-design.md's own L3 sketch would produce: zero argument filtering, raw
# caller args forwarded verbatim after the fixed prefix.
set -euo pipefail
: "${WRAPPER_SELF:?}"
: "${WRAPPER_MODE_FLAG:=}"
: "${WRAPPER_ALIAS:?}"
: "${HERE:?}"

CMD="$WRAPPER_CLINE_BIN"
if [ "${CLINE_WRAPPER_TEST:-}" = "1" ]; then
  : "${CLINE_WRAPPER_TEST_BIN:?}"
  echo "[TEST MODE] using $CLINE_WRAPPER_TEST_BIN instead of $WRAPPER_CLINE_BIN" >&2
  CMD="$CLINE_WRAPPER_TEST_BIN"
fi

ORIG_ARGS=("$@")
set -- -P "$WRAPPER_PROVIDER"
[ -n "$WRAPPER_MODE_FLAG" ] && set -- "$@" "$WRAPPER_MODE_FLAG"
set -- "$@" -m "$WRAPPER_ALIAS" --compaction "$WRAPPER_COMPACTION" -t "$WRAPPER_DEFAULT_TIMEOUT"
set -- "$@" "${ORIG_ARGS[@]}"

CLINE_NO_AUTO_UPDATE=1 "$CMD" "$@"
LEAKY_EOF
chmod +x "$M4_DIR/wrapper_common.sh"
require_seed "M4" "$M4_DIR/wrapper_common.sh" 'ORIG_ARGS=("$@")'
M4_OUT="$RUN/mutants/M4-M5-leaky.out"
run_against_mutant "$M4_DIR" "$M4_OUT"; M4_RC=$?
record_row "M4-thinking-leak" \
  "wrapper_common.sh wholesale-replaced with naive \"\$@\" passthrough (no argument filtering)" \
  "Group B: cline-plan --thinking high should be refused; observed it reaching the stub instead" \
  "$M4_RC" "$(excerpt_of "$M4_OUT" 'FAIL\[WRAPPER\].*USE-02 --thinking leak check')" nonzero
record_row "M5-model-leak" \
  "same mutant as M4 (wrapper_common.sh naive \"\$@\" passthrough), exercised with -m flashnext" \
  "Group B: cline-plan -m flashnext should be refused; observed it reaching the stub instead" \
  "$M4_RC" "$(excerpt_of "$M4_OUT" 'FAIL\[WRAPPER\].*-m flashnext')" nonzero

# ---------------------------------------------------------------------------
# M6 — wrapper-deleted: cline-plan removed entirely. Absence is a failure, not a skip.
# ---------------------------------------------------------------------------
M6_DIR="$MUTROOT/m6-wrapper-deleted"
copy_base "$M6_DIR"
rm -f "$M6_DIR/cline-plan"
M6_OUT="$RUN/mutants/M6.out"
run_against_mutant "$M6_DIR" "$M6_OUT"; M6_RC=$?
record_row "M6-wrapper-deleted" \
  "cline-plan removed entirely from the wrapper directory" \
  "top-level absence gate in verify_wrappers.sh (missing required file)" \
  "$M6_RC" "$(excerpt_of "$M6_OUT" 'FAIL\[WRAPPER\].*missing')" nonzero

# ---------------------------------------------------------------------------
# M7 — codex-alias: wrapper.env's act alias set to flashnext-codex. Static check only — this
# mutant never invokes anything.
# ---------------------------------------------------------------------------
M7_DIR="$MUTROOT/m7-codex-alias"
copy_base "$M7_DIR"
sed -i.bak 's/WRAPPER_ACT_ALIAS="flashnext-act"/WRAPPER_ACT_ALIAS="flashnext-codex"/' "$M7_DIR/wrapper.env"
rm -f "$M7_DIR/wrapper.env.bak"
require_seed "M7" "$M7_DIR/wrapper.env" 'WRAPPER_ACT_ALIAS="flashnext-codex"'
M7_OUT="$RUN/mutants/M7.out"
run_against_mutant "$M7_DIR" "$M7_OUT"; M7_RC=$?
record_row "M7-codex-alias" \
  "wrapper.env: WRAPPER_ACT_ALIAS=\"flashnext-act\" -> \"flashnext-codex\"" \
  "Group A forbidden-codex-alias check (static; never invokes anything)" \
  "$M7_RC" "$(excerpt_of "$M7_OUT" 'FAIL\[WRAPPER\].*codex')" nonzero

# ---------------------------------------------------------------------------
# M8 — POSITIVE CONTROL: alias reverted to plain 'flashnext' (USE-03's revert branch). MUST PASS.
# Proves the checker does not hardcode the current A/B outcome into the guard.
# ---------------------------------------------------------------------------
M8_DIR="$MUTROOT/m8-alias-reverted"
copy_base "$M8_DIR"
sed -i.bak 's/WRAPPER_PLAN_ALIAS="flashnext-plan"/WRAPPER_PLAN_ALIAS="flashnext"/' "$M8_DIR/wrapper.env"
rm -f "$M8_DIR/wrapper.env.bak"
require_seed "M8" "$M8_DIR/wrapper.env" 'WRAPPER_PLAN_ALIAS="flashnext"'
M8_OUT="$RUN/mutants/M8.out"
run_against_mutant "$M8_DIR" "$M8_OUT"; M8_RC=$?
record_row "M8-alias-reverted-POSITIVE-CONTROL" \
  "wrapper.env: WRAPPER_PLAN_ALIAS=\"flashnext-plan\" -> \"flashnext\" (USE-03's revert state)" \
  "must exit 0 — a legitimate revert must not be indistinguishable from a real defect" \
  "$M8_RC" "$(excerpt_of "$M8_OUT" 'OK\[WRAPPER\]: all wrapper assertions passed')" zero

# ---------------------------------------------------------------------------
# M9 — CLEAN CONTROL: unmutated copy. MUST PASS, in the same session as the seven MUSTs above.
# ---------------------------------------------------------------------------
M9_DIR="$MUTROOT/m9-clean-control"
copy_base "$M9_DIR"
M9_OUT="$RUN/mutants/M9.out"
run_against_mutant "$M9_DIR" "$M9_OUT"; M9_RC=$?
record_row "M9-clean-control" \
  "none — unmutated copy of the real wrapper set" \
  "must exit 0 — a checker that fails everything cannot masquerade as a strict one" \
  "$M9_RC" "$(excerpt_of "$M9_OUT" 'OK\[WRAPPER\]: all wrapper assertions passed')" zero

echo
echo "wrapper-selftest.tsv written to: $TSV"
column -t -s "$(printf '\t')" "$TSV" 2>/dev/null || cat "$TSV"

# ---------------------------------------------------------------------------
# Integration row: with the M4 leaky mutant in place, run_headless.sh (Task 2's guard) must abort
# with the WRAPPER message, not a providers.json message.
# ---------------------------------------------------------------------------
INTEGRATION_OUT="$RUN/mutants/integration-run_headless-M4.out"
( WRAPPER_DIR="$M4_DIR" HEADLESS_DRY=1 SKIP_SANDBOX_GATE=1 bash "$RUN_HEADLESS_SH" "smoke" ) \
  > "$RUN/mutants/integration-run_headless-M4.stdout" 2> "$INTEGRATION_OUT"
INTEGRATION_RC=$?

ABORT_LINE="$(grep -m1 'ABORT: wrapper mode/alias check failed' "$INTEGRATION_OUT" || true)"
INTEGRATION_VERDICT="FAIL"
if [ -n "$ABORT_LINE" ] && ! grep -q 'providers.json still fails' "$INTEGRATION_OUT"; then
  INTEGRATION_VERDICT="PASS"
else
  FAIL_ANY=1
fi

{
  echo "run_headless.sh exit code: $INTEGRATION_RC"
  echo "abort line (verbatim): $ABORT_LINE"
  echo "verdict: $INTEGRATION_VERDICT"
} > "$RUN/integration-row.txt"
cat "$RUN/integration-row.txt"

echo
echo "=== overall selftest verdict: $([ "$FAIL_ANY" = "0" ] && echo PASS || echo FAIL) ==="

exit "$FAIL_ANY"
