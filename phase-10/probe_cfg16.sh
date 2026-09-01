#!/usr/bin/env bash
# probe_cfg16.sh — Phase 10 Plan 04, Task 1.
#
# CFG-16: does the shipped two-parameter combination
# (enable_thinking:true + reasoning_effort:medium, "et-medium") actually
# produce reasoning CONTENT through the alias, at a realistic (non-truncating)
# max_tokens? Phase 9's PRB-01/PRB-03 never checked this at max_tokens:256 --
# PRB-03's et-medium measurement used max_tokens:4, which truncates before any
# reasoning text could surface at all. That is the gap this script closes.
#
# What is genuinely still open, per GATE-VERDICT.md §3.2 and this plan's
# objective: NOT "does the combination turn thinking on" (PRB-01 already
# showed reasoning_effort:medium alone does that -- 179 nonempty chars vs an
# empty negative control) but "does litellm's ALIAS-LEVEL injection actually
# deliver the combination through to the model at all", given that litellm's
# own validation layer treats the two parameters asymmetrically:
# reasoning_effort is a hosted_vllm-whitelisted param; enable_thinking is
# unrecognized and rides extra_body (ALIAS-DESIGN.md §3).
#
# Three requests, max_tokens:256, one fixed user message, strictly sequential
# with an in_flight=0 check before each:
#   - 8011      : POST :8011 direct, body carries the literal
#                 reasoning_effort:medium + enable_thinking:true (ROADMAP
#                 criterion 1b's :8011 half)
#   - 4000-plan : POST :4000, {"model":"flashnext-plan"}, NO reasoning params
#                 in the client body -- the params must come from the alias
#                 definition or not at all (criterion 1b's :4000 half)
#   - 4000-control : POST :4000, {"model":"flashnext"}, same message/max_tokens
#                 -- the negative control. Without it an empty reasoning
#                 result on 4000-plan cannot be distinguished from "this stack
#                 never emits the field at all" (PRB-01's whole design point).
#
# Both field spellings are inspected for every arm: reasoning_content
# (litellm's own name) and reasoning (:8011/mlx_vlm.server's name) -- neither
# endpoint is trusted to use the other's name.
#
# bash 3.2 compatible (no declare -A, no ${var^^}).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib10.sh
source "$SCRIPT_DIR/probe_lib10.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root, so phase-10/results/... paths resolve

CURRENT_RUN_PTR="phase-10/results/CURRENT_CFG16_RUN"
LIVE_CFG_SHA="$(shasum -a 256 "$LIVE_CFG" | awk '{print $1}')"
MSG="1부터 20까지의 소수를 모두 더하면? 답만 한 줄로."
MAX_TOKENS=256

wait_idle10() {
  local attempt=0 idle_ok=0 last=""
  while [ "$attempt" -lt 10 ]; do
    last=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    case "$last" in
      *"in_flight=0"*) idle_ok=1; break ;;
    esac
    attempt=$((attempt + 1))
    sleep 1
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle before next probe (last: $last)" >&2
    return 1
  fi
}

# fire_cfg16_request <arm> <out_file> -> echoes HTTP code on stdout
fire_cfg16_request() {
  local arm="$1" out_file="$2" body http_code endpoint
  case "$arm" in
    8011)
      endpoint="http://localhost:8011/v1/chat/completions"
      body="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$MSG\"}],\"max_tokens\":$MAX_TOKENS,\"reasoning_effort\":\"medium\",\"enable_thinking\":true}"
      ;;
    4000-plan)
      endpoint="http://127.0.0.1:4000/v1/chat/completions"
      body="{\"model\":\"flashnext-plan\",\"messages\":[{\"role\":\"user\",\"content\":\"$MSG\"}],\"max_tokens\":$MAX_TOKENS}"
      ;;
    4000-control)
      endpoint="http://127.0.0.1:4000/v1/chat/completions"
      body="{\"model\":\"flashnext\",\"messages\":[{\"role\":\"user\",\"content\":\"$MSG\"}],\"max_tokens\":$MAX_TOKENS}"
      ;;
    *)
      echo "FATAL: unknown arm '$arm'" >&2
      return 1
      ;;
  esac
  http_code=$(curl -s -o "$out_file" -w '%{http_code}' "$endpoint" \
    -H 'Content-Type: application/json' \
    -d "$body")
  echo "$http_code"
}

