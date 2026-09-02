#!/usr/bin/env bash
# phase-11/verify_wrappers.sh — USE-02 / ROADMAP Phase 11 criterion 2.
#
# WHY THIS FILE EXISTS AT ALL (read before editing).
# A mode/alias mismatch and a `--thinking` leak are properties of an INVOCATION, not of any
# config file. `providers.json` records neither the mode flag nor which alias a given call
# used — Phase 10 confirmed `cline -m` leaves `model` at "flashnext" regardless of which alias
# actually ran (phase-10/VRF-04-OBSERVATION.md §1). There is nothing left to inspect after the
# fact in providers.json. So this checker inspects the WRAPPERS themselves: what they literally
# contain (Group A) and what argv they actually construct when run (Group B).
#
# GROUP A vs GROUP B — deliberately BOTH, not either/or.
# Group A (static) catches a wrong literal instantly and is cheap, but it can be fooled by
# correct-looking text that behaves wrong (e.g. the right variable name assigned, but a parser
# bug elsewhere in the file still leaks a flag through). Group B (behavioural) runs the real
# wrapper against phase-11/testing/stub-cline and inspects the argv it ACTUALLY built, so it
# exercises the real code path including any conditional logic — but it only tests the cases
# this script thinks to invoke. Keeping both means each covers the other's blind spot, the same
# argument phase-10/validate_config.sh rung 3 makes for keeping two overlapping checks. Phase 10
# shipped five instruments that reported clean while observing almost nothing
# (phase-10/PHASE-10-FINDINGS.md §4.6) — every check below is designed to be demonstrably able
# to fail (see phase-11/selftest_verify_wrappers.sh, which seeds real mutants and requires the
# real phase-01/config/verify_config.sh to exit non-zero on each one).
#
# ABSENCE IS A FAILURE, NOT A SKIP.
# If cline-plan, cline-act or wrapper.env is missing from $WRAPPER_DIR, this script FAILS. A
# "wrappers not present, skipping" branch that returned 0 would be exactly the
# instrument-that-observes-nothing pattern this phase exists to avoid.
#
# USAGE / ENV:
#   WRAPPER_DIR=<dir>              directory to check (default: this script's own directory,
#                                   i.e. the real phase-11/ wrappers). Point this at a mutant
#                                   copy to check a seeded defect instead — a one-variable change.
#   WRAPPER_CHECK_ALIAS_LIVE=1     opt-in, OFF BY DEFAULT (hard constraint: no network
#                                   dependency on verify_config.sh's default path). When set,
#                                   additionally curls http://127.0.0.1:4000/v1/models (litellm's
#                                   own model-list endpoint — gateway-only, zero model requests)
#                                   and asserts both configured aliases appear in .data[].id.
#                                   Exercised exactly once, deliberately, by plan 11-04 Task 3
#                                   Part A0 against the live gateway; never by default here.
#
# EXIT CODES: 0 = all assertions passed. 3 = at least one wrapper assertion failed (a DIFFERENT
# code from verify_config.sh's own providers.json exit code 1, so a caller can always tell a
# wrapper fault from a providers.json fault apart by exit code alone).
#
# Deliberately NOT `set -e` (phase-10/PHASE-10-FINDINGS.md §4.6 catalogues an outage sampler
# killed by `set -e` on the exact condition it existed to record; phase-11/wrapper_argv_test.sh
# makes the same choice for the same reason). Every non-zero exit this script cares about is
# captured explicitly.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="${WRAPPER_DIR:-$SCRIPT_DIR}"
STUB_BIN="$SCRIPT_DIR/testing/stub-cline"

FAIL_COUNT=0

