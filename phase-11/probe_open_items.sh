#!/usr/bin/env bash
# phase-11/probe_open_items.sh — Open items 1 & 2 (plan 11-04, Task 2).
#
# OPEN ITEM 1 — reasoning_effort:"high" through each alias prefix (budget: 4
# live requests: 1a, 1b, 1c, 1d). Both alias-prefix branches are asymmetric
# per 11-RESEARCH.md Q4:
#   - openai/-prefixed (`flashnext`): reasoning_effort is not in
#     OpenAIGPTConfig.get_supported_openai_params() -> litellm's own
#     UnsupportedParamsError, expected HTTP 400, BEFORE the model server.
#   - hosted_vllm/-prefixed (`flashnext-plan`): reasoning_effort IS
#     whitelisted by HostedVLLMChatConfig, so litellm forwards it; the model
#     server itself is documented (VALIDATED.md §4,
#     howto/thinking-and-reasoning-effort.md §1) to 500 on the literal value
#     "high" ("Supported types are xhigh (default), medium, and low") -- but
#     that 500 has never been observed end-to-end through this exact stack.
#     This script observes it, whatever it turns out to be.
# 1c additionally exercises the REAL cline --thinking high CLI surface
# (raw binary, NOT the phase-11 wrapper -- the wrapper refuses --thinking by
# design; this is deliberately testing what a user who bypasses/predates the
# wrapper would see).
# 1d is the healthy-path control: same alias as 1a, reasoning_effort omitted.
#
# OPEN ITEM 2 — the per-turn max_tokens the installed cline 3.0.60 actually
# sends (budget: 1 live request). Follows docs/cline-max-tokens-findings.md
# §6's own recheck recipe: watermark the server log, fire one trivial
# one-word-reply cline call via the `flashnext` alias (NOT flashnext-plan --
# this measures cline's own request shaping, keeping reasoning out of it),
# read the `Generation queued: ... max_tokens=<n>` line(s) back out.
#
# Outcome-neutral throughout: any HTTP status, any max_tokens value is a
# complete, satisfying answer. A request is retried ONCE, only on an
# OPERATIONAL failure (connection error / non-HTTP response / empty output),
# never because its content was not the predicted one.
#
# bash 3.2 compatible. NOTE: sourcing probe_lib11.sh turns `set -e` on in
# this shell -- every command below that is allowed to fail uses
# `cmd || var=$?` (var initialised first) or an `if`/`||` wrapper. See
# probe_lib11.sh's own header for why this matters here specifically.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/probe_lib11.sh"

cd "$(cd "$HERE/.." && pwd)"   # repo root, so phase-11/results/... paths resolve

CURRENT_RUN_PTR="phase-11/results/CURRENT_OPENITEMS_RUN"
GATEWAY="http://localhost:4000/v1/chat/completions"

RUN="$(new_run_dir11 openitems)"
echo "$RUN" > "$CURRENT_RUN_PTR"
echo "Run dir: $RUN"

preflight11 "$RUN" || { echo "FATAL: preflight11 failed" >&2; exit 1; }

printf 'case\tendpoint\tmodel\treasoning_effort\thttp_status\tbody_excerpt\tnote\n' > "$RUN/oi1.tsv"

SEQ=0

# ---- curl_case <label> <model> <reasoning_effort|""> <out_json> <out_status_file> <note> ----
curl_case() {
  local label="$1" model="$2" re_field="$3" out_json="$4" out_status="$5" note="$6"
  local body
  if [ -n "$re_field" ]; then
    body='{"model":"'"$model"'","messages":[{"role":"user","content":"2+2? Reply with one word."}],"max_tokens":32,"reasoning_effort":"'"$re_field"'"}'
  else
    body='{"model":"'"$model"'","messages":[{"role":"user","content":"2+2? Reply with one word."}],"max_tokens":32}'
  fi

  assert_budget "$RUN"
  wait_idle11 || { echo "FATAL: model not idle before $label" >&2; exit 1; }

  local status=""
  status="$(curl -s -o "$out_json" -w '%{http_code}' "$GATEWAY" -H 'Content-Type: application/json' -H 'Authorization: Bearer dummy' -d "$body")" || status="CURL_ERROR"
  local retried=0
  if [ "$status" = "CURL_ERROR" ] || [ -z "$status" ]; then
    echo "  OPERATIONAL FAILURE on $label (status='$status') -- retrying ONCE" >&2
    mv "$out_json" "${out_json}.attempt1" 2>/dev/null || true
    wait_idle11 || true
    status="$(curl -s -o "$out_json" -w '%{http_code}' "$GATEWAY" -H 'Content-Type: application/json' -H 'Authorization: Bearer dummy' -d "$body")" || status="CURL_ERROR"
    retried=1
  fi
  echo "$status" > "$out_status"

  SEQ=$((SEQ + 1))
  log_budget_row "$RUN" "$SEQ" "$label" 1

  local excerpt
  excerpt="$(head -c 300 "$out_json" 2>/dev/null | tr '\n' ' ')"
  [ -z "$excerpt" ] && excerpt="(empty body)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$GATEWAY" "$model" "${re_field:-<omitted>}" "$status" "$excerpt" "${note} retried=${retried}" >> "$RUN/oi1.tsv"
  echo "$label: http_status=$status retried=$retried body(head)=$excerpt"
}

