#!/usr/bin/env bash
# verify_reach.sh — Phase 10 Plan 04, Task 2. The VRF-03 deliverable: a
# standalone, re-runnable script that measures whether parameters injected at
# the ALIAS DEFINITION actually reach the model, on server-side evidence
# (prompt_tokens read from the model server's own log) rather than on HTTP
# status. It also resolves the hosted_vllm/ vs openai/ provider-prefix
# confound the research raised and did not settle (10-RESEARCH.md #2).
#
# One fixed request body ("hi", max_tokens:4) across seven arms:
#   A  :8011  $MODEL              (unspecified, direct)
#   B  :4000  flashnext           (openai/,      unspecified, no client params)
#   C  :8011  $MODEL + reasoning_effort:medium + enable_thinking:true (et-medium, direct)
#   D  :4000  flashnext-plan      (hosted_vllm/, et-medium INJECTED BY THE ALIAS -- no client params)
#   E  :8011  $MODEL + reasoning_effort:xhigh   (direct)
#   F  :4000  flashnext-reach-xhigh (hosted_vllm/, xhigh INJECTED BY THE ALIAS -- no client params)
#   G  :4000  flashnext-act       (hosted_vllm/, enable_thinking:false INJECTED -- no client params)
#
# Holding the request body constant is what makes any prompt_tokens
# difference attributable to the injected parameters rather than to the text.
# Run twice back to back (14 requests) -- not for statistics (prompt_tokens
# is a deterministic function of tokenized text) but to catch the
# `no Stream(gpu, 1)` flake or incidental drift. Disagreement between the two
# sweeps on any arm is itself a finding: a third sweep is run and all three
# are reported, no winner picked.
#
# Every reading is attributed to its own request by a log watermark
# (`wc -l` immediately before firing, grep only the newly appended lines,
# require EXACTLY ONE "Prefill started" line) -- never by `tail -N`, which a
# concurrent Kanban/Telegram request could silently corrupt.
#
# The oracle (phase-09/PRB-03-ORACLE.md) is used as a DELTA from this run's
# own arm A, never as a portable absolute -- the absolute baseline has
# already been observed to drift by a constant offset across sessions while
# every delta stayed bit-for-bit identical.
#
# Exits 0 on a completed measurement regardless of which way the numbers
# came out; non-zero only on an operational failure (attribution ambiguity
# never resolved, an arm that never returned, or a postflight10 violation).
#
# bash 3.2 compatible (no declare -A, no ${var^^}).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib10.sh
source "$SCRIPT_DIR/probe_lib10.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root, so phase-10/results/... paths resolve

CURRENT_RUN_PTR="phase-10/results/CURRENT_REACH_RUN"
LIVE_CFG_SHA="$(shasum -a 256 "$LIVE_CFG" | awk '{print $1}')"
ARMS="A B C D E F G"
ATTEMPT_MAX=3

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

# arm_endpoint <arm> -> echoes full URL
arm_endpoint() {
  case "$1" in
    A|C|E) echo "http://localhost:8011/v1/chat/completions" ;;
    B|D|F|G) echo "http://127.0.0.1:4000/v1/chat/completions" ;;
    *) echo "FATAL: unknown arm '$1'" >&2; return 1 ;;
  esac
}

# arm_model_field <arm> -> the "model" value actually sent in the request body
arm_model_field() {
  case "$1" in
    A|C|E) echo "$MODEL" ;;
    B) echo "flashnext" ;;
    D) echo "flashnext-plan" ;;
    F) echo "flashnext-reach-xhigh" ;;
    G) echo "flashnext-act" ;;
    *) echo "FATAL: unknown arm '$1'" >&2; return 1 ;;
  esac
}

# build_reach_body <arm> -> echoes the fixed-shape JSON body for that arm.
# Only reasoning_effort/enable_thinking presence+value vary (and only for the
# :8011 direct arms C/E -- the :4000 alias arms D/F/G send NO client-side
# reasoning params at all, so any effect must come from the alias definition
# itself, not from the client).
build_reach_body() {
  local arm="$1" model
  model="$(arm_model_field "$arm")"
  case "$arm" in
    A|B|D|F|G)
      echo "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4}"
      ;;
    C)
      echo "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"reasoning_effort\":\"medium\",\"enable_thinking\":true}"
      ;;
    E)
      echo "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"reasoning_effort\":\"xhigh\"}"
      ;;
    *)
      echo "FATAL: unknown arm '$arm'" >&2
      return 1
      ;;
  esac
}

