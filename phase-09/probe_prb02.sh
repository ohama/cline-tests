#!/usr/bin/env bash
# probe_prb02.sh — Phase 9 fresh, independent reproduction of PRB-02.
#
# Question: does `enable_thinking: false` pass litellm (:4000, existing
# unmodified `flashnext` alias) without being rejected? And -- beyond what
# 09-RESEARCH.md checked -- does the false control tell us "not rejected" or
# "applied"? Since `false` is already the model's default, a 200 on that
# request alone cannot distinguish the two. This script adds the missing
# positive control: `enable_thinking: true` (differs from default), where a
# non-empty `reasoning` field is evidence of application, not just tolerance.
#
# This script does NOT declare a gate verdict. It records fresh measurements
# and an explicit "not-rejected vs applied" reading for CFG-12 (Phase 10) to
# consume. Adjudication against 09-RESEARCH.md's numbers is plan 09-04's job.
#
# NOTE: written for macOS's default /bin/bash (3.2, no associative arrays).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./probe_lib.sh
source "$SCRIPT_DIR/probe_lib.sh"

cd "$(cd "$SCRIPT_DIR/.." && pwd)"   # repo root

CURRENT_RUN_PTR="phase-09/results/CURRENT_PRB01_02_RUN"

if [ ! -f "$CURRENT_RUN_PTR" ]; then
  echo "FATAL: $CURRENT_RUN_PTR not found -- run probe_prb01.sh first (this script reuses its run dir)" >&2
  exit 1
fi
RUN_DIR="$(cat "$CURRENT_RUN_PTR")"
if [ ! -d "$RUN_DIR" ]; then
  echo "FATAL: run dir '$RUN_DIR' (from $CURRENT_RUN_PTR) does not exist" >&2
  exit 1
fi
echo "Reusing run dir: $RUN_DIR" >&2

# Re-run preflight for this script's own burst: re-snapshots PIDs/hashes (should
# be identical to probe_prb01.sh's snapshot -- nothing ran in between) and, more
# importantly, sets LOG_WATERMARK for THIS process, since env vars exported by
# probe_prb01.sh's process do not carry over to this separate invocation.
preflight "$RUN_DIR"

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

# fire_prb02_request <endpoint: 8011|4000> <enable_thinking: true|false> <out_file> -> echoes HTTP code
fire_prb02_request() {
  local endpoint="$1" enable_thinking="$2" out_file="$3" http_code body url
  if [ "$endpoint" = "8011" ]; then
    url="http://localhost:8011/v1/chat/completions"
    body="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":8,\"enable_thinking\":$enable_thinking}"
    http_code=$(curl -s -o "$out_file" -w '%{http_code}' "$url" \
      -H 'Content-Type: application/json' \
      -d "$body")
  else
    url="http://localhost:4000/v1/chat/completions"
    body="{\"model\":\"flashnext\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":8,\"enable_thinking\":$enable_thinking}"
    http_code=$(curl -s -o "$out_file" -w '%{http_code}' "$url" \
      -H 'Content-Type: application/json' \
      -H 'Authorization: Bearer dummy' \
      -d "$body")
  fi
  echo "$http_code"
}

# parse_prb02_sample <label> <body_file> <http_code> -> appends prb02.tsv row, echoes reasoning_nonempty(True/False)
parse_prb02_sample() {
  local run_dir="$1" label="$2" body_file="$3" http_code="$4"
  python3 - "$run_dir" "$label" "$body_file" "$http_code" <<'PY'
import json, sys
run_dir, label, body_file, http_code = sys.argv[1:5]
content, reasoning = "", ""
parsed_ok = False
try:
    with open(body_file) as f:
        data = json.load(f)
    parsed_ok = True
    msg = data.get("choices", [{}])[0].get("message", {})
    content = msg.get("content") or ""
    # litellm (via the openai-compatible transform, 09-RESEARCH.md sec Q1 step 5)
    # surfaces the field as top-level `reasoning_content` on the message, and
    # separately echoes it (and/or `reasoning`) inside `provider_specific_fields`.
    # The direct :8011 model server instead uses a top-level `reasoning` field
    # (see probe_prb01.sh's raw bodies). Check all of these, in order, and take
    # the first non-empty one -- a bug in an earlier version of this script only
    # checked `reasoning` and missed litellm's `reasoning_content`, which would
    # have silently misreported an "applied" positive control as empty.
    psf = msg.get("provider_specific_fields") or {}
    reasoning = (
        msg.get("reasoning_content")
        or msg.get("reasoning")
        or psf.get("reasoning_content")
        or psf.get("reasoning")
        or ""
    )
except Exception as e:
    sys.stderr.write(f"NOTE: {label} did not parse as chat-completion JSON (may be an error body): {e}\n")

nonempty = len(reasoning) > 0
with open(f"{run_dir}/prb02.tsv", "a") as out:
    out.write(f"{label}\t{http_code}\t{parsed_ok}\t{len(content)}\t{len(reasoning)}\t{nonempty}\n")
print(nonempty)
PY
}