fail() {
  echo "FAIL[WRAPPER]: $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

ok() {
  echo "OK[WRAPPER]: $1"
}

# ---------------------------------------------------------------------------
# Top-level absence gate. Absence of any of these three files is fatal — checked
# and reported before anything else runs, and before this script tries to source
# a wrapper.env that might not exist.
# ---------------------------------------------------------------------------
for f in cline-plan cline-act wrapper.env; do
  if [ ! -f "$WRAPPER_DIR/$f" ]; then
    fail "required file missing: $WRAPPER_DIR/$f"
  fi
done

if [ "$FAIL_COUNT" -ne 0 ]; then
  echo "FAIL[WRAPPER]: one or more required wrapper files are missing from $WRAPPER_DIR — cannot proceed" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# GROUP A — static assertions on file contents.
# ---------------------------------------------------------------------------

# Source wrapper.env directly: it is plain KEY=VALUE assignments (no side effects), and we need
# its values (WRAPPER_PLAN_ALIAS, WRAPPER_ACT_ALIAS, WRAPPER_PROVIDER, WRAPPER_CLINE_BIN, ...)
# for both Group A membership checks and Group B's expected-argv assertions.
# shellcheck source=/dev/null
. "$WRAPPER_DIR/wrapper.env"
: "${WRAPPER_PLAN_ALIAS:=}"
: "${WRAPPER_ACT_ALIAS:=}"
: "${WRAPPER_PROVIDER:=}"
: "${WRAPPER_CLINE_BIN:=}"

# --- aliases non-empty and different from each other ---
if [ -z "$WRAPPER_PLAN_ALIAS" ]; then
  fail "wrapper.env: WRAPPER_PLAN_ALIAS is empty"
fi
if [ -z "$WRAPPER_ACT_ALIAS" ]; then
  fail "wrapper.env: WRAPPER_ACT_ALIAS is empty"
fi
if [ -n "$WRAPPER_PLAN_ALIAS" ] && [ -n "$WRAPPER_ACT_ALIAS" ]; then
  if [ "$WRAPPER_PLAN_ALIAS" = "$WRAPPER_ACT_ALIAS" ]; then
    fail "wrapper.env: WRAPPER_PLAN_ALIAS and WRAPPER_ACT_ALIAS are identical ('$WRAPPER_PLAN_ALIAS') — mode and alias are not distinguishable (ROADMAP criterion 2 mode/alias mismatch)"
  else
    ok "WRAPPER_PLAN_ALIAS ('$WRAPPER_PLAN_ALIAS') and WRAPPER_ACT_ALIAS ('$WRAPPER_ACT_ALIAS') are non-empty and distinct"
  fi
fi

# --- outcome-neutral membership: USE-03 may revert the plan alias to plain 'flashnext' ---
# Neither may ever be flashnext-codex: calling that alias has been measured to kill the model
# server, so it is forbidden outright, with its own named message (never merged into the
# generic "not a known alias" branch).
case "$WRAPPER_PLAN_ALIAS" in
  flashnext-codex)
    fail "wrapper.env: WRAPPER_PLAN_ALIAS is 'flashnext-codex' — this alias has been measured to kill the model server; forbidden outright regardless of mode"
    ;;
  flashnext-plan|flashnext)
    ok "WRAPPER_PLAN_ALIAS='$WRAPPER_PLAN_ALIAS' is a known-good plan alias (outcome-neutral: USE-03 may revert to plain 'flashnext')"
    ;;
  *)
    fail "wrapper.env: WRAPPER_PLAN_ALIAS='$WRAPPER_PLAN_ALIAS' is not a known plan alias (expected 'flashnext-plan' or 'flashnext')"
    ;;
esac
case "$WRAPPER_ACT_ALIAS" in
  flashnext-codex)
    fail "wrapper.env: WRAPPER_ACT_ALIAS is 'flashnext-codex' — this alias has been measured to kill the model server; forbidden outright regardless of mode"
    ;;
  flashnext-act|flashnext)
    ok "WRAPPER_ACT_ALIAS='$WRAPPER_ACT_ALIAS' is a known-good act alias"
    ;;
  *)
    fail "wrapper.env: WRAPPER_ACT_ALIAS='$WRAPPER_ACT_ALIAS' is not a known act alias (expected 'flashnext-act' or 'flashnext')"
    ;;
esac

# --- cline-plan pairs -p with the plan alias; cline-act pairs no mode flag with the act alias ---
if grep -qE 'WRAPPER_MODE_FLAG="-p"' "$WRAPPER_DIR/cline-plan"; then
  ok "cline-plan sets WRAPPER_MODE_FLAG=\"-p\" (ROADMAP criterion 1/2 mode pairing)"
else
  fail "cline-plan does not set WRAPPER_MODE_FLAG=\"-p\" — mode/alias pairing broken (ROADMAP criterion 2)"
