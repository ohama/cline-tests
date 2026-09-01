#!/usr/bin/env bash
# verify_reasoning_history_source.sh -- Phase 9 Plan 03, Task 3, Part A.
#
# Independently re-verifies the shouldIncludeReasoningHistory / agentPartTo-
# ContentBlock source path that 09-RESEARCH.md traced, and the installed
# litellm reasoning_content/reasoning fallback that backs the running
# com.ohama.litellm. Read-only: git describe / grep / sed only. Nothing is
# installed, checked out, cloned, or modified.
#
# This script does NOT restate the research's line numbers -- it re-runs the
# greps against the actual files on disk right now and records whatever line
# numbers are ACTUALLY observed, which may differ from 09-RESEARCH.md's.
#
# Writes "$RUN"/source-verification.txt (full evidence) and echoes a PASS/FAIL
# line per check to stdout.
set -euo pipefail

CLINE_SRC="/Users/ohama/projs/cline-src"
AI_SDK_TS="$CLINE_SRC/sdk/packages/llms/src/providers/ai-sdk.ts"
MODEL_FACTS_TS="$CLINE_SRC/sdk/packages/llms/src/providers/model-facts.ts"
CODEC_TS="$CLINE_SRC/sdk/packages/core/src/runtime/config/agent-message-codec.ts"
MSG_BUILDER_TS="$CLINE_SRC/sdk/packages/core/src/session/services/message-builder.ts"
LITELLM_COMMON_UTILS="/Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/litellm_core_utils/prompt_templates/common_utils.py"
DOC_IMPL="docs/plan-act-reasoning-implementation.md"
DOC_DESIGN="docs/plan-act-reasoning-design.md"
DOC_DIAGRAMS="docs/plan-act-reasoning-diagrams.md"
PINNED_TAG="cli-v3.0.53"

