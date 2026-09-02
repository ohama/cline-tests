#!/usr/bin/env bash
# phase-11/wrapper_argv_test.sh — behavioural test over the wrappers' ACTUAL captured argv
# (never their source text), plus the leaky-mutant and alias-swap negative controls that prove
# this test can fail.
#
# Deliberately does NOT use `set -e`: phase-10/PHASE-10-FINDINGS.md §4.6 catalogues an outage
# sampler killed by `set -e` on the exact condition it existed to record. Every command whose
# non-zero exit is expected (a refused wrapper call, a failing mutant) is captured explicitly
# instead, so a real bug in this test script fails loudly rather than being swallowed by -e or
# silently producing a false PASS.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_WRAPPER_DIR="$REPO_ROOT/phase-11"
STUB_BIN="$REPO_ROOT/phase-11/testing/stub-cline"
RESULTS_ROOT="$REPO_ROOT/phase-11/results"

if [ ! -x "$STUB_BIN" ]; then
  echo "FATAL: stub binary not found or not executable: $STUB_BIN" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$RESULTS_ROOT/${TS}-argv"
mkdir -p "$RUN"
echo "$RUN" > "$RESULTS_ROOT/CURRENT_ARGV_RUN"

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

read_env_var() {
  # $1 = wrapper dir, $2 = variable name defined in that dir's wrapper.env
  local dir="$1" var="$2"
  ( . "$dir/wrapper.env" 2>/dev/null; eval "printf '%s' \"\$$var\"" )
}

argv_lines_into_array() {
  # Populates global ARGV_LINES with the argv the stub actually received (the lines strictly
  # between the stub's own ---RUN--- and ---ENV--- markers).
  local file="$1"
  ARGV_LINES=()
  local in_run=0 line
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "---RUN---" ]; then in_run=1; continue; fi
    if [ "$line" = "---ENV---" ]; then in_run=0; continue; fi
    if [ "$in_run" = "1" ]; then ARGV_LINES+=("$line"); fi
  done < "$file"
}

argv_has_exact() {
  local want="$1" e
  for e in "${ARGV_LINES[@]:-}"; do
    [ "$e" = "$want" ] && return 0
  done
  return 1
}

