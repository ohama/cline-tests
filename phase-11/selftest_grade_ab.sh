#!/bin/bash
# selftest_grade_ab.sh -- proves grade_ab.py returns every verdict it claims to be able to return.
#
# Runs the real grader (not a mock) against hand-written fixture NDJSON files and requires the
# exact stated verdict (and, where relevant, qualifier) for each. Writes
# phase-11/fixtures/selftest.tsv and exits non-zero if any row is FAIL.
#
# bash 3.2 compatible: no associative arrays. Fixture rows are plain parallel arrays.

set -u
cd "$(dirname "$0")/.." || exit 1
REPO_ROOT="$(pwd)"
GRADER="$REPO_ROOT/phase-11/grade_ab.py"
FIXDIR="$REPO_ROOT/phase-11/fixtures"
OUT_TSV="$FIXDIR/selftest.tsv"

# Parallel arrays: fixture name | ndjson file | expected file | required verdict | required qualifier (or "-" if none)
FIXTURE_NAMES=(
  "f1-correct"
  "f2-wrong"
  "f3-noanswer"
  "f4-truncated"
  "f5-reasoning-only"
  "f6-malformed"
  "f7-empty"
  "f8-numeric"
  "f8-exact-normalized"
)
FIXTURE_NDJSON=(
  "$FIXDIR/f1-correct.ndjson"
  "$FIXDIR/f2-wrong.ndjson"
  "$FIXDIR/f3-noanswer.ndjson"
  "$FIXDIR/f4-truncated.ndjson"
  "$FIXDIR/f5-reasoning-only.ndjson"
  "$FIXDIR/f6-malformed.ndjson"
  "$FIXDIR/f7-empty.ndjson"
  "$FIXDIR/f8-numeric-vs-exact.ndjson"
  "$FIXDIR/f8-numeric-vs-exact.ndjson"
)
FIXTURE_EXPECTED=(
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-task.expected"
  "$FIXDIR/fixture-numeric.expected"
  "$FIXDIR/fixture-exact.expected"
)
FIXTURE_REQUIRED_VERDICT=(
  "correct"
  "incorrect"
  "no-answer"
  "no-output"
  "no-answer"
  "correct"
  "unparseable"
  "correct"
  "incorrect"
)
FIXTURE_REQUIRED_QUALIFIER=(
  "-"
  "-"
  "-"
  "-"
  "answer-seen-in-reasoning-only"
  "-"
  "-"
  "-"
  "-"
)

N=${#FIXTURE_NAMES[@]}
FAIL_COUNT=0

echo -e "fixture\trequired_verdict\tobserved_verdict\tobserved_qualifier\tPASS|FAIL" > "$OUT_TSV"

i=0
while [ "$i" -lt "$N" ]; do
  name="${FIXTURE_NAMES[$i]}"
  ndjson="${FIXTURE_NDJSON[$i]}"
  expected_file="${FIXTURE_EXPECTED[$i]}"
  required_verdict="${FIXTURE_REQUIRED_VERDICT[$i]}"
  required_qualifier="${FIXTURE_REQUIRED_QUALIFIER[$i]}"

  row=$(python3 "$GRADER" --ndjson "$ndjson" --expected "$expected_file" 2>/dev/null)
  observed_verdict=$(echo "$row" | cut -f2)
  observed_qualifier=$(echo "$row" | cut -f3)
  if [ -z "$observed_qualifier" ]; then
    observed_qualifier="-"
  fi

  status="PASS"
  if [ "$observed_verdict" != "$required_verdict" ]; then
    status="FAIL"
  fi
  if [ "$required_qualifier" != "-" ] && [ "$observed_qualifier" != "$required_qualifier" ]; then
    status="FAIL"
  fi

  if [ "$status" = "FAIL" ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  echo -e "${name}\t${required_verdict}\t${observed_verdict}\t${observed_qualifier}\t${status}" >> "$OUT_TSV"

  i=$((i + 1))
done

echo "--- selftest_grade_ab.sh results ---"
cat "$OUT_TSV"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "SELFTEST FAILED: $FAIL_COUNT row(s) did not match their required verdict/qualifier." >&2
  exit 1
fi

echo "SELFTEST PASSED: all $N fixture rows matched their required verdict/qualifier."
exit 0