# run_reach_request <sweep_num: 1|2|3> <arm>
# Fires one request, attributes it to its own "Prefill started" log line via
# watermark (not tail -N), retries on 0-match or >=2-match (bounded at
# ATTEMPT_MAX attempts), appends a row to reach.tsv and (on success) the
# matched line to sweep-lines.txt, then closes with flake_window+record_verdict.
run_reach_request() {
  local sweep="$1" arm="$2"
  local endpoint model body body_file
  endpoint="$(arm_endpoint "$arm")"
  model="$(arm_model_field "$arm")"
  body="$(build_reach_body "$arm")"
  body_file="$RUN_DIR/raw-reach-${sweep}-${arm}.json"

  local attempt=1 http_code="" prompt_tokens="" matched_line="" match_count=0 ok=0

  while [ "$attempt" -le "$ATTEMPT_MAX" ]; do
    wait_idle10
    local mark
    mark=$(wc -l < "$FLASHNEXT_LOG" | tr -d ' ')

    http_code=$(curl -s -o "$body_file" -w '%{http_code}' "$endpoint" \
      -H 'Content-Type: application/json' \
      -d "$body")

    # Small settle so the async server-side log write for this request has
    # landed before we read "the lines appended since $mark".
    sleep 0.3

    local new_lines
    new_lines=$(sed -n "$((mark + 1)),\$p" "$FLASHNEXT_LOG")
    match_count=$(printf '%s\n' "$new_lines" | grep -c 'Prefill started' || true)

    if [ "$http_code" = "200" ] && [ "$match_count" -eq 1 ]; then
      matched_line=$(printf '%s\n' "$new_lines" | grep 'Prefill started')
      prompt_tokens=$(printf '%s\n' "$matched_line" | grep -oE 'prompt_tokens=[0-9]+' | cut -d= -f2)
      ok=1
      break
    fi

    if [ "$match_count" -eq 0 ]; then
      echo "  [sweep$sweep-$arm] attempt $attempt: http=$http_code, 0 Prefill-started lines in window -- retrying" >&2
    elif [ "$match_count" -ge 2 ]; then
      echo "  [sweep$sweep-$arm] attempt $attempt: http=$http_code, $match_count Prefill-started lines in window -- another tenant's request landed here, attribution ambiguous, discarding and retrying" >&2
    else
      echo "  [sweep$sweep-$arm] attempt $attempt: http=$http_code -- retrying" >&2
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$sweep" "$arm" "$endpoint" "$model" "$http_code" "${prompt_tokens:-}" "${matched_line:-}" >> "$RUN_DIR/reach.tsv"

  if [ "$ok" -eq 1 ]; then
    echo "$matched_line" >> "$RUN_DIR/sweep-lines.txt"
  fi

  local flake_state verdict
  flake_state=$(flake_window "$RUN_DIR")
  if [ "$ok" -eq 1 ]; then
    verdict=$(record_verdict "$RUN_DIR" "reach-sweep${sweep}-${arm}" "expected" "$flake_state")
  else
    verdict=$(record_verdict "$RUN_DIR" "reach-sweep${sweep}-${arm}" "indeterminate" "")
  fi
  echo "  [sweep$sweep-$arm] http=$http_code prompt_tokens=${prompt_tokens:-N/A} verdict=$verdict (attempts=$attempt)" >&2

  if [ "$ok" -ne 1 ]; then
    OPERATIONAL_FAILURE=1
  fi

  sleep 1
}

run_reach_sweep() {
  local sweep_num="$1" arm
  for arm in $ARMS; do
    run_reach_request "$sweep_num" "$arm"
  done
}

tok_of() {
  awk -F'\t' -v s="$1" -v a="$2" '$1==s && $2==a {v=$6} END{print v}' "$RUN_DIR/reach.tsv"
}
http_of() {
  awk -F'\t' -v s="$1" -v a="$2" '$1==s && $2==a {v=$5} END{print v}' "$RUN_DIR/reach.tsv"
}

# oracle_label/oracle_delta -- phase-09/PRB-03-ORACLE.md §2/§2b, used strictly
# as a delta reference, never as a portable absolute (§4/§5 of that document).
oracle_label() {
  case "$1" in
    A|B) echo "unspecified" ;;
    C|D) echo "et-medium" ;;
    E|F) echo "xhigh" ;;
    G) echo "unspecified (enable_thinking:false is already the model default)" ;;
  esac
}
oracle_delta() {
  case "$1" in
    A|B|G) echo "0" ;;
    C|D) echo "-2" ;;
    E|F) echo "+40" ;;
  esac
}

echo "=== VRF-01/02/03 reach proof: 7-arm watermark-attributed prompt_tokens sweep, run twice ===" >&2