argv_has_pair() {
  local flag="$1" value="$2" n i j
  n=${#ARGV_LINES[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${ARGV_LINES[$i]}" = "$flag" ]; then
      j=$((i + 1))
      if [ "$j" -lt "$n" ] && [ "${ARGV_LINES[$j]}" = "$value" ]; then
        return 0
      fi
    fi
    i=$((i + 1))
  done
  return 1
}

argv_count() {
  local want="$1" c=0 e
  for e in "${ARGV_LINES[@]:-}"; do
    [ "$e" = "$want" ] && c=$((c + 1))
  done
  printf '%s' "$c"
}

argv_last_equals() {
  local want="$1" n=${#ARGV_LINES[@]}
  [ "$n" -gt 0 ] && [ "${ARGV_LINES[$((n - 1))]}" = "$want" ]
}

env_line_present() {
  # $1 = argv file, $2 = expected exact "KEY=VALUE" line
  local file="$1" expected="$2"
  [ -f "$file" ] && grep -qxF "$expected" "$file"
}

invoke_wrapper() {
  # $1 wrapper_dir $2 wrapper_name $3 argv_file $4 out_file $5 err_file ; rest = args to the wrapper
  local wdir="$1" wname="$2" argv_file="$3" out_file="$4" err_file="$5"
  shift 5
  ( CLINE_WRAPPER_TEST=1 CLINE_WRAPPER_TEST_BIN="$STUB_BIN" STUB_ARGV_FILE="$argv_file" \
      "$wdir/$wname" "$@" >"$out_file" 2>"$err_file" )
  return $?
}

# run_case populates: CASE_RC, CASE_STUB_INVOKED, CASE_BYTE_UNCHANGED, CASE_ARGV_FILE,
# CASE_OUT_FILE, CASE_ERR_FILE, and (via argv_lines_into_array) ARGV_LINES.
run_case() {
  # $1 case_id  $2 kind(pos|refusal)  $3 wrapper_dir  $4 wrapper_name  $5 case_log_dir  -- rest = args
  local case_id="$1" kind="$2" wdir="$3" wname="$4" clog="$5"
  shift 5
  mkdir -p "$clog"
  local argv_file="$clog/${case_id}.argv"
  local out_file="$clog/${case_id}.stdout"
  local err_file="$clog/${case_id}.stderr"

  if [ "$kind" = "refusal" ]; then
    # Pre-seed a sentinel so "byte-unchanged" is a real proof (the file already exists and
    # already has content the stub would append after, if it ran) rather than a trivial
    # absent-both-times comparison.
    printf 'SENTINEL-%s-UNTOUCHED\n' "$case_id" > "$argv_file"
  else
    rm -f "$argv_file"
  fi
  : > "$out_file"
  : > "$err_file"

  local before_sha after_sha
  before_sha="$(shasum -a 256 "$argv_file" 2>/dev/null || echo NOFILE)"

  invoke_wrapper "$wdir" "$wname" "$argv_file" "$out_file" "$err_file" "$@"
  CASE_RC=$?

  after_sha="$(shasum -a 256 "$argv_file" 2>/dev/null || echo NOFILE)"
  if [ "$before_sha" = "$after_sha" ]; then CASE_BYTE_UNCHANGED=yes; else CASE_BYTE_UNCHANGED=no; fi

  if [ -f "$argv_file" ] && grep -q -- '---RUN---' "$argv_file"; then
    CASE_STUB_INVOKED=yes
  else
    CASE_STUB_INVOKED=no
  fi

  CASE_ARGV_FILE="$argv_file"
  CASE_OUT_FILE="$out_file"
  CASE_ERR_FILE="$err_file"
  argv_lines_into_array "$argv_file"
}

record_row() {
  # $1 case $2 wrapper $3 args_desc $4 exit_code $5 stub_invoked $6 assertion $7 verdict
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" >> "$OUT_TSV"
  if [ "$7" != "PASS" ]; then SUITE_FAIL=1; fi
}

# ---------------------------------------------------------------------------
# run_suite: executes all 13 cases (P1-P4, R1-R9) against a given wrapper dir.
# Sets SUITE_FAIL (0/1) and writes rows to $OUT_TSV (caller sets OUT_TSV and CLOG first).
# ---------------------------------------------------------------------------
run_suite() {
  local wdir="$1"
  SUITE_FAIL=0

  printf 'case\twrapper\targs\texit_code\tstub_invoked\tassertion\tverdict\n' > "$OUT_TSV"

  local plan_alias act_alias provider compaction
  plan_alias="$(read_env_var "$wdir" WRAPPER_PLAN_ALIAS)"
  act_alias="$(read_env_var "$wdir" WRAPPER_ACT_ALIAS)"
  provider="$(read_env_var "$wdir" WRAPPER_PROVIDER)"
  compaction="$(read_env_var "$wdir" WRAPPER_COMPACTION)"

  # --- P1: cline-plan "hello" ---
  run_case P1 pos "$wdir" cline-plan "$CLOG" "hello"
  local ok=1 reasons=""
  argv_has_exact "-p" || { ok=0; reasons="$reasons no-p"; }
  argv_has_pair "-m" "$plan_alias" || { ok=0; reasons="$reasons no-m-planalias"; }
  argv_has_pair "-P" "$provider" || { ok=0; reasons="$reasons no-P-provider"; }
  argv_has_pair "--compaction" "$compaction" || { ok=0; reasons="$reasons no-compaction"; }
  argv_last_equals "hello" || { ok=0; reasons="$reasons last-not-hello"; }
  [ "$(argv_count "-m")" = "1" ] || { ok=0; reasons="$reasons m-count-ne-1"; }
  [ "$(argv_count "--thinking")" = "0" ] || { ok=0; reasons="$reasons thinking-present"; }
  env_line_present "$CASE_ARGV_FILE" "CLINE_NO_AUTO_UPDATE=1" || { ok=0; reasons="$reasons no-env-record"; }
  record_row P1 cline-plan "cline-plan hello" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "has -p; -m ${plan_alias} once; -P ${provider}; --compaction ${compaction}; last=hello; thinking=0; env recorded${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- P2: cline-act "hello" ---
  run_case P2 pos "$wdir" cline-act "$CLOG" "hello"
  ok=1; reasons=""
  argv_has_pair "-m" "$act_alias" || { ok=0; reasons="$reasons no-m-actalias"; }
  argv_has_exact "-p" && { ok=0; reasons="$reasons has-p"; }
  argv_has_exact "--plan" && { ok=0; reasons="$reasons has--plan"; }
  [ "$(argv_count "-m")" = "1" ] || { ok=0; reasons="$reasons m-count-ne-1"; }
  [ "$(argv_count "--thinking")" = "0" ] || { ok=0; reasons="$reasons thinking-present"; }
  record_row P2 cline-act "cline-act hello" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "has -m ${act_alias} once; no -p; no --plan; thinking=0${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- P3: cline-plan --timeout 90 --json "hello" ---
  run_case P3 pos "$wdir" cline-plan "$CLOG" --timeout 90 --json "hello"
  ok=1; reasons=""
  argv_has_pair "-t" "90" || { ok=0; reasons="$reasons no-t-90"; }
  argv_has_exact "--json" || { ok=0; reasons="$reasons no-json"; }
  record_row P3 cline-plan "cline-plan --timeout 90 --json hello" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "has -t 90; has --json${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- P4: cline-plan -- "-weird prompt"  (refused: prompt begins with -) ---
  run_case P4 refusal "$wdir" cline-plan "$CLOG" -- "-weird prompt"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  record_row P4 cline-plan "cline-plan -- '-weird prompt'" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "documented limitation: prompt beginning with '-' refused, exit 2, stub not invoked, argv file byte-unchanged${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R1: cline-plan --thinking high "x" ---
  run_case R1 refusal "$wdir" cline-plan "$CLOG" --thinking high "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '--thinking' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing---thinking"; }
  record_row R1 cline-plan "cline-plan --thinking high x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged; stderr names --thinking${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R2: cline-plan --thinking=high "x" ---
  run_case R2 refusal "$wdir" cline-plan "$CLOG" --thinking=high "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '--thinking' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing---thinking"; }
  record_row R2 cline-plan "cline-plan --thinking=high x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "the '=' form; exit 2; stub not invoked; argv file byte-unchanged; stderr names --thinking${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R3: cline-plan --thinking "x"  (bare form) ---
  run_case R3 refusal "$wdir" cline-plan "$CLOG" --thinking "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '--thinking' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing---thinking"; }
  record_row R3 cline-plan "cline-plan --thinking x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "bare form (cline's own bare --thinking means medium); exit 2; stub not invoked; argv file byte-unchanged${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R4: cline-act --thinking high "x" ---
  run_case R4 refusal "$wdir" cline-act "$CLOG" --thinking high "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '--thinking' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing---thinking"; }
  record_row R4 cline-act "cline-act --thinking high x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged; stderr names --thinking${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R5: cline-plan -m flashnext "x" ---
  run_case R5 refusal "$wdir" cline-plan "$CLOG" -m flashnext "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '-m' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing--m"; }
  record_row R5 cline-plan "cline-plan -m flashnext x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged; stderr names -m${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R6: cline-act -m flashnext-codex "x" ---
  run_case R6 refusal "$wdir" cline-act "$CLOG" -m flashnext-codex "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  record_row R6 cline-act "cline-act -m flashnext-codex x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged. NOTE: flashnext-codex has been measured to kill the model server for 29s (11-RESEARCH.md) — deny-by-default closes this path too, for free, without needing a codex-specific rule${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R7: cline-plan -P openai "x" ---
  run_case R7 refusal "$wdir" cline-plan "$CLOG" -P openai "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  record_row R7 cline-plan "cline-plan -P openai x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R8: cline-act -p "x" ---
  run_case R8 refusal "$wdir" cline-act "$CLOG" -p "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  record_row R8 cline-act "cline-act -p x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "exit 2; stub not invoked; argv file byte-unchanged${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"

  # --- R9: cline-plan --auto-approve false "x"  (generic deny-by-default, not a named flag) ---
  run_case R9 refusal "$wdir" cline-plan "$CLOG" --auto-approve false "x"
  ok=1; reasons=""
  [ "$CASE_RC" = "2" ] || { ok=0; reasons="$reasons rc-ne-2(got $CASE_RC)"; }
  [ "$CASE_STUB_INVOKED" = "no" ] || { ok=0; reasons="$reasons stub-was-invoked"; }
  [ "$CASE_BYTE_UNCHANGED" = "yes" ] || { ok=0; reasons="$reasons argv-file-changed"; }
  grep -q -- '--auto-approve' "$CASE_ERR_FILE" || { ok=0; reasons="$reasons message-missing---auto-approve"; }
  record_row R9 cline-plan "cline-plan --auto-approve false x" "$CASE_RC" "$CASE_STUB_INVOKED" \
    "generic deny-by-default refusal (not one of the four named flags), proving the parser is a whitelist, not a blocklist; exit 2; stub not invoked; argv file byte-unchanged${reasons:+ [FAIL:${reasons}]}" \
    "$([ "$ok" = 1 ] && echo PASS || echo FAIL)"
}