echo "=== OPEN ITEM 1a: reasoning_effort=high through flashnext-plan (hosted_vllm/) ==="
curl_case "1a" "flashnext-plan" "high" "$RUN/oi1-plan-high.json" "$RUN/oi1-plan-high.status" \
  "hosted_vllm/ alias, client-sent high, overrides the alias's injected medium (litellm kwarg-merge order, ALIAS-DESIGN.md §3); inferred (never observed end-to-end) to pass litellm and 500 at the model server"

echo "=== OPEN ITEM 1b: reasoning_effort=high through flashnext (openai/) ==="
curl_case "1b" "flashnext" "high" "$RUN/oi1-flat-high.json" "$RUN/oi1-flat-high.status" \
  "openai/ alias; expected HTTP 400 UnsupportedParamsError per ALIAS-DESIGN.md §3 -- reasoning_effort is not in OpenAIGPTConfig.get_supported_openai_params()"

echo "=== OPEN ITEM 1d: control -- flashnext-plan with reasoning_effort OMITTED ==="
curl_case "1d" "flashnext-plan" "" "$RUN/oi1-plan-control.json" "$RUN/oi1-plan-control.status" \
  "control: identical alias/body to 1a minus reasoning_effort -- confirms the alias path itself is healthy, so a non-200 in 1a is attributable to the VALUE, not to the alias being broken"

echo "=== OPEN ITEM 1c: real cline --thinking high (RAW binary, NOT the phase-11 wrapper) ==="
assert_budget "$RUN"
wait_idle11 || { echo "FATAL: model not idle before 1c" >&2; exit 1; }
OI1C_NDJSON="$RUN/oi1c-cline-thinking-high.ndjson"
OI1C_STDERR="$RUN/oi1c-cline-thinking-high.stderr"
OI1C_RC=0
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan --thinking high \
  --compaction agentic --json -t 120 "2+2? Reply with one word." \
  > "$OI1C_NDJSON" 2> "$OI1C_STDERR" || OI1C_RC=$?
OI1C_RETRIED=0
# Operational failure detector: the binary itself was unreachable (e.g. mid
# self-update / npm package removed -- observed live during this plan's own
# execution, see OPEN-ITEMS.md), NOT a content/response failure. Retry ONCE,
# per this plan's outcome-neutral retry rule -- never retry because the
# RESPONSE content was not the predicted one.
if [ "$OI1C_RC" -ne 0 ] && grep -qiE 'command not found|No such file or directory|ENOENT' "$OI1C_STDERR" 2>/dev/null; then
  echo "  OPERATIONAL FAILURE on 1c (cline binary unreachable, rc=$OI1C_RC) -- retrying ONCE" >&2
  mv "$OI1C_NDJSON" "${OI1C_NDJSON}.attempt1" 2>/dev/null || true
  mv "$OI1C_STDERR" "${OI1C_STDERR}.attempt1" 2>/dev/null || true
  wait_idle11 || true
  OI1C_RC=0
  CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-plan --thinking high \
    --compaction agentic --json -t 120 "2+2? Reply with one word." \
    > "$OI1C_NDJSON" 2> "$OI1C_STDERR" || OI1C_RC=$?
  OI1C_RETRIED=1
fi
echo "$OI1C_RC" > "$RUN/oi1c-cline-thinking-high.exit"
SEQ=$((SEQ + 1))
log_budget_row "$RUN" "$SEQ" "1c" 1
OI1C_EXCERPT="$(head -c 300 "$OI1C_NDJSON" 2>/dev/null | tr '\n' ' ')"
[ -z "$OI1C_EXCERPT" ] && OI1C_EXCERPT="(empty stdout)"
OI1C_STDERR_EXCERPT="$(head -c 300 "$OI1C_STDERR" 2>/dev/null | tr '\n' ' ')"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "1c" "cline-cli(raw)" "flashnext-plan" "high(--thinking)" "exit=$OI1C_RC" "$OI1C_EXCERPT" "raw cline --thinking high, NOT the phase-11 wrapper (which refuses --thinking by design); retried=${OI1C_RETRIED}; stderr_excerpt=[$OI1C_STDERR_EXCERPT]" >> "$RUN/oi1.tsv"
echo "1c: exit=$OI1C_RC retried=$OI1C_RETRIED stdout(head)=$OI1C_EXCERPT stderr(head)=$OI1C_STDERR_EXCERPT"

echo ""
echo "=== oi1.tsv ==="
column -t -s $'\t' "$RUN/oi1.tsv" 2>/dev/null || cat "$RUN/oi1.tsv"

