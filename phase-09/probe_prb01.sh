#!/usr/bin/env bash
# probe_prb01.sh — Phase 9 fresh, independent reproduction of PRB-01.
#
# Question (milestone gate, red): does `reasoning_effort: medium` at :8011 actually
# produce a non-empty `reasoning` field? 09-RESEARCH.md already answered YES once;
# this script re-runs the research's literal command (09-RESEARCH.md Q2) into a
# fresh run directory owned by this phase, plus a negative control the research
# did not run: identical body with `reasoning_effort` entirely omitted. The
# control is what actually discriminates "thinking-on-at-medium" from
# "thinking-is-always-on-regardless-of-effort".
#
# This script does NOT declare a gate verdict. It records fresh measurements.
# Adjudication against 09-RESEARCH.md's numbers is plan 09-04's job.
#
# NOTE: written for macOS's default /bin/bash (3.2, no associative arrays / no
# `declare -A`) -- deliberately avoids bash 4+ features.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib.sh
source "$SCRIPT_DIR/probe_lib.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root, so phase-09/results/... paths resolve

CURRENT_RUN_PTR="phase-09/results/CURRENT_PRB01_02_RUN"

wait_idle() {
  local attempt=0 idle_ok=0 last=""
  while [ "$attempt" -lt 10 ]; do
    last=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    if [[ "$last" == *"in_flight=0"* ]]; then
      idle_ok=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle before next probe (last: $last)" >&2
    return 1
  fi
}

# fire_prb01_request <effort|unspecified> <out_body_file> -> echoes HTTP code
fire_prb01_request() {
  local effort="$1" out_file="$2" http_code body
  if [ "$effort" = "unspecified" ]; then
    body="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2는?\"}],\"max_tokens\":64}"
  else
    body="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2는?\"}],\"max_tokens\":64,\"reasoning_effort\":\"$effort\"}"
  fi
  http_code=$(curl -s -o "$out_file" -w '%{http_code}' http://localhost:8011/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "$body")
  echo "$http_code"
}

# parse_prb01_sample <run_dir> <label> <body_file> <http_code> <hypothesis: nonempty|empty>
# Appends a row to prb01.tsv, echoes "expected" or "unexpected" on stdout.
parse_prb01_sample() {
  local run_dir="$1" label="$2" body_file="$3" http_code="$4" hypothesis="$5"
  python3 - "$run_dir" "$label" "$body_file" "$http_code" "$hypothesis" <<'PY'
import json, sys
run_dir, label, body_file, http_code, hypothesis = sys.argv[1:6]
content, reasoning = "", ""
try:
    with open(body_file) as f:
        data = json.load(f)
    msg = data["choices"][0]["message"]
    content = msg.get("content") or ""
    reasoning = msg.get("reasoning") or ""
except Exception as e:
    sys.stderr.write(f"PARSE_ERROR for {label}: {e}\n")

nonempty = len(reasoning) > 0
snippet = reasoning[:120].replace("\n", " ").replace("\t", " ")
with open(f"{run_dir}/prb01.tsv", "a") as out:
    out.write(f"{label}\t{http_code}\t{len(content)}\t{len(reasoning)}\t{snippet}\t{nonempty}\n")

matched = (nonempty and hypothesis == "nonempty") or ((not nonempty) and hypothesis == "empty")
print("expected" if matched else "unexpected")
PY
}

# run_prb01_sample <label> <effort> <hypothesis>
# Fires the request, parses+records it, and (only if flagged DISCARDED-FLAKE)
# retries up to 3 total attempts, per the anti-flake rule in probe_lib.sh.
run_prb01_sample() {
  local label="$1" effort="$2" hypothesis="$3"
  local body_file="$RUN_DIR/raw-prb01-${label}.json"

  wait_idle
  local http_code
  http_code=$(fire_prb01_request "$effort" "$body_file")
  echo "  $label -> HTTP $http_code ($body_file)" >&2
  local result
  result=$(parse_prb01_sample "$RUN_DIR" "$label" "$body_file" "$http_code" "$hypothesis")
  sleep 1

  local flake_state verdict
  flake_state=$(flake_window "$RUN_DIR")
  verdict=$(record_verdict "$RUN_DIR" "$label" "$result" "$flake_state")
  echo "  verdict[$label] = $verdict (flake=$flake_state)" >&2

  local attempt=1
  while [ "$verdict" = "DISCARDED-FLAKE" ] && [ "$attempt" -lt 3 ]; do
    attempt=$((attempt + 1))
    local retry_label="${label}-retry${attempt}"
    echo "  $label was DISCARDED-FLAKE; re-running as $retry_label (attempt $attempt/3)" >&2
    body_file="$RUN_DIR/raw-prb01-${retry_label}.json"
    wait_idle
    http_code=$(fire_prb01_request "$effort" "$body_file")
    result=$(parse_prb01_sample "$RUN_DIR" "$retry_label" "$body_file" "$http_code" "$hypothesis")
    sleep 1
    flake_state=$(flake_window "$RUN_DIR")
    verdict=$(record_verdict "$RUN_DIR" "$label" "$result" "$flake_state")
    echo "  verdict[$retry_label] (recorded under label=$label) = $verdict (flake=$flake_state)" >&2
  done

  if [ "$verdict" = "DISCARDED-FLAKE" ] && [ "$attempt" -ge 3 ]; then
    record_verdict "$RUN_DIR" "$label" "indeterminate" "" >/dev/null
    echo "  verdict[$label] = INDETERMINATE (retries exhausted)" >&2
  fi
}

echo "=== PRB-01 fresh reproduction ===" >&2

RUN_DIR="$(new_run_dir prb01-02)"
echo "$RUN_DIR" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN_DIR" >&2

preflight "$RUN_DIR"

printf 'label\thttp_code\tcontent_len\treasoning_len\treasoning_snippet\treasoning_nonempty\n' > "$RUN_DIR/prb01.tsv"

# Hypothesis: medium enables thinking (reasoning field non-empty); the
# unspecified/default request does NOT (reasoning field empty) -- that
# asymmetry is what actually proves medium is doing something, not just that
# the model always thinks regardless of the parameter.
run_prb01_sample "medium-1"        medium       nonempty
run_prb01_sample "medium-2"        medium       nonempty
run_prb01_sample "unspecified-1"   unspecified  empty
run_prb01_sample "unspecified-2"   unspecified  empty

postflight "$RUN_DIR"

echo "=== PRB-01 done. See $RUN_DIR/prb01.tsv and $RUN_DIR/verdicts.tsv ===" >&2