# ---------------------------------------------------------------------------
# Part B: run the suite against the REAL wrappers
# ---------------------------------------------------------------------------
OUT_TSV="$RUN/argv.tsv"
CLOG="$RUN/cases-real"
run_suite "$REAL_WRAPPER_DIR"
REAL_SUITE_FAIL="$SUITE_FAIL"

# ---------------------------------------------------------------------------
# Part C: seed MUTANT-LEAKY and MUTANT-SWAP, prove the test can fail
# ---------------------------------------------------------------------------
MUTDIR="$RUN/mutants"
mkdir -p "$MUTDIR"

# --- MUTANT-LEAKY: models docs/plan-act-reasoning-design.md's L3 naive shell-function sketch
# (`cline -p -m flashnext-plan "$@"`) — no argument filtering at all, raw caller args forwarded
# verbatim. This is Pitfall 2 from 11-RESEARCH.md, made concrete.
LEAKY_DIR="$MUTDIR/leaky"
mkdir -p "$LEAKY_DIR"
cp "$REAL_WRAPPER_DIR/wrapper.env" "$LEAKY_DIR/wrapper.env"
cp "$REAL_WRAPPER_DIR/cline-plan" "$LEAKY_DIR/cline-plan"
cp "$REAL_WRAPPER_DIR/cline-act" "$LEAKY_DIR/cline-act"
chmod +x "$LEAKY_DIR/cline-plan" "$LEAKY_DIR/cline-act"
cat > "$LEAKY_DIR/wrapper_common.sh" <<'MUTANT_LEAKY_EOF'
#!/usr/bin/env bash
# MUTANT-LEAKY — test fixture only, never shipped. Deliberately reproduces the naive `"$@"`
# passthrough docs/plan-act-reasoning-design.md's own L3 sketch would produce
# (`cline -p -m flashnext-plan "$@"`): zero argument filtering, raw caller args forwarded
# verbatim after the fixed prefix. Seeded by phase-11/wrapper_argv_test.sh to prove the test
# can fail; must never be copied into the real phase-11/wrapper_common.sh.
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
MUTANT_LEAKY_EOF
chmod +x "$LEAKY_DIR/wrapper_common.sh"