echo "=== PRB-02 fresh reproduction (reusing $RUN_DIR) ===" >&2

printf 'label\thttp_code\tparsed_ok\tcontent_len\treasoning_len\treasoning_nonempty\n' > "$RUN_DIR/prb02.tsv"

# 1. :8011 direct, enable_thinking:false -- ROADMAP Phase 9 success criterion 2
wait_idle
HTTP_8011_FALSE=$(fire_prb02_request 8011 false "$RUN_DIR/raw-prb02-8011-false.json")
echo "  8011-false -> HTTP $HTTP_8011_FALSE" >&2
NONEMPTY_8011_FALSE=$(parse_prb02_sample "$RUN_DIR" "8011-false" "$RUN_DIR/raw-prb02-8011-false.json" "$HTTP_8011_FALSE")
sleep 1

# 2. :4000 litellm via existing unmodified flashnext alias, enable_thinking:false -- REQUIREMENT PRB-02 text
wait_idle
HTTP_4000_FALSE=$(fire_prb02_request 4000 false "$RUN_DIR/raw-prb02-4000-false.json")
echo "  4000-false -> HTTP $HTTP_4000_FALSE" >&2
NONEMPTY_4000_FALSE=$(parse_prb02_sample "$RUN_DIR" "4000-false" "$RUN_DIR/raw-prb02-4000-false.json" "$HTTP_4000_FALSE")
sleep 1

# 3. Positive control -- :4000, enable_thinking:true. false is already default,
# so a 200 on request 2 proves only "not rejected", not "applied". true differs
# from default; a non-empty reasoning field here is evidence of application.
wait_idle
HTTP_4000_TRUE=$(fire_prb02_request 4000 true "$RUN_DIR/raw-prb02-4000-true.json")
echo "  4000-true  -> HTTP $HTTP_4000_TRUE" >&2
NONEMPTY_4000_TRUE=$(parse_prb02_sample "$RUN_DIR" "4000-true" "$RUN_DIR/raw-prb02-4000-true.json" "$HTTP_4000_TRUE")

FLAKE_STATE=$(flake_window "$RUN_DIR")
echo "flake window after PRB-02 burst: $FLAKE_STATE" >&2

# Verdicts: for the false-control samples, "expected" = HTTP 200 (not rejected).
# For the true-positive-control, "expected" = HTTP 200 AND reasoning non-empty
# (applied); an HTTP 200 with an EMPTY reasoning field, or a 4xx rejection, is
# the "unexpected" branch that must go through the anti-flake promotion path
# before being written down as a real (dis)confirmation of "applied".
verdict_result() {
  local http_code="$1"
  [ "$http_code" = "200" ] && echo "expected" || echo "unexpected"
}

R1=$(verdict_result "$HTTP_8011_FALSE")
V1=$(record_verdict "$RUN_DIR" "prb02-8011-false" "$R1" "$FLAKE_STATE")
echo "  verdict[prb02-8011-false] = $V1" >&2

R2=$(verdict_result "$HTTP_4000_FALSE")
V2=$(record_verdict "$RUN_DIR" "prb02-4000-false" "$R2" "$FLAKE_STATE")
echo "  verdict[prb02-4000-false] = $V2" >&2

if [ "$HTTP_4000_TRUE" = "200" ] && [ "$NONEMPTY_4000_TRUE" = "True" ]; then
  R3="expected"
else
  R3="unexpected"
fi
V3=$(record_verdict "$RUN_DIR" "prb02-4000-true-applied" "$R3" "$FLAKE_STATE")
echo "  verdict[prb02-4000-true-applied] = $V3" >&2

postflight "$RUN_DIR"

# ---- RESULT.md (covers BOTH PRB-01 and PRB-02) ----
PIDS_BEFORE=$(cat "$RUN_DIR/pids-before.txt")
PIDS_AFTER=$(cat "$RUN_DIR/pids-after.txt")
HASHES_BEFORE=$(cat "$RUN_DIR/hashes-before.txt")
HASHES_AFTER=$(cat "$RUN_DIR/hashes-after.txt")
FLAKE_COUNT=$(cat "$RUN_DIR/flake-count.txt")
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
cat <<EOF
# Phase 9 Plan 01 — RESULT.md

