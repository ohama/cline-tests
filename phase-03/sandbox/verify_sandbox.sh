#!/bin/bash
# verify_sandbox.sh — the standing Phase 3 gate.
#
# Re-runnable, read-only against every live service: makes no launchd
# mutation, restarts nothing, and never touches Phase 2's hardening. Proves
# all four ROADMAP Phase 3 success criteria (SBX-01..04) in one command and
# prints one PASS/FAIL line per criterion so the mapping from case to
# criterion is explicit and greppable. Phases 4, 5, 6 and 7 should call
# this script before trusting phase-03/sandbox/run_sandboxed.sh, the same
# way phase-02/infra/verify_no_regression.sh is the standing INF-03 gate.
#
# SCOPE LIMITATION (stated, not hidden, same as config.env/run_sandboxed.sh):
# the generated profiles use `(allow default)` with an explicit deny on
# PROTECTED_ROOT. They protect $HOME. This is NOT a total-deny jail —
# anything outside $HOME (/tmp, /opt, /usr/local, external volumes) stays
# reachable. That is an accepted, deliberate boundary, not a bug this gate
# checks for.
#
# Every allow/deny judgement in this script is delegated to
# assert_denied.sh (or, for the F8 probe, to probe_fs.js's own DENIED/ERROR/
# SUCCEEDED text) — never to a bare exit code. See 03-RESEARCH.md Pitfall 1
# (crash != denial) and Pitfall 5 (fail-open profile, not restrictive).
#
# macOS /bin/bash is 3.2: parallel indexed arrays only, no declare -A.
#
# Usage:
#   verify_sandbox.sh [--out-dir <dir>]
#   verify_sandbox.sh --negative-control [--negative-control-skip-precheck] [--out-dir <dir>]
#
# Exit code contract (mirrors phase-01/parse_result.py's 3-way discipline):
#   0 = all four CRITERION lines PASS
#   1 = at least one CRITERION FAIL (and no case CRASHED)
#   2 = at least one case CRASHED — inconclusive, never report as a pass
#
# --negative-control mode proves this verifier can itself detect a
# fail-open sandbox (03-RESEARCH.md Pitfall 5: a sandbox that passes
# because it fails open is invisible to a shallow test). It deliberately
# feeds Group F a deny-less fixture.sb and inverts the expectation; see the
# NEGATIVE CONTROL MODE section below for its own, separate exit contract.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

OUT_DIR=""
NEGATIVE_CONTROL=0
NEGATIVE_CONTROL_SKIP_PRECHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"; shift 2 ;;
    --negative-control)
      NEGATIVE_CONTROL=1; shift ;;
    --negative-control-skip-precheck)
      NEGATIVE_CONTROL_SKIP_PRECHECK=1; shift ;;
    *)
      echo "verify_sandbox.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  if [ "$NEGATIVE_CONTROL" -eq 1 ]; then
    OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-negative-control"
  else
    OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-sbx"
  fi
fi
mkdir -p "$OUT_DIR"
export EVIDENCE_DIR="$OUT_DIR"

FIXTURE_SB="$OUT_DIR/fixture.sb"
PRODUCTION_SB="$OUT_DIR/production.sb"
VERDICT_FILE="$OUT_DIR/sbx-verdict.txt"
: > "$VERDICT_FILE"

vlog() {
  echo "$1" | tee -a "$VERDICT_FILE"
}

CANARY_STRING="SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX"

# ---------------------------------------------------------------------------
# Case bookkeeping: parallel indexed arrays (bash 3.2 has no declare -A).
# rc convention (same as assert_denied.sh): 0=PASS, 1=FAIL, 2=CRASHED.
# ---------------------------------------------------------------------------
CASE_IDS=()
CASE_RCS=()

record_case() {
  CASE_IDS+=("$1")
  CASE_RCS+=("$2")
}