OUT_TSV="$RUN/mutant-leaky-suite.tsv"
CLOG="$RUN/cases-mutant-leaky"
run_suite "$LEAKY_DIR"
LEAKY_SUITE_FAIL="$SUITE_FAIL"
LEAKY_R1_VERDICT="$(awk -F'\t' '$1=="R1"{print $7}' "$OUT_TSV")"
if [ "$LEAKY_R1_VERDICT" = "FAIL" ]; then
  LEAKY_MUTANT_VERDICT="CAUGHT"
  LEAKY_ACTUALLY_FAILED="R1"
else
  LEAKY_MUTANT_VERDICT="MISSED"
  LEAKY_ACTUALLY_FAILED="NONE (R1 unexpectedly PASSED against the mutant)"
fi

# --- MUTANT-SWAP: cline-plan points -m at WRAPPER_ACT_ALIAS instead of WRAPPER_PLAN_ALIAS.
# Parser and construction site are otherwise untouched (still deny-by-default).
SWAP_DIR="$MUTDIR/swap"
mkdir -p "$SWAP_DIR"
cp "$REAL_WRAPPER_DIR/wrapper.env" "$SWAP_DIR/wrapper.env"
cp "$REAL_WRAPPER_DIR/wrapper_common.sh" "$SWAP_DIR/wrapper_common.sh"
cp "$REAL_WRAPPER_DIR/cline-act" "$SWAP_DIR/cline-act"
sed 's/WRAPPER_ALIAS="\$WRAPPER_PLAN_ALIAS"/WRAPPER_ALIAS="$WRAPPER_ACT_ALIAS"/' \
  "$REAL_WRAPPER_DIR/cline-plan" > "$SWAP_DIR/cline-plan"