# parse_cfg16_sample <run_dir> <arm> <body_file> <http_code> <hypothesis: nonempty|empty>
# Appends a row to cfg16.tsv, echoes "expected"/"unexpected" on stdout.
parse_cfg16_sample() {
  local run_dir="$1" arm="$2" body_file="$3" http_code="$4" hypothesis="$5"
  python3 - "$run_dir" "$arm" "$body_file" "$http_code" "$hypothesis" <<'PY'
import json, sys
run_dir, arm, body_file, http_code, hypothesis = sys.argv[1:6]
content = reasoning_content = reasoning = ""
prompt_tokens = completion_tokens = ""
try:
    with open(body_file) as f:
        data = json.load(f)
    msg = data["choices"][0]["message"]
    content = msg.get("content") or ""
    reasoning_content = msg.get("reasoning_content") or ""
    reasoning = msg.get("reasoning") or ""
    usage = data.get("usage") or {}
    prompt_tokens = usage.get("prompt_tokens", "")
    completion_tokens = usage.get("completion_tokens", "")
except Exception as e:
    sys.stderr.write(f"PARSE_ERROR for {arm}: {e}\n")

# "nonempty" for the purpose of the hypothesis check means EITHER spelling
# carries content -- this script never assumes which name is populated.
nonempty = (len(reasoning_content) > 0) or (len(reasoning) > 0)
with open(f"{run_dir}/cfg16.tsv", "a") as out:
    out.write(f"{arm}\t{http_code}\t{len(reasoning_content)}\t{len(reasoning)}\t{len(content)}\t{prompt_tokens}\t{completion_tokens}\t{nonempty}\n")

matched = (nonempty and hypothesis == "nonempty") or ((not nonempty) and hypothesis == "empty")
print("expected" if matched else "unexpected")
PY
}

run_cfg16_sample() {
  local arm="$1" hypothesis="$2"
  local body_file="$RUN_DIR/raw-cfg16-${arm}.json"

  wait_idle10
  local http_code
  http_code=$(fire_cfg16_request "$arm" "$body_file")
  echo "  $arm -> HTTP $http_code ($body_file)" >&2
  local result
  result=$(parse_cfg16_sample "$RUN_DIR" "$arm" "$body_file" "$http_code" "$hypothesis")
  sleep 1

  local flake_state verdict
  flake_state=$(flake_window "$RUN_DIR")
  verdict=$(record_verdict "$RUN_DIR" "cfg16-$arm" "$result" "$flake_state")
  echo "  verdict[$arm] = $verdict (flake=$flake_state, result=$result)" >&2

  local attempt=1
  while [ "$verdict" = "DISCARDED-FLAKE" ] && [ "$attempt" -lt 3 ]; do
    attempt=$((attempt + 1))
    echo "  $arm was DISCARDED-FLAKE; re-firing (attempt $attempt/3), overwriting $body_file" >&2
    wait_idle10
    http_code=$(fire_cfg16_request "$arm" "$body_file")
    result=$(parse_cfg16_sample "$RUN_DIR" "$arm" "$body_file" "$http_code" "$hypothesis")
    sleep 1
    flake_state=$(flake_window "$RUN_DIR")
    verdict=$(record_verdict "$RUN_DIR" "cfg16-$arm" "$result" "$flake_state")
    echo "  verdict[$arm] retry -> $verdict (flake=$flake_state)" >&2
  done
  if [ "$verdict" = "DISCARDED-FLAKE" ] && [ "$attempt" -ge 3 ]; then
    record_verdict "$RUN_DIR" "cfg16-$arm" "indeterminate" "" >/dev/null
    echo "  verdict[$arm] = INDETERMINATE (retries exhausted)" >&2
  fi
}