get_case_rc() {
  local want="$1" i
  for ((i = 0; i < ${#CASE_IDS[@]}; i++)); do
    if [ "${CASE_IDS[$i]}" = "$want" ]; then
      printf '%s' "${CASE_RCS[$i]}"
      return 0
    fi
  done
  printf ''
}

criterion_verdict() {
  # Prints "PASS <id>=... <id>=..." or "FAIL <id>=... <id>=..." for the
  # given list of case ids. A missing case (never ran) counts as FAIL.
  local all_pass=1 detail="" id rc
  for id in "$@"; do
    rc="$(get_case_rc "$id")"
    if [ -z "$rc" ]; then
      all_pass=0
      detail="$detail $id=MISSING"
    elif [ "$rc" != "0" ]; then
      all_pass=0
      detail="$detail $id=rc$rc"
    else
      detail="$detail $id=PASS"
    fi
  done
  if [ "$all_pass" -eq 1 ]; then
    printf 'PASS%s' "$detail"
  else
    printf 'FAIL%s' "$detail"
  fi
}

# ---------------------------------------------------------------------------
# Profile sanity pre-check — the fail-open guard. Run before ANY case, on
# BOTH generated profiles. A profile that lost its deny-root lines would
# make every subsequent "allow" case pass for the wrong reason, so this
# aborts the whole run rather than letting that happen silently.
#
# Returns via globals: PRECHECK_OK=0/1, PRECHECK_DETAIL=<message>.
# ---------------------------------------------------------------------------
profile_precheck() {
  local profile="$1" label="$2"
  PRECHECK_OK=1
  PRECHECK_DETAIL=""

  if [ ! -s "$profile" ]; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: profile is empty or missing: $profile"
    return
  fi

  local first_line
  first_line="$(head -n1 "$profile")"
  if [ "$first_line" != "(version 1)" ]; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: first line is not '(version 1)': got [$first_line]"
    return
  fi

  if ! grep -qF '(allow default)' "$profile"; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: missing '(allow default)'"
    return
  fi

  local expected_root deny_read deny_write
  expected_root="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$PROTECTED_ROOT")"
  deny_read="(deny file-read* (subpath \"$expected_root\"))"
  deny_write="(deny file-write* (subpath \"$expected_root\"))"

  if ! grep -qF "$deny_read" "$profile"; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: missing deny-root file-read* line for $expected_root"
    return
  fi
  if ! grep -qF "$deny_write" "$profile"; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: missing deny-root file-write* line for $expected_root"
    return
  fi

  local deny_line_num punch_line_num
  deny_line_num="$(grep -nF "$deny_read" "$profile" | head -1 | cut -d: -f1)"
  punch_line_num="$(grep -nF '(allow file-read* (subpath' "$profile" | head -1 | cut -d: -f1)"

  if [ -z "$punch_line_num" ]; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: no allow file-read* punch-through line found at all (fail-open guard: nothing is punched through a deny-everything-under-\$HOME profile)"
    return
  fi
  if [ "$punch_line_num" -le "$deny_line_num" ]; then
    PRECHECK_OK=0
    PRECHECK_DETAIL="$label: first allow punch-through (line $punch_line_num) is not after the deny-root lines (line $deny_line_num) — SBPL is last-match-wins, so this ordering would make the punch-through ineffective"
    return
  fi
}

# ---------------------------------------------------------------------------
# NEGATIVE CONTROL MODE — proves this verifier can detect a fail-open
# sandbox. Deliberately separate flow from the normal run below: it never
# reaches Group P, never touches the production profile, and has its own
# exit contract (0 = the negative control demonstrated the failure it set
# out to demonstrate; 1 = the verifier itself is broken, i.e. it reported a
# PASS it should not have).
# ---------------------------------------------------------------------------
if [ "$NEGATIVE_CONTROL" -eq 1 ]; then
  vlog "=== NEGATIVE CONTROL MODE ==="

  "$SCRIPT_DIR/make_fixtures.sh" --root "$FIXTURES_ROOT" > "$OUT_DIR/fixture-manifest.txt"

  python3 "$SCRIPT_DIR/gen_sandbox_profile.py" \
    --allowed-repos "$FIXTURES_ROOT/allowed_repos.test.json" \
    --protected-root "$PROTECTED_ROOT" \
    --out "$FIXTURE_SB" 2> "$OUT_DIR/gen-fixture.stderr"

  # Deliberately replace the fixture profile with a fail-open one: no deny
  # rules at all, just `(allow default)`.
  printf '(version 1)\n(allow default)\n' > "$FIXTURE_SB"
  vlog "fail-open fixture.sb written to $FIXTURE_SB:"
  vlog "$(cat "$FIXTURE_SB")"

  if [ "$NEGATIVE_CONTROL_SKIP_PRECHECK" -eq 0 ]; then
    profile_precheck "$FIXTURE_SB" "fixture"
    if [ "$PRECHECK_OK" -eq 0 ]; then
      vlog "NEGATIVE-CONTROL PASSED: profile sanity pre-check correctly rejected the fail-open profile ($PRECHECK_DETAIL)"
      exit 0
    fi
    vlog "NEGATIVE-CONTROL FAILED: profile sanity pre-check did NOT reject a deny-less profile"
    exit 1
  fi

  vlog "(pre-check skipped by --negative-control-skip-precheck; running Group F deny cases against the fail-open profile)"

  FX="$FIXTURES_ROOT"
  ANY_FALSE_PASS=0
  ANY_UNEXPECTED=0

  "$SCRIPT_DIR/assert_denied.sh" --label F2-negctl --profile "$FIXTURE_SB" --expect deny --target secret.txt \
    -- /bin/cat "$FX/forbidden/secret.txt" > "$OUT_DIR/F2-negctl.out" 2>&1
  F2_NEGCTL_RC=$?

  "$SCRIPT_DIR/assert_denied.sh" --label F4-negctl --profile "$FIXTURE_SB" --expect deny --target secret.txt \
    -- /bin/sh -c "cat $FX/forbidden/secret.txt" > "$OUT_DIR/F4-negctl.out" 2>&1
  F4_NEGCTL_RC=$?

  "$SCRIPT_DIR/assert_denied.sh" --label F5-negctl --profile "$FIXTURE_SB" --expect deny --target canary.txt \
    -- /bin/cat "$FX/allowed_extra_should_not_match/canary.txt" > "$OUT_DIR/F5-negctl.out" 2>&1
  F5_NEGCTL_RC=$?

  "$SCRIPT_DIR/assert_denied.sh" --label F7-negctl --profile "$FIXTURE_SB" --expect deny --target secret.txt \
    -- /bin/cat "$FX/allowed/escape-link/secret.txt" > "$OUT_DIR/F7-negctl.out" 2>&1
  F7_NEGCTL_RC=$?

  for out in "$OUT_DIR"/F2-negctl.out "$OUT_DIR"/F4-negctl.out "$OUT_DIR"/F5-negctl.out "$OUT_DIR"/F7-negctl.out; do
    LINE="$(grep '^CASE' "$out")"
    vlog "$LINE"
    if printf '%s' "$LINE" | grep -q ' PASS '; then
      ANY_FALSE_PASS=1
    elif ! printf '%s' "$LINE" | grep -q 'not-denied'; then
      ANY_UNEXPECTED=1
    fi
  done

  if [ "$ANY_FALSE_PASS" -eq 1 ]; then
    vlog "NEGATIVE-CONTROL FAILED: verifier reports PASS against a fail-open profile"
    exit 1
  fi
  if [ "$ANY_UNEXPECTED" -eq 1 ]; then
    vlog "NEGATIVE-CONTROL FAILED: at least one deny case neither passed falsely nor reported not-denied (unexpected classification) -- inspect the CASE lines above"
    exit 1
  fi
  vlog "NEGATIVE-CONTROL PASSED: every Group F deny case reported FAIL not-denied against the fail-open profile — the verifier correctly detected the fail-open sandbox"
  exit 0
fi

# ---------------------------------------------------------------------------
# Setup.
# ---------------------------------------------------------------------------
vlog "=== phase-03 verify_sandbox.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog "OUT_DIR=$OUT_DIR"

"$SCRIPT_DIR/make_fixtures.sh" --root "$FIXTURES_ROOT" > "$OUT_DIR/fixture-manifest.txt"

python3 "$SCRIPT_DIR/gen_sandbox_profile.py" \
  --allowed-repos "$FIXTURES_ROOT/allowed_repos.test.json" \
  --protected-root "$PROTECTED_ROOT" \
  --out "$FIXTURE_SB" 2> "$OUT_DIR/gen-fixture.stderr"
GEN_FIXTURE_RC=$?
if [ "$GEN_FIXTURE_RC" -ne 0 ]; then
  vlog "ABORT: fixture profile generation failed (see $OUT_DIR/gen-fixture.stderr)"
  exit 1
fi

EXTRA_ALLOW_ARGS=(--extra-allow "$CLINE_DATA_DIR")
if [ -n "${EXTRA_ALLOW_PATHS:-}" ]; then
  IFS=':' read -r -a _extra_allow_arr <<< "$EXTRA_ALLOW_PATHS"
  for _p in "${_extra_allow_arr[@]}"; do
    if [ -n "$_p" ]; then
      EXTRA_ALLOW_ARGS+=(--extra-allow "$_p")
    fi
  done
fi

python3 "$SCRIPT_DIR/gen_sandbox_profile.py" \
  --allowed-repos "$ALLOWED_REPOS_JSON" \
  --protected-root "$PROTECTED_ROOT" \
  "${EXTRA_ALLOW_ARGS[@]}" \
  --out "$PRODUCTION_SB" 2> "$OUT_DIR/gen-production.stderr"
GEN_PRODUCTION_RC=$?
if [ "$GEN_PRODUCTION_RC" -ne 0 ]; then
  vlog "ABORT: production profile generation failed (see $OUT_DIR/gen-production.stderr)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Profile sanity pre-check (fail-open guard) on BOTH profiles, before any
# case runs.
# ---------------------------------------------------------------------------
profile_precheck "$FIXTURE_SB" "fixture"
if [ "$PRECHECK_OK" -eq 0 ]; then
  vlog "ABORT: profile sanity pre-check FAILED: $PRECHECK_DETAIL"
  exit 1
fi
vlog "profile sanity pre-check: fixture.sb OK"

profile_precheck "$PRODUCTION_SB" "production"
if [ "$PRECHECK_OK" -eq 0 ]; then
  vlog "ABORT: profile sanity pre-check FAILED: $PRECHECK_DETAIL"
  exit 1
fi
vlog "profile sanity pre-check: production.sb OK"

FX="$FIXTURES_ROOT"

# ---------------------------------------------------------------------------
# Group F — fixture profile.
# ---------------------------------------------------------------------------
"$SCRIPT_DIR/assert_denied.sh" --label F1 --profile "$FIXTURE_SB" --expect allow --expect-stdout 'ALLOWED-CANARY-OK' \
  -- /bin/cat "$FX/allowed/canary.txt"
record_case "F1" $?
vlog "$(grep '^CASE' "$OUT_DIR/F1.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label F2 --profile "$FIXTURE_SB" --expect deny --target secret.txt \
  -- /bin/cat "$FX/forbidden/secret.txt"
record_case "F2" $?
vlog "$(grep '^CASE' "$OUT_DIR/F2.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label F3 --profile "$FIXTURE_SB" --expect deny --write-target "$FX/forbidden/newfile.txt" \
  -- /bin/sh -c "echo x > $FX/forbidden/newfile.txt"
record_case "F3" $?
vlog "$(grep '^CASE' "$OUT_DIR/F3.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label F4 --profile "$FIXTURE_SB" --expect deny --target secret.txt \
  -- /bin/sh -c "cat $FX/forbidden/secret.txt"
record_case "F4" $?
vlog "$(grep '^CASE' "$OUT_DIR/F4.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label F5 --profile "$FIXTURE_SB" --expect deny --target canary.txt \
  -- /bin/cat "$FX/allowed_extra_should_not_match/canary.txt"
record_case "F5" $?
vlog "$(grep '^CASE' "$OUT_DIR/F5.txt" 2>/dev/null || true)"
if grep -q 'PREFIX-TRAP-CANARY' "$OUT_DIR/F5.txt" 2>/dev/null; then
  vlog "CASE F5-canary-leak FAIL PREFIX-TRAP-CANARY leaked into captured stdout"
  record_case "F5-canary-leak" 1
else
  record_case "F5-canary-leak" 0
fi

"$SCRIPT_DIR/assert_denied.sh" --label F6 --profile "$FIXTURE_SB" --expect allow --expect-stdout 'CANON-CANARY-OK' \
  -- /bin/cat "$FX/symlinked/real/canary.txt"
record_case "F6" $?
vlog "$(grep '^CASE' "$OUT_DIR/F6.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label F7 --profile "$FIXTURE_SB" --expect deny --target secret.txt \
  -- /bin/cat "$FX/allowed/escape-link/secret.txt"
record_case "F7" $?
vlog "$(grep '^CASE' "$OUT_DIR/F7.txt" 2>/dev/null || true)"

# F8: the in-process/subprocess probe. NOT routed through assert_denied.sh
# (it makes 7 assertions inside one process) -- every DENIED/ERROR/SUCCEEDED
# verdict below comes from probe_fs.js's own text output, never from the
# exit code of the sandbox-exec invocation.
#
# Two real, live-reproduced environmental pitfalls this works around
# (neither is a weakening of the assertion -- both are plumbing so Node can
# start at all under this profile; SBX-02/03 discrimination is unchanged):
#   1. Redirecting the sandboxed process's stdout/stderr directly to a FILE
#      under a path this profile does NOT punch through (e.g. $OUT_DIR,
#      which lives under $HOME/.../phase-03/results/) crashes Node with
#      SIGABRT during its own startup the moment it touches that fd's
#      backing path. Capturing via a command-substitution PIPE instead
#      (no named filesystem path involved) avoids this entirely; the text
#      is written to $PROBE_OUT afterward, outside the sandbox.
#   2. probe_fs.js itself lives under phase-03/sandbox/, which this fixture
#      profile does not punch through, so plain `node <path>` cannot even
#      read its own entry script (MODULE_NOT_FOUND), and Node's default
#      module-resolution realpath walk additionally lstat()s every
#      ancestor directory up to /, including $HOME itself, which is denied
#      metadata access outside the punched-through subpaths (EPERM lstat).
#      Fixed by copying probe_fs.js into the fixture's already-punched-
#      through $FX/allowed/ for the duration of this one case, and passing
#      --preserve-symlinks-main so Node skips the ancestor-walking realpath
#      resolution of the main script.
PROBE_COPY="$FX/allowed/probe_fs.js"
cp "$SCRIPT_DIR/probe_fs.js" "$PROBE_COPY"
PROBE_OUT="$OUT_DIR/probe-sandboxed.txt"
PROBE_TEXT="$(/usr/bin/sandbox-exec -f "$FIXTURE_SB" /usr/bin/env \
  ALLOWED_PATH="$FX/allowed" FORBIDDEN_PATH="$FX/forbidden" \
  node --preserve-symlinks-main "$PROBE_COPY" 2>&1)"
F8_SANDBOX_EXEC_RC=$?
rm -f "$PROBE_COPY"
printf '%s\n' "$PROBE_TEXT" > "$PROBE_OUT"

F8_OK=1
F8_DETAIL=""
if [ "$F8_SANDBOX_EXEC_RC" -gt 128 ]; then
  F8_OK=0
  F8_DETAIL="sandbox-exec crashed with signal (rc=$F8_SANDBOX_EXEC_RC)"
elif ! grep -q '^PROBE-SUMMARY' "$PROBE_OUT"; then
  F8_OK=0
  F8_DETAIL="probe_fs.js did not print PROBE-SUMMARY -- it did not run to completion"
else
  for check in "inproc-read-allowed:SUCCEEDED" "inproc-write-allowed:SUCCEEDED" \
               "inproc-read-forbidden:DENIED" "inproc-write-forbidden:DENIED" \
               "subproc-read-forbidden:DENIED" "subproc-write-forbidden:DENIED" \
               "escape-symlink-read:DENIED"
  do
    want_label="${check%%:*}"
    want_result="${check##*:}"
    line="$(grep "^PROBE $want_label " "$PROBE_OUT" || true)"
    if [ -z "$line" ]; then
      F8_OK=0
      F8_DETAIL="$F8_DETAIL missing-line:$want_label"
      continue
    fi
    got_result="$(printf '%s' "$line" | awk '{print $3}')"
    if [ "$got_result" = "ERROR" ]; then
      F8_OK=0
      F8_DETAIL="$F8_DETAIL ERROR-result:[$line]"
    elif [ "$got_result" != "$want_result" ]; then
      F8_OK=0
      F8_DETAIL="$F8_DETAIL mismatch:[$line] want=$want_result"
    fi
  done
fi
if [ "$F8_OK" -eq 1 ]; then
  vlog "CASE F8 PASS probe (7/7 checks correct: SBX-02/SBX-03 same mechanism)"
  record_case "F8" 0
else
  vlog "CASE F8 FAIL probe $F8_DETAIL"
  record_case "F8" 1
fi

# ---------------------------------------------------------------------------
# Group P — production profile (real workspace/ALLOWED_REPOS.json).
# ---------------------------------------------------------------------------
"$SCRIPT_DIR/assert_denied.sh" --label P1 --profile "$PRODUCTION_SB" --expect allow \
  -- /bin/cat "$PROJECT_ROOT/workspace/scratch-repo/README.md"
record_case "P1" $?
vlog "$(grep '^CASE' "$OUT_DIR/P1.txt" 2>/dev/null || true)"

PROBE_WRITE_FILE="$PROJECT_ROOT/workspace/scratch-repo/.sbx-write-probe"
rm -f "$PROBE_WRITE_FILE"
"$SCRIPT_DIR/assert_denied.sh" --label P2 --profile "$PRODUCTION_SB" --expect allow --skip-control \
  -- /bin/sh -c "echo ok > $PROBE_WRITE_FILE"
record_case "P2" $?
vlog "$(grep '^CASE' "$OUT_DIR/P2.txt" 2>/dev/null || true)"
rm -f "$PROBE_WRITE_FILE"

"$SCRIPT_DIR/assert_denied.sh" --label P3 --profile "$PRODUCTION_SB" --expect deny --target CANARY.txt \
  -- /bin/cat "$BENCH_DIR/runs/CANARY.txt"
record_case "P3" $?
vlog "$(grep '^CASE' "$OUT_DIR/P3.txt" 2>/dev/null || true)"

# NOT `cat $BENCH_DIR/runs/*` -- once Phase 7 committed a real run directory
# (bench/runs/<UTC>-phase07/, sibling to CANARY.txt, per its own PLAN.md
# artifact spec) alongside CANARY.txt, that glob's control run (unsandboxed,
# below) legitimately failed with rc=1 ("cat: bench/runs/<dir>: Is a
# directory") -- nothing to do with sandbox enforcement, purely `cat`'s
# normal behavior on a directory argument -- which made assert_denied.sh
# bail out at its own control-run guard before ever invoking the sandboxed
# command (observed live 2026-08-30, 07-03 smoke run post-run gate sweep).
# `find -type f -exec cat {} +` asserts the same thing (every FILE under
# bench/runs/ is unreadable from inside the sandbox) but is robust to
# subdirectories, and is if anything a broader assertion (recurses into any
# subdirectory) rather than a weaker one.
"$SCRIPT_DIR/assert_denied.sh" --label P4 --profile "$PRODUCTION_SB" --expect deny \
  -- /bin/sh -c "find \"$BENCH_DIR/runs\" -type f -exec cat {} +"
record_case "P4" $?
vlog "$(grep '^CASE' "$OUT_DIR/P4.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label P5 --profile "$PRODUCTION_SB" --expect deny \
  -- /bin/cat "$ALLOWED_REPOS_JSON"
record_case "P5" $?
vlog "$(grep '^CASE' "$OUT_DIR/P5.txt" 2>/dev/null || true)"

"$SCRIPT_DIR/assert_denied.sh" --label P6 --profile "$PRODUCTION_SB" --expect deny \
  -- /bin/cat "$PROJECT_ROOT/.planning/STATE.md"
record_case "P6" $?
vlog "$(grep '^CASE' "$OUT_DIR/P6.txt" 2>/dev/null || true)"

# Canary-leak sweep: the canary content must never appear in ANY captured
# sandboxed stdout, in any file in $OUT_DIR, outside the profiles/verdict.
CANARY_LEAK="$(grep -rlF "$CANARY_STRING" "$OUT_DIR" 2>/dev/null | grep -v -e '/sbx-verdict\.txt$' -e '/README\.md$' -e '\.sb$' || true)"
if [ -n "$CANARY_LEAK" ]; then
  record_case "CANARY-LEAK" 1
  vlog "CASE CANARY-LEAK FAIL canary string found in: $CANARY_LEAK"
else
  record_case "CANARY-LEAK" 0
fi

# ---------------------------------------------------------------------------
# Criterion 1 (SBX-01): ALLOWED_REPOS.json exists, parses, every entry
# resolves to an existing directory, and NO entry equals or is an ancestor
# of realpath(BENCH_DIR). This direction is deliberate: the misconfiguration
# to prevent is someone whitelisting the repo root (under which bench/
# lives), NOT a repo accidentally placed inside bench/.
# ---------------------------------------------------------------------------
CRIT1_OUTPUT="$(ALLOWED_REPOS_JSON="$ALLOWED_REPOS_JSON" BENCH_DIR="$BENCH_DIR" python3 - <<'PY'
import json
import os
import sys

allowed_repos_json = os.environ["ALLOWED_REPOS_JSON"]
bench_dir = os.environ["BENCH_DIR"]

if not os.path.isfile(allowed_repos_json):
    print("FAIL missing-file:%s" % allowed_repos_json)
    sys.exit(1)

try:
    with open(allowed_repos_json) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print("FAIL invalid-json:%s" % e)
    sys.exit(1)

repos = data.get("repos", [])
if not repos:
    print("FAIL empty-repos-list")
    sys.exit(1)

bench_real = os.path.realpath(bench_dir)

for raw in repos:
    real = os.path.realpath(raw)
    if not os.path.isdir(real):
        print("FAIL entry-not-a-directory:%s->%s" % (raw, real))
        sys.exit(1)
    # Direction is load-bearing: bench_real must not equal, and must not be
    # a descendant of (start with realpath(entry) + os.sep), any entry.
    if bench_real == real or bench_real.startswith(real + os.sep):
        print("FAIL bench-dir-is-descendant-of-or-equal-to-entry:entry=%s bench=%s" % (real, bench_real))
        sys.exit(1)

print("PASS entries=%d bench_real=%s" % (len(repos), bench_real))
sys.exit(0)
PY
)"
CRIT1_RC=$?
vlog "criterion-1-check: $CRIT1_OUTPUT"

# ---------------------------------------------------------------------------
# Verdict.
# ---------------------------------------------------------------------------
if [ "$CRIT1_RC" -eq 0 ]; then
  CRIT1_RESULT="PASS $CRIT1_OUTPUT"
else
  CRIT1_RESULT="FAIL $CRIT1_OUTPUT"
fi
CRIT2_RESULT="$(criterion_verdict F2 F3 F8)"
CRIT3_RESULT="$(criterion_verdict F4 F8)"
CRIT4_RESULT="$(criterion_verdict P3 P4 CANARY-LEAK)"

vlog ""
vlog "CRITERION 1 (SBX-01 ALLOWED_REPOS.json exists and is the source of truth): $CRIT1_RESULT"
vlog "CRITERION 2 (SBX-02 read/write outside the whitelist actually fails): $CRIT2_RESULT"
vlog "CRITERION 3 (SBX-03 execute_command outside the whitelist is blocked by sandbox-exec): $CRIT3_RESULT"
vlog "CRITERION 4 (SBX-04 bench results dir unreadable from inside the sandbox): $CRIT4_RESULT"

TOTAL_CASES=${#CASE_IDS[@]}
PASSED_CASES=0
CRASHED_CASES=0
for i in "${!CASE_IDS[@]}"; do
  rc="${CASE_RCS[$i]}"
  if [ "$rc" = "0" ]; then
    PASSED_CASES=$((PASSED_CASES + 1))
  elif [ "$rc" = "2" ]; then
    CRASHED_CASES=$((CRASHED_CASES + 1))
  fi
done

vlog ""
vlog "CASES $PASSED_CASES/$TOTAL_CASES"
vlog "CRASHED $CRASHED_CASES"

OVERALL_RC=0
if [ "$CRASHED_CASES" -gt 0 ]; then
  OVERALL_RC=2
elif [ "$CRIT1_RC" -ne 0 ] || [[ "$CRIT2_RESULT" == FAIL* ]] || [[ "$CRIT3_RESULT" == FAIL* ]] || [[ "$CRIT4_RESULT" == FAIL* ]]; then
  OVERALL_RC=1
fi

vlog ""
if [ "$OVERALL_RC" -eq 0 ]; then
  vlog "VERIFY_SANDBOX: PASS"
else
  vlog "VERIFY_SANDBOX: FAIL (rc=$OVERALL_RC)"
fi

echo "RESULTS_DIR=$OUT_DIR"
exit "$OVERALL_RC"