chmod +x "$SWAP_DIR/cline-plan" "$SWAP_DIR/cline-act" "$SWAP_DIR/wrapper_common.sh"

if ! grep -q 'WRAPPER_ALIAS="\$WRAPPER_ACT_ALIAS"' "$SWAP_DIR/cline-plan"; then
  echo "FATAL: MUTANT-SWAP seed failed — sed did not find the expected line in cline-plan" >&2
  exit 1
fi

OUT_TSV="$RUN/mutant-swap-suite.tsv"
CLOG="$RUN/cases-mutant-swap"
run_suite "$SWAP_DIR"
SWAP_SUITE_FAIL="$SUITE_FAIL"
SWAP_P1_VERDICT="$(awk -F'\t' '$1=="P1"{print $7}' "$OUT_TSV")"
if [ "$SWAP_P1_VERDICT" = "FAIL" ]; then
  SWAP_MUTANT_VERDICT="CAUGHT"
  SWAP_ACTUALLY_FAILED="P1"
else
  SWAP_MUTANT_VERDICT="MISSED"
  SWAP_ACTUALLY_FAILED="NONE (P1 unexpectedly PASSED against the mutant)"
fi

{
  printf 'mutant\texpected_failing_case\tactually_failed_case\texit_code\tverdict\n'
  printf 'MUTANT-LEAKY\tR1\t%s\t%s\t%s\n' "$LEAKY_ACTUALLY_FAILED" "$LEAKY_SUITE_FAIL" "$LEAKY_MUTANT_VERDICT"
  printf 'MUTANT-SWAP\tP1\t%s\t%s\t%s\n' "$SWAP_ACTUALLY_FAILED" "$SWAP_SUITE_FAIL" "$SWAP_MUTANT_VERDICT"
} > "$RUN/argv-mutants.tsv"

# ---------------------------------------------------------------------------
# Final verdict: exit non-zero if the REAL suite had any failing row, or if either mutant
# was MISSED. Both conditions are exercised in this same run, on purpose — a test that fails
# everything cannot masquerade as a strict one only by failing the real suite; it also has to
# demonstrate it can PASS the real suite while still catching a deliberately seeded bug.
# ---------------------------------------------------------------------------
echo "Run directory: $RUN"
echo "Real-wrapper suite: $([ "$REAL_SUITE_FAIL" = "0" ] && echo 'ALL PASS' || echo 'HAS FAILURES')"
echo "MUTANT-LEAKY: $LEAKY_MUTANT_VERDICT"
echo "MUTANT-SWAP: $SWAP_MUTANT_VERDICT"

FINAL_RC=0
[ "$REAL_SUITE_FAIL" = "0" ] || FINAL_RC=1
[ "$LEAKY_MUTANT_VERDICT" = "CAUGHT" ] || FINAL_RC=1
[ "$SWAP_MUTANT_VERDICT" = "CAUGHT" ] || FINAL_RC=1

exit "$FINAL_RC"
