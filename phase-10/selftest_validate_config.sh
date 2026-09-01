#!/usr/bin/env bash
# selftest_validate_config.sh -- negative controls for validate_config.sh.
#
# Phase 9's precedent governs how a safety envelope is accepted: it is
# believed only after it has been seeded with a real mutation and observed
# to exit non-zero -- never merely asserted to work. This script seeds four
# MUTANT configs (copied into a throwaway tempdir, never near the live path)
# and runs the full 4-rung ladder against each, recording what actually
# happened. It also re-runs the clean, unmutated candidate in the same
# session, so a ladder that fails everything cannot masquerade as strict.
#
# Outcome neutrality: MUTANT-4 (a schema-invalid litellm_params: null) is a
# MEASUREMENT, not an assertion. If the real litellm binary boots it anyway,
# that is a real, useful finding about rung 4's limits -- recorded, not
# hidden, not retried away.
#
# This script's own exit code is non-zero ONLY if MUTANT-1, MUTANT-2 or
# MUTANT-3 was NOT caught, or if the clean candidate failed -- those three
# are mechanical/deterministic. MUTANT-4's outcome never affects this exit
# code.
#
# bash 3.2 compatible (no declare -A) -- this machine's default /bin/bash.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE="$HERE/config/config.yaml.candidate"
VALIDATE="$HERE/validate_config.sh"
PORT=4010

if [ ! -f "$CANDIDATE" ]; then
  echo "FATAL: candidate not found at $CANDIDATE -- run build_candidate.sh first" >&2
  exit 2
fi
if [ ! -x "$VALIDATE" ]; then
  echo "FATAL: $VALIDATE not found or not executable" >&2
  exit 2
fi

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/phase10-selftest.XXXXXX")
cleanup_workdir() {
  rm -rf "$WORKDIR"
}
trap cleanup_workdir EXIT

# validate_config.sh creates a brand-new run dir on EVERY invocation and
# overwrites CURRENT_VALIDATE_RUN each time -- this self-test calls it 5
# times (clean + 4 mutants), so by the time the last mutant runs,
# CURRENT_VALIDATE_RUN would otherwise point at MUTANT-4's directory, not a
# directory holding both a 4-row ladder.tsv and a 5-row selftest.tsv. Fix:
# anchor this self-test's own evidence (selftest.tsv, per-mutant ladder.tsv
# copies) in the CLEAN candidate's run dir -- captured right after that call
# below -- and restore CURRENT_VALIDATE_RUN to point at it once every mutant
# has run, so the final canonical run dir holds everything together.
CLEAN_RUN_DIR=""
log_row() {
  # mutant  rung_expected  rung_actual  exit_code  verdict
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$SELFTEST_TSV"
}

port_is_free() {
  ! lsof -nP -iTCP:"$PORT" -sTCP:LISTEN > /dev/null 2>&1
}

wait_port_free() {
  local tries=0
  while ! port_is_free && [ "$tries" -lt 10 ]; do
    sleep 1
    tries=$((tries + 1))
  done
  port_is_free
}

# run_ladder <config-path> <label>
# Sets LAST_EXIT, LAST_FAILED_RUNG ("" if all 4 rungs passed), LAST_RUN_DIR.
run_ladder() {
  local cfg="$1" label="$2"
  local log="$WORKDIR/${label}.ladder.log"
  bash "$VALIDATE" "$cfg" --port "$PORT" > "$log" 2>&1
  LAST_EXIT=$?
  local mini_run
  mini_run=$(cat "$HERE/results/CURRENT_VALIDATE_RUN" 2>/dev/null || true)
  LAST_RUN_DIR="$mini_run"
  LAST_FAILED_RUNG=""
  if [ -n "$mini_run" ] && [ -f "$mini_run/ladder.tsv" ]; then
    cp "$mini_run/ladder.tsv" "$WORKDIR/${label}.ladder.tsv"
    LAST_FAILED_RUNG=$(awk -F'\t' '$3=="FAIL"{print $1; exit}' "$mini_run/ladder.tsv")
  fi
  if ! wait_port_free; then
    echo "WARNING: port $PORT still bound after $label ladder run (waited 10s)" >&2
  fi
}

# ---- build the four mutants into $WORKDIR (never near the live path) ----

MUTANT1="$WORKDIR/mutant1-yaml-broken.yaml"
MUTANT2="$WORKDIR/mutant2-drop-params.yaml"
MUTANT3="$WORKDIR/mutant3-baseline-touched.yaml"
MUTANT4="$WORKDIR/mutant4-schema-invalid.yaml"

SRC="$CANDIDATE" DST="$MUTANT1" python3 - <<'PY'
import os
src = os.environ["SRC"]
dst = os.environ["DST"]
with open(src) as f:
    text = f.read()
old = "litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }"
count = text.count(old)
if count < 1:
    raise SystemExit(f"MUTANT-1 anchor line not found in {src} (expected the qwen-local deprecated inline entry)")