RUN_DIR="$(new_run_dir10 reach)"
echo "$RUN_DIR" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN_DIR" >&2

OPERATIONAL_FAILURE=0

preflight10 "$RUN_DIR" || { echo "FATAL: preflight10 failed" >&2; exit 1; }

# No header row: reach.tsv is exactly 14 data rows (2 sweeps x 7 arms), so a
# reader (or an automated verify command counting/uniquing columns) never has
# to account for a header line. Columns, in order: sweep, arm, endpoint,
# model, http_code, prompt_tokens, matched_line.
: > "$RUN_DIR/reach.tsv"
: > "$RUN_DIR/sweep-lines.txt"

run_reach_sweep 1
run_reach_sweep 2

# ---- sweep 1 vs sweep 2 agreement, per arm ----
MISMATCH=0
{
  echo "=== sweep 1 vs sweep 2 agreement ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
} > "$RUN_DIR/sweep-agreement.txt"
for arm in $ARMS; do
  v1=$(tok_of 1 "$arm")
  v2=$(tok_of 2 "$arm")
  if [ "$v1" != "$v2" ]; then
    echo "MISMATCH arm=$arm sweep1=$v1 sweep2=$v2" | tee -a "$RUN_DIR/sweep-agreement.txt" >&2
    MISMATCH=1
  else
    echo "agree    arm=$arm sweep1=$v1 sweep2=$v2" >> "$RUN_DIR/sweep-agreement.txt"
  fi
done

if [ "$MISMATCH" -eq 1 ]; then
  echo "Sweep 1/2 disagreement detected on at least one arm -- running a third sweep (3) per plan" \
       "instructions; all three will be reported, no winner picked." >&2
  echo "sweep 1/2 disagreed on at least one arm -- running sweep 3. See reach.tsv rows sweep=3." \
       >> "$RUN_DIR/sweep-agreement.txt"
  run_reach_sweep 3
else
  echo "Sweep 1 and sweep 2 agree on all 7 arms." >&2
fi

# ---- Build reach-report.txt ----
REPORT="$RUN_DIR/reach-report.txt"
: > "$REPORT"
p() { echo "$*" | tee -a "$REPORT"; }

p "=== REACH PROOF REPORT ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
p "Run dir: $RUN_DIR"
p ""

# Canonical values used for the readings below: sweep 1 (sweep 1 vs 2 agreed,
# or -- if they disagreed -- sweep 1 is still shown but the disagreement is
# printed prominently above and must be read alongside it, not instead of it).
A_TOK=$(tok_of 1 A); B_TOK=$(tok_of 1 B); C_TOK=$(tok_of 1 C); D_TOK=$(tok_of 1 D)
E_TOK=$(tok_of 1 E); F_TOK=$(tok_of 1 F); G_TOK=$(tok_of 1 G)
A_HTTP=$(http_of 1 A); B_HTTP=$(http_of 1 B); C_HTTP=$(http_of 1 C); D_HTTP=$(http_of 1 D)
E_HTTP=$(http_of 1 E); F_HTTP=$(http_of 1 F); G_HTTP=$(http_of 1 G)

p "--- VRF-01 (ROADMAP criterion 4): flashnext (B) vs flashnext-plan (D), same user message ---"
p "B (flashnext, unspecified)  prompt_tokens=$B_TOK  http=$B_HTTP"
p "D (flashnext-plan, et-medium injected by the alias)  prompt_tokens=$D_TOK  http=$D_HTTP"
p "delta (D - B) = $((D_TOK - B_TOK))   (oracle et-medium delta: -2)"
p ""

p "--- VRF-02: the judgement basis is the server-log prompt_tokens value, not HTTP 200 ---"
p "판정 근거는 서버 로그의 prompt_tokens 값이며 HTTP 200 응답이 아니다."
p "Reason: a drop_params-style silent parameter drop would still return HTTP 200 while changing"
p "nothing server-side -- so a 200 status carries zero information about whether an injected"
p "parameter actually reached the model. The HTTP codes below are recorded for completeness,"
p "precisely so a reader can see they were available and were NOT used as the evidence:"
p "  A=$A_HTTP  B=$B_HTTP  C=$C_HTTP  D=$D_HTTP  E=$E_HTTP  F=$F_HTTP  G=$G_HTTP  (all sweep 1)"
p ""

p "--- Wide-margin reach (the strong proof) ---"
p "B (flashnext) vs F (flashnext-reach-xhigh, hosted_vllm/): prompt_tokens $B_TOK vs $F_TOK," \
  "delta=$((F_TOK - B_TOK))  (oracle: +40)"