fi
if grep -qE 'WRAPPER_ALIAS="\$WRAPPER_PLAN_ALIAS"' "$WRAPPER_DIR/cline-plan"; then
  ok "cline-plan reads WRAPPER_ALIAS from \$WRAPPER_PLAN_ALIAS"
else
  fail "cline-plan does not set WRAPPER_ALIAS from \$WRAPPER_PLAN_ALIAS — possible mode/alias mismatch (ROADMAP criterion 2)"
fi

if grep -qE 'WRAPPER_MODE_FLAG=""' "$WRAPPER_DIR/cline-act"; then
  ok "cline-act sets WRAPPER_MODE_FLAG=\"\" (no mode flag — Act is the CLI's own default)"
else
  fail "cline-act does not set WRAPPER_MODE_FLAG=\"\" — mode/alias pairing broken (ROADMAP criterion 2)"
fi
if grep -qE 'WRAPPER_ALIAS="\$WRAPPER_ACT_ALIAS"' "$WRAPPER_DIR/cline-act"; then
  ok "cline-act reads WRAPPER_ALIAS from \$WRAPPER_ACT_ALIAS"
else
  fail "cline-act does not set WRAPPER_ALIAS from \$WRAPPER_ACT_ALIAS — possible mode/alias mismatch (ROADMAP criterion 2)"
fi

# cline-act must contain no -p/--plan token OUTSIDE COMMENTS (a trailing '#...' is stripped
# before matching, so a comment merely mentioning '-p' does not trip this).
ACT_CODE_ONLY="$(sed 's/#.*$//' "$WRAPPER_DIR/cline-act")"
if printf '%s\n' "$ACT_CODE_ONLY" | grep -Eq -- '(^|[^A-Za-z0-9_-])-p([^A-Za-z0-9_-]|$)|--plan'; then
  fail "cline-act contains a -p/--plan token outside comments — Act mode must never pass the plan mode flag"
else
  ok "cline-act contains no -p/--plan token outside comments"
fi

# --- neither wrapper contains a literal alias string (must go through wrapper.env) ---
LITERAL_ALIAS_HIT=0
for w in cline-plan cline-act; do
  for alias_val in "$WRAPPER_PLAN_ALIAS" "$WRAPPER_ACT_ALIAS"; do
    [ -n "$alias_val" ] || continue
    if grep -qF -- "$alias_val" "$WRAPPER_DIR/$w"; then
      fail "$w contains the literal alias string '$alias_val' — aliases must be read from wrapper.env only"
      LITERAL_ALIAS_HIT=1
    fi
  done
done
[ "$LITERAL_ALIAS_HIT" = "0" ] && ok "neither cline-plan nor cline-act contains a literal alias string"