echo "=== CFG-16: reasoning-content check at :8011 and :4000, with a negative control ===" >&2

RUN_DIR="$(new_run_dir10 cfg16)"
echo "$RUN_DIR" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN_DIR" >&2

preflight10 "$RUN_DIR" || { echo "FATAL: preflight10 failed" >&2; exit 1; }

printf 'arm\thttp_code\treasoning_content_len\treasoning_len\tcontent_len\tprompt_tokens\tcompletion_tokens\tnonempty\n' > "$RUN_DIR/cfg16.tsv"

# Hypotheses:
#   8011         -> nonempty (PRB-01 already showed medium alone turns thinking
#                   on at :8011 direct; et-medium's TOKEN cost is unchanged
#                   from medium alone per PRB-03-ORACLE §2b, but content was
#                   never checked at a realistic length -- this is that check)
#   4000-plan    -> nonempty (the question this script exists to answer: does
#                   the alias deliver the combination through litellm at all)
#   4000-control -> empty (unmodified flashnext, no reasoning params anywhere
#                   -- the negative control PRB-01's own design depends on)
run_cfg16_sample "8011"          nonempty
run_cfg16_sample "4000-plan"     nonempty
run_cfg16_sample "4000-control"  empty

echo "" >&2
echo "=== cfg16.tsv ===" >&2
cat "$RUN_DIR/cfg16.tsv" >&2

# ---- Read the four possible outcomes, per the plan's <action> ----
V8011_NONEMPTY=$(awk -F'\t' '$1=="8011"{print $8}' "$RUN_DIR/cfg16.tsv" | tail -1)
V4000PLAN_NONEMPTY=$(awk -F'\t' '$1=="4000-plan"{print $8}' "$RUN_DIR/cfg16.tsv" | tail -1)
VCONTROL_NONEMPTY=$(awk -F'\t' '$1=="4000-control"{print $8}' "$RUN_DIR/cfg16.tsv" | tail -1)

{
  echo "=== CFG-16 reading ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
  echo "8011 nonempty=$V8011_NONEMPTY  4000-plan nonempty=$V4000PLAN_NONEMPTY  4000-control nonempty=$VCONTROL_NONEMPTY"
} > "$RUN_DIR/cfg16-reading.txt"

if [ "$VCONTROL_NONEMPTY" = "True" ]; then
  echo "READING: negative control FAILED (control produced nonempty reasoning) -- none of these" \
       "readings discriminate. This probe is INCONCLUSIVE, recorded plainly, not a positive." \
       | tee -a "$RUN_DIR/cfg16-reading.txt" >&2
elif [ "$V8011_NONEMPTY" = "True" ] && [ "$V4000PLAN_NONEMPTY" = "True" ]; then
  echo "READING: CFG-16 answered POSITIVELY -- 8011 direct and flashnext-plan through :4000 both" \
       "produced nonempty reasoning while the flashnext negative control did not. Nothing further" \
       "needed." | tee -a "$RUN_DIR/cfg16-reading.txt" >&2
