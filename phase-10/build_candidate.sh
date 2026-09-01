#!/usr/bin/env bash
# build_candidate.sh — deterministic candidate litellm config generator.
#
# WHY THIS EXISTS
# ----------------
# Phase 10 must never hand-edit /Users/ohama/agent-stack/litellm/config.yaml.
# litellm's launchd job has KeepAlive:true and no --config fallback: a bad
# config doesn't break one alias, it crash-loops the whole gateway (and with
# it Kanban :3484 and the Telegram connector). This script produces the exact
# candidate bytes plan 10-03 will install, by PURE LINE INSERTION over a copy
# of the live file — never by loading it through a YAML dumper, which would
# silently destroy the file's extensive 🔴-flagged operational comments even
# if the model_list data survived semantically intact.
#
# This script NEVER writes the live file. It only reads it and writes into
# phase-10/config/.
#
# bash 3.2 compatible (no declare -A, no mapfile) — this machine's default
# /bin/bash is 3.2.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE="/Users/ohama/agent-stack/litellm/config.yaml"
BLOCK="$HERE/config/aliases-candidate.yaml"
OUT="$HERE/config/config.yaml.candidate"
PROVENANCE="$HERE/config/candidate-provenance.txt"
PROOF="$HERE/config/insertion-proof.txt"

ANCHOR_PATTERN='^  # ── 호환용 옛 별칭'

if [ ! -f "$LIVE" ]; then
  echo "FATAL: live config not found at $LIVE" >&2
  exit 1
fi
if [ ! -f "$BLOCK" ]; then
  echo "FATAL: alias block not found at $BLOCK" >&2
  exit 1
fi

# ---- find the insertion anchor by regex, never by a hardcoded line number ----
ANCHOR_COUNT=$(grep -c "$ANCHOR_PATTERN" "$LIVE" || true)
if [ "$ANCHOR_COUNT" -ne 1 ]; then
  echo "FATAL: expected exactly 1 match for anchor pattern '$ANCHOR_PATTERN' in $LIVE, found $ANCHOR_COUNT." >&2
  echo "The live file's structure has changed since this plan was written (planning-time observation:" >&2
  echo "anchor at line 35 of a 50-line file, flashnext at 22, flashnext-codex at 29-33). Stopping rather" >&2
  echo "than guessing where to insert." >&2
  exit 1
fi
ANCHOR=$(grep -n "$ANCHOR_PATTERN" "$LIVE" | head -1 | cut -d: -f1)
echo "Anchor found at line $ANCHOR of $LIVE (matched exactly once)."

# ---- build the candidate: head (unchanged) + new block + blank line + tail (unchanged) ----
{
  head -n "$((ANCHOR - 1))" "$LIVE"
  cat "$BLOCK"
  echo ""
  tail -n "+${ANCHOR}" "$LIVE"
} > "$OUT"

echo "Wrote candidate: $OUT ($(wc -l < "$OUT" | tr -d ' ') lines, live was $(wc -l < "$LIVE" | tr -d ' ') lines)"

# ---- provenance record ----
LIVE_SHA=$(shasum -a 256 "$LIVE" | awk '{print $1}')
{
  echo "=== candidate-provenance $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "live file:        $LIVE"
  echo "live sha256:      $LIVE_SHA"
  echo "live line count:  $(wc -l < "$LIVE" | tr -d ' ')"
  echo "anchor pattern:   $ANCHOR_PATTERN"
  echo "anchor line:      $ANCHOR"
  echo "candidate file:   $OUT"
  echo "candidate sha256: $(shasum -a 256 "$OUT" | awk '{print $1}')"
  echo "candidate lines:  $(wc -l < "$OUT" | tr -d ' ')"
} > "$PROVENANCE"
cat "$PROVENANCE"

# ---- prove the insertion is pure: three independent checks ----
: > "$PROOF"
{
  echo "=== insertion-proof $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""
  echo "--- Proof 1: diff shows only additions, no removed/altered live lines ---"
  REMOVED_COUNT=$(diff "$LIVE" "$OUT" | grep -c '^<' || true)
  echo "diff \"$LIVE\" \"$OUT\" | grep -c '^<' = $REMOVED_COUNT (expect 0)"
  if [ "$REMOVED_COUNT" -ne 0 ]; then
    echo "FAIL: candidate removed or altered a live line"
    diff "$LIVE" "$OUT" | grep '^<'
  else
    echo "PASS"
  fi
  echo ""
  echo "--- Proof 2: head range [1, anchor-1] is byte-identical between live and candidate ---"
  if diff <(head -n "$((ANCHOR - 1))" "$LIVE") <(head -n "$((ANCHOR - 1))" "$OUT") > /dev/null 2>&1; then
    echo "diff of head -n $((ANCHOR - 1)) (both files): empty -- PASS"
  else
    echo "FAIL: head range differs"
    diff <(head -n "$((ANCHOR - 1))" "$LIVE") <(head -n "$((ANCHOR - 1))" "$OUT") || true
  fi
  echo ""
  echo "--- Proof 3: semantic deep-equal of flashnext and flashnext-codex entries (yaml.safe_load) ---"
  LIVE_PATH="$LIVE" OUT_PATH="$OUT" python3 - <<'PY'
import os
import sys
import yaml

live_path = os.environ["LIVE_PATH"]
out_path = os.environ["OUT_PATH"]

with open(live_path) as f:
    live = yaml.safe_load(f)
with open(out_path) as f:
    cand = yaml.safe_load(f)


def find_entry(doc, name):
    for entry in doc["model_list"]:
        if entry.get("model_name") == name:
            return entry
    return None


ok = True
for name in ("flashnext", "flashnext-codex"):
    live_entry = find_entry(live, name)
    cand_entry = find_entry(cand, name)
    if live_entry is None or cand_entry is None:
        print(f"FAIL: entry '{name}' missing (live={live_entry is not None}, candidate={cand_entry is not None})")
        ok = False
        continue
    if live_entry == cand_entry:
        print(f"PASS: '{name}' deep-equal between live and candidate")
    else:
        print(f"FAIL: '{name}' differs")
        print(f"  live:      {live_entry}")
        print(f"  candidate: {cand_entry}")
        ok = False

sys.exit(0 if ok else 1)
PY
  PY_EXIT=$?
  echo "(python3 exit code: $PY_EXIT)"
} >> "$PROOF" 2>&1 || true

cat "$PROOF"

echo ""
echo "Candidate build complete. See $PROVENANCE and $PROOF."