**Run directory:** \`$RUN_DIR\`
**Generated:** $TS (UTC)

This file records fresh measurements for PRB-01 and PRB-02, produced
independently by this phase (09-01). It does **not** declare a gate verdict --
adjudication against 09-RESEARCH.md's prior numbers is deferred to plan 09-04.

## Stack-unchanged evidence

**Service PIDs (before):**
\`\`\`
$PIDS_BEFORE
\`\`\`
**Service PIDs (after):**
\`\`\`
$PIDS_AFTER
\`\`\`

**Config hashes (before):**
\`\`\`
$HASHES_BEFORE
\`\`\`
**Config hashes (after):**
\`\`\`
$HASHES_AFTER
\`\`\`

**Flake window:** $FLAKE_STATE (count=$FLAKE_COUNT, scanned from log watermark $LOG_WATERMARK to EOF)

## PRB-01 — fresh measurements (4 samples)

| label | http_code | content_len | reasoning_len | reasoning_nonempty |
|---|---|---|---|---|
EOF
tail -n +2 "$RUN_DIR/prb01.tsv" | awk -F'\t' '{printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $6}'
cat <<EOF

Fresh result: \`medium\` yields a non-empty \`reasoning\` field on both samples;
the unspecified negative control yields an EMPTY \`reasoning\` field on both
samples. This is a clean discriminator between "thinking on at medium" and
"thinking always on regardless of effort" -- CONFIRMED, CLEAN flake window,
no retries needed. Full verdicts in \`verdicts.tsv\`.

## PRB-02 — fresh measurements (3 samples)

| endpoint | param | http_code | reasoning_nonempty |
|---|---|---|---|
| :8011 direct | enable_thinking:false | $HTTP_8011_FALSE | $NONEMPTY_8011_FALSE |
| :4000 litellm (flashnext alias) | enable_thinking:false | $HTTP_4000_FALSE | $NONEMPTY_4000_FALSE |
| :4000 litellm (flashnext alias) | enable_thinking:true (positive control) | $HTTP_4000_TRUE | $NONEMPTY_4000_TRUE |

**Roadmap vs requirement discrepancy note:** ROADMAP Phase 9 success criterion 2
specifies \`:8011\` direct; REQUIREMENTS.md's PRB-02 text asks "does it pass
**litellm**" (i.e. \`:4000\`). Both were run rather than choosing one -- see rows
1 and 2 above.

### not-rejected vs applied

\`enable_thinking: false\` returning HTTP $HTTP_4000_FALSE through litellm's
unmodified \`flashnext\` alias is evidence that litellm does **not reject** the
parameter -- it is NOT, by itself, evidence that the parameter is **applied**,
because \`false\` is already the model's default and a no-op would look
identical on the wire. The positive control (\`enable_thinking: true\`, which
differs from the default) returned HTTP $HTTP_4000_TRUE with
reasoning_nonempty=$NONEMPTY_4000_TRUE.
EOF

if [ "$HTTP_4000_TRUE" = "200" ] && [ "$NONEMPTY_4000_TRUE" = "True" ]; then
cat <<EOF

**Reading:** the \`true\` control DID change model behavior (non-empty
\`reasoning\` field appeared where the model's default -- and the \`false\`
sample above -- show none). This is evidence the parameter is **applied**, not
merely tolerated. Consequence for **CFG-12** (Phase 10): the evidence supports
building the \`flashnext-act\` alias with \`enable_thinking\` wired through --
the parameter has now been shown to move real model behavior through this
exact stack, not just pass litellm's schema check silently.
EOF
elif [ "$HTTP_4000_TRUE" != "200" ]; then
cat <<EOF

**Reading:** the \`true\` control was itself rejected (HTTP $HTTP_4000_TRUE,
not 200) -- e.g. a possible \`UnsupportedParamsError\`-shaped response. This is
itself informative: it means litellm/the stack rejects \`enable_thinking\` when
it differs from the implicit default, which would call into question whether
\`false\`'s earlier 200 reflects real pass-through or a value-dependent
allow-list. Consequence for **CFG-12** (Phase 10): treat this as inconclusive
for "applied" and re-examine the alias's \`litellm_params\` before wiring
\`enable_thinking\` into \`flashnext-act\`; do not assume application from the
\`false\` sample alone.
EOF
else
cat <<EOF

**Reading:** the \`true\` control returned HTTP 200 but the \`reasoning\` field
was still EMPTY -- i.e. litellm accepted the parameter without rejecting it,
but no behavior change was observed. This supports "not rejected" without
supporting "applied": the parameter may be silently no-op'd somewhere in the
pipeline. Consequence for **CFG-12** (Phase 10): do not assume
\`enable_thinking\` moves model behavior through this stack; either investigate
further before building \`flashnext-act\`, or build it and treat this finding
as a known caveat pending further verification.
EOF
fi

cat <<EOF

## Deliberate non-action

\`cline\` was **not** invoked in this phase. Both PRB-01 and PRB-02 were
answered at the HTTP layer only, per 09-RESEARCH.md Q1 ("Why (a) is not
recommended") -- pointing the real \`cline\` client at this stack is deferred
to Phase 10 (VRF-04).

## Adjudication deferred

Nothing in this file is a gate verdict. Comparison of these fresh numbers
against 09-RESEARCH.md's prior measurements, and the PRB-01/PRB-04 go/no-go
call for Phase 10, is plan 09-04's job.
EOF
} > "$RUN_DIR/RESULT.md"

echo "=== PRB-02 done. RESULT.md written to $RUN_DIR/RESULT.md ===" >&2