elif [ "$V8011_NONEMPTY" = "True" ] && [ "$V4000PLAN_NONEMPTY" != "True" ]; then
  echo "READING: the model CAN produce reasoning (8011 nonempty) but the ALIAS DOES NOT DELIVER IT" \
       "(4000-plan empty). Fault localized to litellm. Diagnosing before concluding..." \
       | tee -a "$RUN_DIR/cfg16-reading.txt" >&2

  {
    echo "=== diagnostic: /v1/models listing ==="
    curl -s http://127.0.0.1:4000/v1/models
    echo ""
    echo "=== diagnostic: installed live config's flashnext-plan alias block ==="
    grep -A8 'model_name: flashnext-plan' "$LIVE_CFG" || echo "(flashnext-plan block not found in $LIVE_CFG)"
    echo "=== diagnostic: litellm.log tail (outgoing body / UnsupportedParamsError search) ==="
    grep -i 'UnsupportedParamsError\|reasoning_effort\|enable_thinking' /Users/ohama/agent-stack/litellm/litellm.log | tail -40 || echo "(no matches)"
  } > "$RUN_DIR/cfg16-diagnosis.txt" 2>&1
  echo "  diagnosis written to $RUN_DIR/cfg16-diagnosis.txt" >&2

  REMEDIATION="phase-10/CFG-16-REMEDIATION.md"
  {
    echo "# CFG-16-REMEDIATION.md — flashnext-plan does not deliver reasoning through the alias"
    echo ""
    echo "**Finding date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "**Run:** \`$RUN_DIR\`"
    echo ""
    echo "## What was measured"
    echo ""
    echo "At \`max_tokens: $MAX_TOKENS\` (not the truncating max_tokens:4 Phase 9 used for its token"
    echo "sweeps), the same combination (\`reasoning_effort: medium\` + \`enable_thinking: true\`) sent"
    echo "as a literal client body to \`:8011\` direct produced nonempty reasoning content, but the"
    echo "\`flashnext-plan\` alias at \`:4000\` -- which is supposed to inject this same combination at"
    echo "the alias-definition level, with NO client-sent reasoning params -- produced an EMPTY"
    echo "reasoning field (both \`reasoning_content\` and \`reasoning\` spellings checked)."
    echo ""
    echo "cfg16.tsv:"
    echo '```'
    cat "$RUN_DIR/cfg16.tsv"
    echo '```'
    echo ""
    echo "## Diagnosis"
    echo ""
    echo '```'
    cat "$RUN_DIR/cfg16-diagnosis.txt"
    echo '```'
    echo ""
    echo "## Proposed fix (NOT applied -- this document only names it)"
    echo ""
    echo "The exact proposed alias change and its supporting evidence go here, filled in from the"
    echo "diagnosis above (e.g. an UnsupportedParamsError naming enable_thinking or"
    echo "reasoning_effort, a mismatched provider prefix, or a missing/incorrect alias entry in the"
    echo "live file). Per plan 10-04's hard constraints, no restart and no config write happen in"
    echo "this plan -- the fix goes through a fresh human checkpoint and a re-run of plan 10-03's"
    echo "apply procedure."
  } > "$REMEDIATION"
  echo "  wrote $REMEDIATION -- STOPPING per plan (no restart, no config write from this script)" >&2
elif [ "$V8011_NONEMPTY" != "True" ]; then
  echo "READING: :8011 direct itself produced EMPTY reasoning at this prompt/length -- contradicts" \
       "PRB-01's 179-char result. Re-running 8011 once at the same max_tokens with a different" \
       "prompt before recording a confirmed negative." | tee -a "$RUN_DIR/cfg16-reading.txt" >&2
  ALT_MSG="피보나치 수열의 열 번째 항은? 답만 한 줄로."
  body_file="$RUN_DIR/raw-cfg16-8011-retry-altprompt.json"
  wait_idle10
  http_code=$(curl -s -o "$body_file" -w '%{http_code}' "http://localhost:8011/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$ALT_MSG\"}],\"max_tokens\":$MAX_TOKENS,\"reasoning_effort\":\"medium\",\"enable_thinking\":true}")
  result=$(parse_cfg16_sample "$RUN_DIR" "8011-retry-altprompt" "$body_file" "$http_code" nonempty)
  flake_state=$(flake_window "$RUN_DIR")
  verdict=$(record_verdict "$RUN_DIR" "cfg16-8011-retry-altprompt" "$result" "$flake_state")
  echo "  8011-retry-altprompt -> HTTP $http_code, verdict=$verdict" | tee -a "$RUN_DIR/cfg16-reading.txt" >&2
fi

postflight10 "$RUN_DIR" "$LIVE_CFG_SHA" 0 || { echo "FATAL: postflight10 failed (see $RUN_DIR/postflight.txt)" >&2; exit 1; }

echo "" >&2
echo "=== CFG-16 probe done. See $RUN_DIR/cfg16.tsv, cfg16-reading.txt, verdicts.tsv ===" >&2