# ============================================================================
# OPEN ITEM 2 — per-turn max_tokens at 3.0.60. Budget: 1 request.
# docs/cline-max-tokens-findings.md §6's own recheck recipe, byte-watermarked.
# ============================================================================
echo ""
echo "=== OPEN ITEM 2: per-turn max_tokens re-measurement (cline 3.0.60, flashnext alias) ==="
assert_budget "$RUN"
wait_idle11 || { echo "FATAL: model not idle before oi2" >&2; exit 1; }
OI2_WATERMARK_BYTES=$(wc -c < "$FLASHNEXT_LOG" | tr -d ' ')
echo "OI2_WATERMARK_BYTES=$OI2_WATERMARK_BYTES"
OI2_NDJSON="$RUN/oi2-cline.ndjson"
OI2_STDERR="$RUN/oi2-cline.stderr"
OI2_RC=0
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext --compaction agentic \
  --json -t 600 "Reply with exactly one word: OK" \
  > "$OI2_NDJSON" 2> "$OI2_STDERR" || OI2_RC=$?
OI2_RETRIED=0
if [ "$OI2_RC" -ne 0 ] && grep -qiE 'command not found|No such file or directory|ENOENT' "$OI2_STDERR" 2>/dev/null; then
  echo "  OPERATIONAL FAILURE on oi2 (cline binary unreachable, rc=$OI2_RC) -- retrying ONCE" >&2
  mv "$OI2_NDJSON" "${OI2_NDJSON}.attempt1" 2>/dev/null || true
  mv "$OI2_STDERR" "${OI2_STDERR}.attempt1" 2>/dev/null || true
  wait_idle11 || true
  OI2_WATERMARK_BYTES=$(wc -c < "$FLASHNEXT_LOG" | tr -d ' ')
  OI2_RC=0
  CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext --compaction agentic \
    --json -t 600 "Reply with exactly one word: OK" \
    > "$OI2_NDJSON" 2> "$OI2_STDERR" || OI2_RC=$?
  OI2_RETRIED=1
fi
SEQ=$((SEQ + 1))
log_budget_row "$RUN" "$SEQ" "oi2" 1
echo "oi2: exit=$OI2_RC retried=$OI2_RETRIED"

tail -c "+$((OI2_WATERMARK_BYTES + 1))" "$FLASHNEXT_LOG" | grep 'Generation queued' > "$RUN/oi2-maxtokens.txt" || true

printf 'case\tmax_tokens\traw_line\n' > "$RUN/oi2.tsv"
if [ -s "$RUN/oi2-maxtokens.txt" ]; then
  while IFS= read -r line; do
    mt="$(printf '%s' "$line" | sed -n 's/.*max_tokens=\([0-9]*\).*/\1/p')"
    printf 'oi2\t%s\t%s\n' "$mt" "$line" >> "$RUN/oi2.tsv"
  done < "$RUN/oi2-maxtokens.txt"
else
  printf 'oi2\tNONE_FOUND\t(no Generation queued line observed since watermark -- see oi2-cline.ndjson/stderr for what actually happened)\n' >> "$RUN/oi2.tsv"
fi

echo ""
echo "=== oi2-maxtokens.txt (raw server log lines) ==="
cat "$RUN/oi2-maxtokens.txt" 2>/dev/null || echo "(none)"
echo ""
echo "=== oi2.tsv ==="
column -t -s $'\t' "$RUN/oi2.tsv" 2>/dev/null || cat "$RUN/oi2.tsv"

# ============================================================================
# postflight + budget cross-check
# ============================================================================
postflight11 "$RUN" || { echo "FATAL: postflight11 failed (see $RUN/postflight.txt)" >&2; exit 1; }

echo ""
echo "=== budget.tsv ==="
cat "$RUN/budget.tsv"

# Independent cross-check: recompute the count of new "Generation queued"
# lines since the PLAN's shared budget watermark, via a DIFFERENT arithmetic
# path than log_budget_row/count_requests_since uses (total-minus-baseline
# via `head`, instead of `tail -n +`), so an off-by-one in one path cannot
# silently agree with itself.
SHARED_BASELINE="$(cat "$BUDGET_STATE_FILE")"
TOTAL_GQ=$(grep -c 'Generation queued' "$FLASHNEXT_LOG") || true
BASELINE_GQ=$(head -n "$SHARED_BASELINE" "$FLASHNEXT_LOG" | grep -c 'Generation queued') || true
INDEP_COUNT=$((TOTAL_GQ - BASELINE_GQ))
FINAL_RUNNING_TOTAL=$(tail -1 "$RUN/budget.tsv" | awk -F'\t' '{print $4}')
echo ""
echo "cross-check (independent arithmetic path): budget.tsv final running_total=$FINAL_RUNNING_TOTAL ; independently recomputed (total_GQ=$TOTAL_GQ - baseline_GQ=$BASELINE_GQ)=$INDEP_COUNT"
if [ "$FINAL_RUNNING_TOTAL" != "$INDEP_COUNT" ]; then
  echo "MISMATCH: budget.tsv running_total does not match the independently recomputed count -- investigate before trusting budget.tsv" >&2
else
  echo "OK: both counting methods agree"
fi

echo ""
echo "probe_open_items.sh done. See $RUN/"