if [ $# -lt 1 ]; then
  RUN="$(cat phase-09/results/CURRENT_PRB04_RUN 2>/dev/null || true)"
  if [ -z "$RUN" ]; then
    echo "FATAL: no run dir given and phase-09/results/CURRENT_PRB04_RUN not found" >&2
    exit 1
  fi
else
  RUN="$1"
fi
if [ ! -d "$RUN" ]; then
  echo "FATAL: run dir '$RUN' does not exist" >&2
  exit 1
fi

OUT="$RUN/source-verification.txt"
: > "$OUT"
overall_ok=1

log() { echo "$@" >> "$OUT"; }
pass() { echo "PASS: $1"; log "PASS: $1"; }
fail() { echo "FAIL: $1"; log "FAIL: $1"; overall_ok=0; }
loud() { echo "LOUD: $1"; log "LOUD: $1"; }

log "=== verify_reasoning_history_source.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
log ""

# ---- Check 1: git tag / drift ------------------------------------------------
log "--- Check 1: cline-src tag ---"
if [ ! -d "$CLINE_SRC/.git" ]; then
  fail "cline-src ($CLINE_SRC) is not a git checkout"
else
  OBSERVED_TAG="$(git -C "$CLINE_SRC" describe --tags 2>&1 || true)"
  log "git -C $CLINE_SRC describe --tags => $OBSERVED_TAG"
  if [ "$OBSERVED_TAG" = "$PINNED_TAG" ]; then
    pass "cline-src tag matches pinned $PINNED_TAG"
  else
    loud "cline-src tag drifted -- observed '$OBSERVED_TAG', pinned '$PINNED_TAG' (CFG-05 unresolved). Findings below apply to the OBSERVED tag, not the pinned one."
  fi
  PORCELAIN="$(git -C "$CLINE_SRC" status --porcelain 2>&1 || true)"
  log "git -C $CLINE_SRC status --porcelain => '${PORCELAIN}'"
  if [ -z "$PORCELAIN" ]; then
    pass "cline-src working tree clean (read-only inspection confirmed, nothing modified)"
  else
    fail "cline-src working tree is DIRTY -- something modified it: $PORCELAIN"
  fi
fi
log ""

# ---- Check 2: shouldIncludeReasoningHistory ----------------------------------
log "--- Check 2: shouldIncludeReasoningHistory (ai-sdk.ts) ---"
if [ ! -f "$AI_SDK_TS" ]; then
  fail "ai-sdk.ts not found at $AI_SDK_TS"
else
  HITS="$(grep -n 'shouldIncludeReasoningHistory' "$AI_SDK_TS" || true)"
  log "grep -n 'shouldIncludeReasoningHistory' $AI_SDK_TS =>"
  log "$HITS"
  if [ -n "$HITS" ]; then
    pass "shouldIncludeReasoningHistory found in ai-sdk.ts ($(echo "$HITS" | wc -l | tr -d ' ') hit(s))"
    DEF_LINE="$(echo "$HITS" | grep 'function shouldIncludeReasoningHistory' | head -1 | cut -d: -f1 || true)"
    if [ -n "$DEF_LINE" ]; then
      BODY_END=$((DEF_LINE + 5))
      log "--- sed -n '${DEF_LINE},${BODY_END}p' $AI_SDK_TS (function body, verbatim) ---"
      sed -n "${DEF_LINE},${BODY_END}p" "$AI_SDK_TS" | tee -a "$OUT" >/dev/null
      if sed -n "${DEF_LINE},${BODY_END}p" "$AI_SDK_TS" | grep -q 'return !isCerebrasProvider'; then
        pass "function body observed to literally contain 'return !isCerebrasProvider(...)' at/after line $DEF_LINE"
      else
        fail "function body did NOT contain the expected 'return !isCerebrasProvider(...)' line -- source has changed since research"
      fi
    else
      fail "could not locate 'function shouldIncludeReasoningHistory' definition line"
    fi
  else
    fail "shouldIncludeReasoningHistory NOT found in ai-sdk.ts -- source has changed since research"
  fi
fi
log ""

# ---- Check 3: isCerebrasProvider ---------------------------------------------
log "--- Check 3: isCerebrasProvider ---"
HITS_AISDK="$(grep -n 'isCerebrasProvider' "$AI_SDK_TS" 2>/dev/null || true)"
log "grep -n 'isCerebrasProvider' $AI_SDK_TS =>"
log "$HITS_AISDK"
HITS_FACTS=""
if [ -f "$MODEL_FACTS_TS" ]; then
  HITS_FACTS="$(grep -n 'isCerebrasProvider' "$MODEL_FACTS_TS" 2>/dev/null || true)"
  log "grep -n 'isCerebrasProvider' $MODEL_FACTS_TS =>"
  log "$HITS_FACTS"
fi
if [ -n "$HITS_AISDK" ]; then
  pass "isCerebrasProvider referenced in ai-sdk.ts (import + call site)"
else
  fail "isCerebrasProvider NOT referenced in ai-sdk.ts"
fi
if [ -n "$HITS_FACTS" ]; then
  loud "isCerebrasProvider's actual DEFINITION lives in model-facts.ts, not ai-sdk.ts (ai-sdk.ts only imports and calls it) -- 09-RESEARCH.md's citation implied it was local to ai-sdk.ts; this is a minor correction to that citation, not a change to the finding itself"
fi
log ""

# ---- Check 4: agentPartToContentBlock ----------------------------------------
log "--- Check 4: agentPartToContentBlock (agent-message-codec.ts) ---"
if [ ! -f "$CODEC_TS" ]; then
  fail "agent-message-codec.ts not found at $CODEC_TS"
else
  HITS="$(grep -n 'agentPartToContentBlock' "$CODEC_TS" || true)"
  log "grep -n 'agentPartToContentBlock' $CODEC_TS =>"
  log "$HITS"
  if [ -n "$HITS" ]; then
    pass "agentPartToContentBlock found in agent-message-codec.ts ($(echo "$HITS" | wc -l | tr -d ' ') hit(s))"
  else
    fail "agentPartToContentBlock NOT found in agent-message-codec.ts -- source has changed since research"
  fi
  CASE_LINE="$(grep -n 'case "reasoning"' "$CODEC_TS" | head -1 | cut -d: -f1 || true)"
  log "grep -n 'case \"reasoning\"' $CODEC_TS => line $CASE_LINE"
  if [ -n "$CASE_LINE" ]; then
    CASE_END=$((CASE_LINE + 16))
    log "--- sed -n '${CASE_LINE},${CASE_END}p' $CODEC_TS (case \"reasoning\" branch, verbatim) ---"
    sed -n "${CASE_LINE},${CASE_END}p" "$CODEC_TS" | tee -a "$OUT" >/dev/null
    if sed -n "${CASE_LINE},${CASE_END}p" "$CODEC_TS" | grep -q 'type: "thinking"'; then
      pass "case \"reasoning\" branch observed to convert to a 'type: \"thinking\"' content block at/after line $CASE_LINE"
    else
      fail "case \"reasoning\" branch did NOT contain 'type: \"thinking\"' -- source has changed since research"
    fi
  else
    fail "could not locate 'case \"reasoning\"' branch in agentPartToContentBlock"
  fi
fi
log ""

# ---- Check 5: message-builder.ts thinking budget count -----------------------
log "--- Check 5: thinking block budget counting (message-builder.ts) ---"
if [ ! -f "$MSG_BUILDER_TS" ]; then
  fail "message-builder.ts not found at $MSG_BUILDER_TS"
else
  HITS="$(grep -n 'thinking' "$MSG_BUILDER_TS" || true)"
  log "grep -n 'thinking' $MSG_BUILDER_TS =>"
  log "$HITS"
  BUDGET_LINE="$(echo "$HITS" | grep 'block.type === "thinking"' | head -1 | cut -d: -f1 || true)"
  if [ -n "$BUDGET_LINE" ]; then
    pass "message-builder.ts observed counting 'block.type === \"thinking\"' toward the text budget at line $BUDGET_LINE"
  else
    fail "did NOT find a 'block.type === \"thinking\"' budget-counting line in message-builder.ts -- source has changed since research"
  fi
fi
log ""

# ---- Check 6: litellm _extract_reasoning_content -----------------------------
log "--- Check 6: litellm _extract_reasoning_content (installed venv backing com.ohama.litellm) ---"
if [ ! -f "$LITELLM_COMMON_UTILS" ]; then
  fail "common_utils.py not found at $LITELLM_COMMON_UTILS"
else
  DEF_LINE="$(grep -n '_extract_reasoning_content' "$LITELLM_COMMON_UTILS" | head -1 | cut -d: -f1 || true)"
  log "grep -n '_extract_reasoning_content' -A 8 $LITELLM_COMMON_UTILS => (def at line $DEF_LINE)"
  if [ -n "$DEF_LINE" ]; then
    BODY_END=$((DEF_LINE + 8))
    sed -n "${DEF_LINE},${BODY_END}p" "$LITELLM_COMMON_UTILS" | tee -a "$OUT" >/dev/null
    BODY="$(sed -n "$((DEF_LINE)),$((DEF_LINE + 20))p" "$LITELLM_COMMON_UTILS")"
    if echo "$BODY" | grep -q '"reasoning_content" in message' && echo "$BODY" | grep -q '"reasoning" in message'; then
      pass "installed litellm's _extract_reasoning_content observed checking BOTH 'reasoning_content' and 'reasoning' keys, at/after line $DEF_LINE"
    else
      fail "installed litellm's _extract_reasoning_content did NOT check both field names -- source has changed since research"
    fi
  else
    fail "_extract_reasoning_content not found in $LITELLM_COMMON_UTILS"
  fi
fi
log ""

# ---- Check 7: doc paragraphs asserting no-accumulation -----------------------
log "--- Check 7: docs/plan-act-reasoning-{implementation,design,diagrams}.md edit targets ---"
for doc in "$DOC_IMPL" "$DOC_DESIGN" "$DOC_DIAGRAMS"; do
  if [ ! -f "$doc" ]; then
    log "$doc: not found, skipped"
    continue
  fi
  log "--- $doc ---"
  HITS="$(grep -n -E 'toGatewayRequestMessages|agentic-compaction|reasoningChars|누적' "$doc" || true)"
  log "$HITS"
done
IMPL_HITS="$(grep -n -E 'toGatewayRequestMessages|agentic-compaction|reasoningChars' "$DOC_IMPL" 2>/dev/null || true)"
if [ -n "$IMPL_HITS" ]; then
  pass "docs/plan-act-reasoning-implementation.md contains the false-negative paragraph's source citations (see source-verification.txt for exact lines)"
else
  fail "docs/plan-act-reasoning-implementation.md no longer contains the expected false-negative citations -- has it already been edited?"
fi
log ""

log "=== overall: $([ "$overall_ok" -eq 1 ] && echo PASS || echo FAIL) ==="
echo "=== overall: $([ "$overall_ok" -eq 1 ] && echo PASS || echo FAIL) ==="
echo "Full evidence: $OUT"

if [ "$overall_ok" -ne 1 ]; then
  exit 1
fi
exit 0