p "D (flashnext-plan, hosted_vllm/) vs F (flashnext-reach-xhigh, hosted_vllm/): prompt_tokens" \
  "$D_TOK vs $F_TOK, delta=$((F_TOK - D_TOK))  (oracle: 53-11=+42)"
p "The D-vs-F pairing is the confound-free one: both are hosted_vllm/, both go through the same" \
  "gateway path, and only the injected reasoning_effort differs -- so this delta is attributable" \
  "to the injected parameter alone."
p ""

p "--- The hosted_vllm/ confound, resolved by measurement ---"
p "A (:8011 direct, unspecified) vs B (:4000 flashnext/openai/, unspecified): $A_TOK vs $B_TOK," \
  "delta=$((B_TOK - A_TOK))"
p "C (:8011 direct, et-medium params sent by client) vs D (:4000 flashnext-plan/hosted_vllm/," \
  "same params injected by the alias): $C_TOK vs $D_TOK, delta=$((D_TOK - C_TOK))"
p "E (:8011 direct, xhigh sent by client) vs F (:4000 flashnext-reach-xhigh/hosted_vllm/, xhigh" \
  "injected by the alias): $E_TOK vs $F_TOK, delta=$((F_TOK - E_TOK))"
AB_DELTA=$((B_TOK - A_TOK)); CD_DELTA=$((D_TOK - C_TOK)); EF_DELTA=$((F_TOK - E_TOK))
if [ "$AB_DELTA" -eq 0 ] && [ "$CD_DELTA" -eq 0 ] && [ "$EF_DELTA" -eq 0 ]; then
  p "All three same-body pairings show delta=0: the provider-prefix swap (openai/ <-> hosted_vllm/)" \
    "and the gateway hop (:8011 direct <-> :4000 alias) introduce NO measurable prompt_tokens" \
    "confound. VRF-01's B-vs-D delta is therefore cleanly attributable to the injected parameters,"\
    "not to the prefix or the extra network hop."
else
  p "NON-ZERO offset(s) detected above -- this is a real finding, not a failure of this script. It" \
    "must be quantified and every delta in this report re-read net of it; see REACH-PROOF.md §4."
fi
p ""

p "--- CFG-12 corroboration: flashnext-act (G) vs flashnext (B) ---"
p "G (flashnext-act, enable_thinking:false injected) vs B (flashnext, unmodified): $G_TOK vs" \
  "$B_TOK, delta=$((G_TOK - B_TOK))"
if [ "$((G_TOK - B_TOK))" -eq 0 ]; then
  p "delta=0 is the EXPECTED result -- enable_thinking:false is already the model's default, so" \
    "flashnext-act is behaviorally indistinguishable from flashnext by this measure. This confirms" \
    "ALIAS-DESIGN.md §5's stated redundancy rather than contradicting anything."
else
  p "delta is non-zero -- a surprise against ALIAS-DESIGN.md §5's stated expectation, worth a" \
    "paragraph in REACH-PROOF.md §5."
fi
p ""

p "--- Delta table: every arm's delta from this run's own arm A, beside the declared oracle ---"
p "(delta-to-delta comparison; absolutes are NOT portable across sessions -- PRB-03-ORACLE.md §5)"
printf '%-4s %-24s %8s %8s %-28s %10s\n' "arm" "model" "tokens" "d(vsA)" "oracle-label" "oracle-d" | tee -a "$REPORT"
for arm in $ARMS; do
  tok=$(tok_of 1 "$arm")
  d=$((tok - A_TOK))
  model="$(arm_model_field "$arm")"
  ol="$(oracle_label "$arm")"
  od="$(oracle_delta "$arm")"
  printf '%-4s %-24s %8s %8s %-28s %10s\n' "$arm" "$model" "$tok" "$d" "$ol" "$od" | tee -a "$REPORT"
done
p ""

# ---- close with postflight10 ----
postflight10 "$RUN_DIR" "$LIVE_CFG_SHA" 0
POSTFLIGHT_RC=$?

echo "" >&2
echo "=== verify_reach.sh done. See $RUN_DIR/reach.tsv, reach-report.txt, sweep-agreement.txt, verdicts.tsv ===" >&2

if [ "$OPERATIONAL_FAILURE" -ne 0 ]; then
  echo "FATAL: at least one arm never returned a clean attributed reading after $ATTEMPT_MAX attempts" >&2
  exit 1
fi
if [ "$POSTFLIGHT_RC" -ne 0 ]; then
  echo "FATAL: postflight10 reported a violation -- see $RUN_DIR/postflight.txt" >&2
  exit 1
fi
exit 0