# Drop the trailing " }" to leave an unclosed flow mapping -- invalid YAML.
new = old[: -len(" }")]
text = text.replace(old, new, 1)
with open(dst, "w") as f:
    f.write(text)
print(f"MUTANT-1 written: {dst} (unclosed '{{' seeded, {count} candidate anchor(s) found, 1 mutated)")
PY

SRC="$CANDIDATE" DST="$MUTANT2" python3 - <<'PY'
import os
src = os.environ["SRC"]
dst = os.environ["DST"]
with open(src) as f:
    text = f.read()
if not text.endswith("\n"):
    text += "\n"
text += "\nlitellm_settings:\n  drop_params: true\n"
with open(dst, "w") as f:
    f.write(text)
print(f"MUTANT-2 written: {dst} (litellm_settings.drop_params: true appended)")
PY

SRC="$CANDIDATE" DST="$MUTANT3" python3 - <<'PY'
import os
import re
src = os.environ["SRC"]
dst = os.environ["DST"]
with open(src) as f:
    text = f.read()
pattern = re.compile(
    r"(- model_name: flashnext\n    litellm_params:\n      model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3\.8-Flash-Next-MLX-oQ4\n      api_base: )http://localhost:8011/v1"
)
new_text, n = pattern.subn(r"\g<1>http://localhost:8012/v1", text, count=1)
if n != 1:
    raise SystemExit("MUTANT-3 anchor (flashnext's api_base line) not found or matched more than once")
with open(dst, "w") as f:
    f.write(new_text)
print(f"MUTANT-3 written: {dst} (flashnext api_base changed 8011 -> 8012, {n} substitution)")
PY

SRC="$CANDIDATE" DST="$MUTANT4" python3 - <<'PY'
import os
src = os.environ["SRC"]
dst = os.environ["DST"]
with open(src) as f:
    text = f.read()
old = (
    "  - model_name: flashnext-act\n"
    "    litellm_params:\n"
    "      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4\n"
    "      api_base: http://localhost:8011/v1\n"
    "      api_key: dummy\n"
    "      enable_thinking: false\n"
)
new = "  - model_name: flashnext-act\n    litellm_params: null\n"
count = text.count(old)
if count != 1:
    raise SystemExit(f"MUTANT-4 anchor (flashnext-act's full litellm_params block) matched {count} times, expected 1")
text = text.replace(old, new, 1)
with open(dst, "w") as f:
    f.write(text)
print(f"MUTANT-4 written: {dst} (flashnext-act's litellm_params replaced with null)")
PY

echo ""
echo "=== positive control: clean, unmutated candidate must PASS all 4 rungs ==="
run_ladder "$CANDIDATE" "clean"
CLEAN_RUN_DIR="$LAST_RUN_DIR"
SELFTEST_TSV="$CLEAN_RUN_DIR/selftest.tsv"
: > "$SELFTEST_TSV"
echo "selftest evidence anchored in: $CLEAN_RUN_DIR (this run's own 4-row ladder.tsv lives here too)"
if [ "$LAST_EXIT" -eq 0 ] && [ -z "$LAST_FAILED_RUNG" ]; then
  echo "clean candidate: PASS (exit 0, no rung failed)"
  log_row "clean-candidate" "none" "none" "$LAST_EXIT" "PASS"
  CLEAN_OK=1
else
  echo "clean candidate: FAIL (exit=$LAST_EXIT, failed rung=${LAST_FAILED_RUNG:-<none-but-nonzero-exit>})"
  log_row "clean-candidate" "none" "${LAST_FAILED_RUNG:-unknown}" "$LAST_EXIT" "FAIL"
  CLEAN_OK=0
fi

classify() {
  # classify <expected-rung> <actual-rung> <exit-code>
  local expected="$1" actual="$2" exit_code="$3"
  if [ "$exit_code" -eq 0 ]; then
    echo "MISSED"
  elif [ "$actual" = "$expected" ]; then
    echo "CAUGHT"
  else
    echo "CAUGHT-BY-DIFFERENT-RUNG"
  fi
}

# Archives a mutant's own ladder.tsv/scratch-boot.log into CLEAN_RUN_DIR
# under a labeled prefix, so all evidence from this session ends up
# reachable from the one canonical run dir this script restores
# CURRENT_VALIDATE_RUN to at the end.
archive_mutant_run() {
  local label="$1"
  if [ -n "$LAST_RUN_DIR" ] && [ -d "$LAST_RUN_DIR" ]; then
    cp "$LAST_RUN_DIR/ladder.tsv" "$CLEAN_RUN_DIR/${label}-ladder.tsv" 2>/dev/null || true
    cp "$LAST_RUN_DIR/scratch-boot.log" "$CLEAN_RUN_DIR/${label}-scratch-boot.log" 2>/dev/null || true
    echo "  (evidence: $LAST_RUN_DIR, archived as $CLEAN_RUN_DIR/${label}-*.{tsv,log})"
  fi
}