# --- real binary referenced by absolute path ---
case "$WRAPPER_CLINE_BIN" in
  /*)
    ok "WRAPPER_CLINE_BIN is an absolute path ('$WRAPPER_CLINE_BIN')"
    ;;
  *)
    fail "wrapper.env: WRAPPER_CLINE_BIN is not an absolute path: '$WRAPPER_CLINE_BIN'"
    ;;
esac

# --- construction region extraction: from the first 'set --' through the invocation line that
# names "$CMD" (the resolved-binary variable). Printed unconditionally so the assertion below is
# auditable, not just asserted. This region is also what the "$@"/$* / bare-cline checks run
# against, deliberately narrowed to this region rather than the whole file, so that unrelated
# prose elsewhere (comments, echo/log strings mentioning "cline") cannot produce a false FAIL.
# ---------------------------------------------------------------------------
COMMON_SH="$WRAPPER_DIR/wrapper_common.sh"
if [ -f "$COMMON_SH" ]; then
  CONSTRUCTION_REGION="$(awk '
    /set --/ && !found { found=1 }
    found { print }
    found && /"\$CMD"/ { exit }
  ' "$COMMON_SH")"

  echo "--- construction region extracted from $COMMON_SH (for audit) ---"
  printf '%s\n' "$CONSTRUCTION_REGION"
  echo "--- end construction region ---"

  if [ -z "$CONSTRUCTION_REGION" ]; then
    fail "$COMMON_SH: could not locate a construction region (no 'set --' ... \"\$CMD\" invocation found) — cannot audit for caller-argument leakage"
  else
    # No unguarded "$@"/$* forwards a caller-argument ARRAY into the constructed command. The
    # legitimate mechanism only ever re-uses the bare, already-rebuilt "$@" (self-referential,
    # rebuilt fresh by the FIRST 'set --' in this region) — it never expands a NAMED array with
    # [@]/[*]. A named-array [@] or [*] expansion here (e.g. "${ORIG_ARGS[@]}") is exactly the
    # shape a caller-arg-preserving leak takes (phase-11/results/20260902T041615Z-argv/'s own
    # MUTANT-LEAKY). Bare "$*" is flagged unconditionally (the real wrapper never uses it).
    if printf '%s\n' "$CONSTRUCTION_REGION" | grep -Eq '\$\{?[A-Za-z_][A-Za-z0-9_]*\[[@*]\]\}?'; then
      fail "construction region in $COMMON_SH expands a named array with [@]/[*] — looks like a caller-argument passthrough leak (--thinking / -m would reach the real binary unfiltered)"
    elif printf '%s\n' "$CONSTRUCTION_REGION" | grep -Eq '(^|[^A-Za-z0-9_$])\$\*'; then
      fail "construction region in $COMMON_SH uses bare \$* — caller-argument passthrough leak"
    else
      ok "construction region in $COMMON_SH shows no named-array or \$* caller-argument passthrough"
    fi

    # Neither the wrapper nor the common file invokes a bare 'cline' — restricted to the
    # construction region alone (see comment above the region extraction for why).
    if printf '%s\n' "$CONSTRUCTION_REGION" | grep -Eq '(^|[^A-Za-z0-9_/.$-])cline([^A-Za-z0-9_-]|$)'; then
      fail "construction region in $COMMON_SH invokes a bare 'cline' rather than the resolved \$CMD/\$WRAPPER_CLINE_BIN variable"
    else
      ok "construction region in $COMMON_SH invokes the resolved binary variable, never a bare 'cline'"
    fi
  fi
else
  fail "$COMMON_SH is missing — cannot audit the single construction site"
fi

# --- optional, opt-in, OFF BY DEFAULT: live alias check against the gateway's own model list.
# /v1/models is served by litellm itself and costs ZERO model requests — it never reaches the
# model server. Exercised exactly once, deliberately, by plan 11-04 Task 3 Part A0; never here
# unless explicitly requested.
# ---------------------------------------------------------------------------
if [ "${WRAPPER_CHECK_ALIAS_LIVE:-0}" = "1" ]; then
  echo "WRAPPER_CHECK_ALIAS_LIVE=1 — querying http://127.0.0.1:4000/v1/models (gateway only, zero model requests)"
  LIVE_MODELS_JSON="$(curl -sf http://127.0.0.1:4000/v1/models 2>/dev/null || true)"
  if [ -z "$LIVE_MODELS_JSON" ]; then
    fail "WRAPPER_CHECK_ALIAS_LIVE=1 but curl to http://127.0.0.1:4000/v1/models failed or returned nothing"
  else
    for alias_val in "$WRAPPER_PLAN_ALIAS" "$WRAPPER_ACT_ALIAS"; do
      [ -n "$alias_val" ] || continue
      if printf '%s' "$LIVE_MODELS_JSON" | ALIAS_TO_FIND="$alias_val" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
ids = [m.get("id") for m in d.get("data", [])]
sys.exit(0 if os.environ["ALIAS_TO_FIND"] in ids else 1)
' 2>/dev/null; then
        ok "live check: alias '$alias_val' present in gateway .data[].id"
      else
        fail "live check: alias '$alias_val' NOT present in gateway .data[].id (http://127.0.0.1:4000/v1/models)"
      fi
    done
  fi
else
  ok "WRAPPER_CHECK_ALIAS_LIVE not set — live gateway check skipped (default, per hard constraint: no network dependency on the default path)"
fi

# ---------------------------------------------------------------------------
# GROUP B — behavioural assertions on real captured argv, against phase-11/testing/stub-cline.
# Deliberately sourced from THIS script's own directory ($SCRIPT_DIR), not $WRAPPER_DIR: the
# stub is invariant test infrastructure owned by plan 11-01, so a mutant copy of the wrapper set
# under test does not need its own copy of testing/ for this script to exercise it.
# ---------------------------------------------------------------------------
if [ ! -x "$STUB_BIN" ]; then
  fail "stub binary not found or not executable: $STUB_BIN — cannot run Group B behavioural assertions"
else
  GB_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/verify_wrappers.XXXXXX")"
  trap 'rm -rf "$GB_TMPDIR"' EXIT

  # --- argv-file parsing helpers (mirrors phase-11/wrapper_argv_test.sh's own, kept local here
  # so this script has no runtime dependency on a file plan 11-01 owns) ---
  argv_lines_from_file() {
    local file="$1" line in_run=0
    ARGV_LINES=()
    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "---RUN---") in_run=1; continue ;;
        "---ENV---") in_run=0; continue ;;
      esac
      [ "$in_run" = "1" ] && ARGV_LINES+=("$line")
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

  gb_run() {
    # $1=wrapper_name $2=argv_file -- rest=args to the wrapper
    local wname="$1" argv_file="$2"
    shift 2
    ( CLINE_WRAPPER_TEST=1 CLINE_WRAPPER_TEST_BIN="$STUB_BIN" STUB_ARGV_FILE="$argv_file" \
        VERIFY_CONFIG_NO_WRAPPER_CHECK=1 \
        "$WRAPPER_DIR/$wname" "$@" >"$GB_TMPDIR/${wname}.out" 2>"$GB_TMPDIR/${wname}.err" )
    return $?
  }

  # --- B1: cline-plan "wrapper-check" (positive) ---
  B1_ARGV="$GB_TMPDIR/b1.argv"
  rm -f "$B1_ARGV"
  gb_run cline-plan "$B1_ARGV" "wrapper-check"
  B1_RC=$?
  argv_lines_from_file "$B1_ARGV"
  B1_OK=1
  argv_has_exact "-p" || B1_OK=0
  argv_has_pair "-m" "$WRAPPER_PLAN_ALIAS" || B1_OK=0
  argv_has_pair "-P" "$WRAPPER_PROVIDER" || B1_OK=0
  [ "$(argv_count -m)" = "1" ] || B1_OK=0
  [ "$(argv_count --thinking)" = "0" ] || B1_OK=0
  if [ "$B1_RC" = "0" ] && [ "$B1_OK" = "1" ]; then
    ok "cline-plan 'wrapper-check' argv observed: $(printf '%s ' "${ARGV_LINES[@]:-<none>}")"
  else
    fail "cline-plan 'wrapper-check' behavioural assertion failed (exit=$B1_RC, expected -p, -m $WRAPPER_PLAN_ALIAS once, -P $WRAPPER_PROVIDER, zero --thinking) — observed argv: $(printf '%s ' "${ARGV_LINES[@]:-<none>}")"
  fi

  # --- B2: cline-act "wrapper-check" (positive) ---
  B2_ARGV="$GB_TMPDIR/b2.argv"
  rm -f "$B2_ARGV"
  gb_run cline-act "$B2_ARGV" "wrapper-check"
  B2_RC=$?
  argv_lines_from_file "$B2_ARGV"
  B2_OK=1
  argv_has_pair "-m" "$WRAPPER_ACT_ALIAS" || B2_OK=0
  argv_has_exact "-p" && B2_OK=0
  argv_has_exact "--plan" && B2_OK=0
  [ "$(argv_count -m)" = "1" ] || B2_OK=0
  [ "$(argv_count --thinking)" = "0" ] || B2_OK=0
  if [ "$B2_RC" = "0" ] && [ "$B2_OK" = "1" ]; then
    ok "cline-act 'wrapper-check' argv observed: $(printf '%s ' "${ARGV_LINES[@]:-<none>}")"
  else
    fail "cline-act 'wrapper-check' behavioural assertion failed (exit=$B2_RC, expected -m $WRAPPER_ACT_ALIAS once, no -p, no --plan, zero --thinking) — observed argv: $(printf '%s ' "${ARGV_LINES[@]:-<none>}")"
  fi

  # --- B3: cline-plan --thinking high "wrapper-check" — must be REFUSED, argv byte-unchanged.
  # This IS the USE-02 --thinking leak check. Pre-seeding a sentinel makes "byte-unchanged" a
  # real comparison rather than a trivial absent-both-times check.
  B3_ARGV="$GB_TMPDIR/b3.argv"
  printf 'SENTINEL-B3-UNTOUCHED\n' > "$B3_ARGV"
  B3_BEFORE_SHA="$(shasum -a 256 "$B3_ARGV")"
  gb_run cline-plan "$B3_ARGV" --thinking high "wrapper-check"
  B3_RC=$?
  B3_AFTER_SHA="$(shasum -a 256 "$B3_ARGV")"
  if [ "$B3_RC" -ne 0 ] && [ "$B3_BEFORE_SHA" = "$B3_AFTER_SHA" ]; then
    ok "cline-plan --thinking high 'wrapper-check' correctly refused (exit=$B3_RC), stub argv file byte-unchanged (USE-02 --thinking leak check)"
  else
    fail "cline-plan --thinking high 'wrapper-check' should exit non-zero and leave the stub argv file byte-unchanged (USE-02 --thinking leak check) — observed exit=$B3_RC, byte-unchanged=$([ "$B3_BEFORE_SHA" = "$B3_AFTER_SHA" ] && echo yes || echo no)"
  fi

  # --- B4: cline-act --thinking high "wrapper-check" — same as B3, other mode ---
  B4_ARGV="$GB_TMPDIR/b4.argv"
  printf 'SENTINEL-B4-UNTOUCHED\n' > "$B4_ARGV"
  B4_BEFORE_SHA="$(shasum -a 256 "$B4_ARGV")"
  gb_run cline-act "$B4_ARGV" --thinking high "wrapper-check"
  B4_RC=$?
  B4_AFTER_SHA="$(shasum -a 256 "$B4_ARGV")"
  if [ "$B4_RC" -ne 0 ] && [ "$B4_BEFORE_SHA" = "$B4_AFTER_SHA" ]; then
    ok "cline-act --thinking high 'wrapper-check' correctly refused (exit=$B4_RC), stub argv file byte-unchanged (USE-02 --thinking leak check)"
  else
    fail "cline-act --thinking high 'wrapper-check' should exit non-zero and leave the stub argv file byte-unchanged (USE-02 --thinking leak check) — observed exit=$B4_RC, byte-unchanged=$([ "$B4_BEFORE_SHA" = "$B4_AFTER_SHA" ] && echo yes || echo no)"
  fi

  # --- B5: cline-plan -m flashnext "wrapper-check" — must be REFUSED, argv byte-unchanged ---
  B5_ARGV="$GB_TMPDIR/b5.argv"
  printf 'SENTINEL-B5-UNTOUCHED\n' > "$B5_ARGV"
  B5_BEFORE_SHA="$(shasum -a 256 "$B5_ARGV")"
  gb_run cline-plan "$B5_ARGV" -m flashnext "wrapper-check"
  B5_RC=$?
  B5_AFTER_SHA="$(shasum -a 256 "$B5_ARGV")"
  if [ "$B5_RC" -ne 0 ] && [ "$B5_BEFORE_SHA" = "$B5_AFTER_SHA" ]; then
    ok "cline-plan -m flashnext 'wrapper-check' correctly refused (exit=$B5_RC), stub argv file byte-unchanged (-m override rejection check)"
  else
    fail "cline-plan -m flashnext 'wrapper-check' should exit non-zero and leave the stub argv file byte-unchanged (-m override rejection check) — observed exit=$B5_RC, byte-unchanged=$([ "$B5_BEFORE_SHA" = "$B5_AFTER_SHA" ] && echo yes || echo no)"
  fi

  rm -rf "$GB_TMPDIR"
  trap - EXIT
fi

# ---------------------------------------------------------------------------
# Final verdict.
# ---------------------------------------------------------------------------
if [ "$FAIL_COUNT" -ne 0 ]; then
  echo "FAIL[WRAPPER]: $FAIL_COUNT wrapper assertion(s) failed for $WRAPPER_DIR — see FAIL[WRAPPER] lines above" >&2
  exit 3
fi

ok "all wrapper assertions passed for $WRAPPER_DIR"
exit 0