echo ""
echo "=== MUTANT-1 yaml-broken (expected: rung 1 FAILs) ==="
run_ladder "$MUTANT1" "mutant1"
V1=$(classify 1 "$LAST_FAILED_RUNG" "$LAST_EXIT")
echo "MUTANT-1: exit=$LAST_EXIT failed_rung=${LAST_FAILED_RUNG:-none} -> $V1"
log_row "MUTANT-1-yaml-broken" "1" "${LAST_FAILED_RUNG:-none}" "$LAST_EXIT" "$V1"
archive_mutant_run "mutant1"

echo ""
echo "=== MUTANT-2 drop-params (expected: rung 2 FAILs -- the CFG-14 guard) ==="
run_ladder "$MUTANT2" "mutant2"
V2=$(classify 2 "$LAST_FAILED_RUNG" "$LAST_EXIT")
echo "MUTANT-2: exit=$LAST_EXIT failed_rung=${LAST_FAILED_RUNG:-none} -> $V2"
log_row "MUTANT-2-drop-params" "2" "${LAST_FAILED_RUNG:-none}" "$LAST_EXIT" "$V2"
archive_mutant_run "mutant2"

echo ""
echo "=== MUTANT-3 baseline-touched (expected: rung 3 FAILs -- the CFG-13 guard) ==="
run_ladder "$MUTANT3" "mutant3"
V3=$(classify 3 "$LAST_FAILED_RUNG" "$LAST_EXIT")
echo "MUTANT-3: exit=$LAST_EXIT failed_rung=${LAST_FAILED_RUNG:-none} -> $V3"
log_row "MUTANT-3-baseline-touched" "3" "${LAST_FAILED_RUNG:-none}" "$LAST_EXIT" "$V3"
archive_mutant_run "mutant3"

echo ""
echo "=== MUTANT-4 schema-invalid (expected: rung 4 FAILs -- but this is a MEASUREMENT, not an assertion) ==="
run_ladder "$MUTANT4" "mutant4"
V4=$(classify 4 "$LAST_FAILED_RUNG" "$LAST_EXIT")
echo "MUTANT-4: exit=$LAST_EXIT failed_rung=${LAST_FAILED_RUNG:-none} -> $V4"
if [ "$V4" = "MISSED" ]; then
  echo "FINDING: rung 4 (real litellm boot) did NOT reject litellm_params: null -- the real binary booted it anyway."
  echo "This means a successful scratch boot is NECESSARY but NOT SUFFICIENT evidence of config validity."
  echo "Recorded as a residual risk for plan 10-03, not engineered away."
fi
log_row "MUTANT-4-schema-invalid" "4" "${LAST_FAILED_RUNG:-none}" "$LAST_EXIT" "$V4"
archive_mutant_run "mutant4"

# Restore CURRENT_VALIDATE_RUN to the canonical clean-candidate run dir --
# without this, it would be left pointing at MUTANT-4's directory, which
# holds a deliberately-broken ladder.tsv, not the 4-PASS positive control.
echo "$CLEAN_RUN_DIR" > "$HERE/results/CURRENT_VALIDATE_RUN"

echo ""
echo "=== selftest.tsv (in $SELFTEST_TSV) ==="
cat "$SELFTEST_TSV"

# ---- final port sanity: nothing must be left listening ----
if ! port_is_free; then
  echo "FATAL: port $PORT is still bound after all self-test runs completed" >&2
  exit 1
fi

# ---- self-test's own exit code ----
# Non-zero ONLY if a mechanical/deterministic mutant (1, 2, 3) was not
# CAUGHT (in either sense -- exact rung or a different rung), or if the
# clean candidate itself failed. MUTANT-4's outcome never affects this.
FAILURES=0
if [ "$CLEAN_OK" -ne 1 ]; then
  echo "SELFTEST FAILURE: the clean, unmutated candidate did not pass cleanly." >&2
  FAILURES=$((FAILURES + 1))
fi
for pair in "MUTANT-1:$V1" "MUTANT-2:$V2" "MUTANT-3:$V3"; do
  name="${pair%%:*}"
  verdict="${pair#*:}"
  case "$verdict" in
    CAUGHT|CAUGHT-BY-DIFFERENT-RUNG) ;;
    *)
      echo "SELFTEST FAILURE: $name was not caught (verdict: $verdict) -- this is a mechanical guard and must fire." >&2
      FAILURES=$((FAILURES + 1))
      ;;
  esac
done

if [ "$FAILURES" -gt 0 ]; then
  echo "SELFTEST: $FAILURES deterministic check(s) failed." >&2
  exit 1
fi

echo "SELFTEST: all deterministic checks passed (clean candidate PASS; MUTANT-1/2/3 all caught)."
echo "MUTANT-4 (non-enforced measurement) verdict: $V4"
exit 0
