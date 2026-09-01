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
# 🔴 2026-09-01, CFG-17 fold-in: this candidate is no longer a PURE insertion.
# The user explicitly ordered the six deprecated qwen-* aliases removed —
# the config's own comment set the deletion condition ("한동안 로그를 보고
# 쓰이지 않으면 지운다") and server logs confirm it: 0 qwen-* requests vs 163
# flashnext requests since the current litellm instance started. So this
# script now does insertion (3 new hosted_vllm/ aliases) AND one deletion
# (the deprecated block), and CFG-13's guarantee narrows to exactly what it
# always meant in practice: flashnext and flashnext-codex are byte-identical
# before and after, not "every live line survives." Everything else in the
# live file (including the deprecated block) is fair game only because CFG-17
# names it explicitly — this script does not go looking for other things to
# delete, and aborts loudly if what it finds doesn't match CFG-17 exactly.
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
# Renamed from insertion-proof.txt: CFG-17 means this file is no longer a
# pure-insertion proof. The rename reflects a STRONGER claim than before
# ("every removed line is accounted for"), not a weaker one.
PROOF="$HERE/config/candidate-proof.txt"

ANCHOR_PATTERN='^  # ── 호환용 옛 별칭'

# The six deprecated aliases CFG-17 deletes, in the exact order they appear
# in the live file. This list is used ONLY to verify that the block found at
# ANCHOR_PATTERN is exactly this and nothing else — it is never the deletion
# mechanism itself. The mechanism stays anchor-driven: "delete from the
# anchor to EOF," verified structurally below before a single byte is cut.
EXPECTED_QWEN_NAMES="qwen-local
qwen-35b
qwen-122b
qwen-122b-claude
qwen-35b-claude
qwen-122b-codex"

if [ ! -f "$LIVE" ]; then
  echo "FATAL: live config not found at $LIVE" >&2
  exit 1
fi
if [ ! -f "$BLOCK" ]; then
  echo "FATAL: alias block not found at $BLOCK" >&2
  exit 1
fi

# ---- find the insertion/deletion anchor by regex, never a hardcoded line number ----
ANCHOR_COUNT=$(grep -c "$ANCHOR_PATTERN" "$LIVE" || true)
if [ "$ANCHOR_COUNT" -ne 1 ]; then
  echo "FATAL: expected exactly 1 match for anchor pattern '$ANCHOR_PATTERN' in $LIVE, found $ANCHOR_COUNT." >&2
  echo "The live file's structure has changed since this plan was written (planning-time observation:" >&2
  echo "anchor at line 35 of a 50-line file, flashnext at 22, flashnext-codex at 29-33, deprecated block" >&2
  echo "at 34-50). Stopping rather than guessing where to insert or what to delete." >&2
  exit 1
fi
ANCHOR=$(grep -n "$ANCHOR_PATTERN" "$LIVE" | head -1 | cut -d: -f1)
echo "Anchor found at line $ANCHOR of $LIVE (matched exactly once)."

LIVE_TOTAL=$(wc -l < "$LIVE" | tr -d ' ')

# ============================================================
# CFG-17: verify the deprecated block is EXACTLY what we expect, BEFORE
# deleting a single byte of it. Every check below aborts loudly rather than
# silently deleting more, less, or something other than the six named
# qwen-* aliases and their comment header.
# ============================================================

SEP_LINE=$((ANCHOR - 1))
SEP_CONTENT=$(sed -n "${SEP_LINE}p" "$LIVE")
if [ -n "$SEP_CONTENT" ]; then
  echo "FATAL: expected line $SEP_LINE (immediately before the anchor) to be blank — found: '$SEP_CONTENT'." >&2
  echo "The structure this script assumes has changed; refusing to guess the deletion boundary." >&2
  exit 1
fi

DEPRECATED_BLOCK=$(tail -n "+${ANCHOR}" "$LIVE")
DEPRECATED_LINE_COUNT=$(printf '%s\n' "$DEPRECATED_BLOCK" | wc -l | tr -d ' ')
EXPECTED_BLOCK_LINES=$((4 + 6 * 2)) # 4-line comment header + 6 aliases x 2 lines each
if [ "$DEPRECATED_LINE_COUNT" -ne "$EXPECTED_BLOCK_LINES" ]; then
  echo "FATAL: the block at line $ANCHOR is $DEPRECATED_LINE_COUNT lines; expected exactly $EXPECTED_BLOCK_LINES" >&2
  echo "(4-line comment header + 6 two-line aliases). Refusing to delete a block of unexpected shape." >&2
  exit 1
fi
if [ "$((ANCHOR + DEPRECATED_LINE_COUNT - 1))" -ne "$LIVE_TOTAL" ]; then
  echo "FATAL: the deprecated block does not run to EOF (would end at line $((ANCHOR + DEPRECATED_LINE_COUNT - 1))," >&2
  echo "but the live file's last line is $LIVE_TOTAL). Something follows the block this script has never seen." >&2
  exit 1
fi

FOUND_NAMES=$(printf '%s\n' "$DEPRECATED_BLOCK" | grep '^  - model_name: ' | sed 's/^  - model_name: *//')
if [ "$FOUND_NAMES" != "$EXPECTED_QWEN_NAMES" ]; then
  echo "FATAL: the deprecated block's alias names don't match CFG-17's expected six exactly." >&2
  echo "expected:" >&2
  printf '%s\n' "$EXPECTED_QWEN_NAMES" >&2
  echo "found:" >&2
  printf '%s\n' "$FOUND_NAMES" >&2
  exit 1
fi

TOUCHED_PROTECTED=$(printf '%s\n' "$DEPRECATED_BLOCK" | grep -c 'flashnext' || true)
if [ "$TOUCHED_PROTECTED" -ne 0 ]; then
  echo "FATAL: the block staged for deletion mentions 'flashnext' $TOUCHED_PROTECTED time(s)." >&2
  echo "Refusing to delete anything that could touch flashnext or flashnext-codex (CFG-13)." >&2
  exit 1
fi

echo "Deprecated block verified: lines $ANCHOR-$LIVE_TOTAL of $LIVE are exactly CFG-17's 6 aliases"
echo "($FOUND_NAMES) plus their comment header, and mention 'flashnext' zero times. Safe to delete."

# ---- build the candidate ----
# head (unchanged, through the blank separator that used to precede the
# deprecated block and now precedes the new alias block instead) + the new
# alias block. The deprecated tail that a pure-insertion version of this
# script would append here (tail -n +$ANCHOR) is deliberately NOT appended —
# that omission, verified above to be exactly CFG-17's six aliases and
# nothing more, is the only behavior change from the original insertion-only
# script.
{
  head -n "$((ANCHOR - 1))" "$LIVE"
  cat "$BLOCK"
} > "$OUT"

echo "Wrote candidate: $OUT ($(wc -l < "$OUT" | tr -d ' ') lines, live was $LIVE_TOTAL lines, deleted $DEPRECATED_LINE_COUNT deprecated lines)"

# ---- provenance record ----
LIVE_SHA=$(shasum -a 256 "$LIVE" | awk '{print $1}')
{
  echo "=== candidate-provenance $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "live file:              $LIVE"
  echo "live sha256:            $LIVE_SHA"
  echo "live line count:        $LIVE_TOTAL"
  echo "anchor pattern:         $ANCHOR_PATTERN"
  echo "anchor line:            $ANCHOR"
  echo "cfg-17 deleted range:   lines $ANCHOR-$LIVE_TOTAL ($DEPRECATED_LINE_COUNT lines: 4-line comment header + 6 aliases)"
  echo "cfg-17 deleted aliases: $(printf '%s' "$FOUND_NAMES" | tr '\n' ',' | sed 's/,$//')"
  echo "candidate file:         $OUT"
  echo "candidate sha256:       $(shasum -a 256 "$OUT" | awk '{print $1}')"
  echo "candidate lines:        $(wc -l < "$OUT" | tr -d ' ')"
} > "$PROVENANCE"
cat "$PROVENANCE"

# ---- prove the candidate is EXACTLY insertion + the CFG-17 deletion, and nothing else: three checks ----
: > "$PROOF"
{
  echo "=== candidate-proof $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "(renamed from insertion-proof.txt: since CFG-17, this is insertion + one deletion, not a pure"
  echo " insertion. Proof 1 below asserts something STRONGER than 'nothing removed' — that every"
  echo " removed line is individually accounted for as either the deprecated comment header or one"
  echo " of the 6 named qwen-* aliases, and nothing else.)"
  echo ""
  echo "--- Proof 1: every removed line is the CFG-17 comment header or one of the 6 named qwen-* aliases, and NOTHING else ---"
  REMOVED_FILE=$(mktemp)
  diff "$LIVE" "$OUT" | sed -n 's/^< //p' > "$REMOVED_FILE"
  REMOVED_COUNT=$(wc -l < "$REMOVED_FILE" | tr -d ' ')
  echo "diff \"$LIVE\" \"$OUT\" | grep -c '^<' = $REMOVED_COUNT (expect exactly $EXPECTED_BLOCK_LINES -- NOT 0: CFG-17 is a deliberate deletion)"
  REMOVED_FILE="$REMOVED_FILE" python3 - <<'PY'
import os
import sys

path = os.environ["REMOVED_FILE"]
with open(path) as f:
    lines = f.read().split("\n")
if lines and lines[-1] == "":
    lines = lines[:-1]

expected_names = [
    "qwen-local", "qwen-35b", "qwen-122b",
    "qwen-122b-claude", "qwen-35b-claude", "qwen-122b-codex",
]

ok = True
i = 0
header_count = 0
# The first contiguous run of "  #..." lines is the deprecated comment header.
while i < len(lines) and lines[i].startswith("  #"):
    print(f"line {i + 1}: COMMENT-HEADER  | {lines[i]!r}")
    header_count += 1
    i += 1
if header_count != 4:
    print(f"FAIL: expected a 4-line comment header, found {header_count}")
    ok = False

alias_idx = 0
while i < len(lines):
    if alias_idx >= len(expected_names):
        print(f"line {i + 1}: UNEXPECTED (no more qwen aliases expected) | {lines[i]!r}")
        ok = False
        i += 1
        continue
    name_line = lines[i]
    expected_name_line = f"  - model_name: {expected_names[alias_idx]}"
    if name_line != expected_name_line:
        print(f"line {i + 1}: FAIL, expected {expected_name_line!r}, got {name_line!r}")
        ok = False
    else:
        print(f"line {i + 1}: QWEN-ALIAS-NAME ({expected_names[alias_idx]}) | {name_line!r}")
    i += 1
    if i >= len(lines):
        print(f"FAIL: alias '{expected_names[alias_idx]}' is missing its litellm_params line")
        ok = False
        break
    params_line = lines[i]
    if not params_line.strip().startswith("litellm_params: {"):
        print(f"line {i + 1}: FAIL, expected a 'litellm_params: {{ ... }}' line, got {params_line!r}")
        ok = False
    else:
        print(f"line {i + 1}: QWEN-ALIAS-PARAMS ({expected_names[alias_idx]}) | {params_line!r}")
    i += 1
    alias_idx += 1

if alias_idx != len(expected_names):
    print(f"FAIL: only {alias_idx}/{len(expected_names)} qwen aliases accounted for")
    ok = False

if any("flashnext" in l for l in lines):
    print("FAIL: a removed line mentions 'flashnext' -- the deletion touched a protected alias")
    ok = False

print(f"TOTAL removed lines classified: {len(lines)}")
sys.exit(0 if ok else 1)
PY
  PY1_EXIT=$?
  rm -f "$REMOVED_FILE"
  if [ "$PY1_EXIT" -eq 0 ] && [ "$REMOVED_COUNT" -eq "$EXPECTED_BLOCK_LINES" ]; then
    echo "PASS: every removed line is exactly the CFG-17 comment header or one of the 6 named qwen-* aliases -- nothing else was removed"
  else
    echo "FAIL: removed-lines proof did not hold (see per-line classification above, python3 exit $PY1_EXIT)"
  fi
  echo ""
  echo "--- Proof 2: head range [1, anchor-1] is byte-identical between live and candidate ---"
  echo "(everything before the deleted block -- flashnext, flashnext-codex, and their comments -- is untouched by construction)"
  if diff <(head -n "$((ANCHOR - 1))" "$LIVE") <(head -n "$((ANCHOR - 1))" "$OUT") > /dev/null 2>&1; then
    echo "diff of head -n $((ANCHOR - 1)) (both files): empty -- PASS"
  else
    echo "FAIL: head range differs"
    diff <(head -n "$((ANCHOR - 1))" "$LIVE") <(head -n "$((ANCHOR - 1))" "$OUT") || true
  fi
  echo ""
  echo "--- Proof 3: semantic deep-equal of flashnext and flashnext-codex entries (yaml.safe_load) -- CFG-13 ---"
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

# CFG-17 corollary: none of the 6 deprecated aliases should survive in the
# candidate at all.
cand_names = [e.get("model_name") for e in cand.get("model_list", [])]
for gone in ("qwen-local", "qwen-35b", "qwen-122b", "qwen-122b-claude", "qwen-35b-claude", "qwen-122b-codex"):
    if gone in cand_names:
        print(f"FAIL: deprecated alias '{gone}' is still present in the candidate")
        ok = False
    else:
        print(f"PASS: deprecated alias '{gone}' absent from the candidate")

sys.exit(0 if ok else 1)
PY
  PY3_EXIT=$?
  echo "(python3 exit code: $PY3_EXIT)"
} >> "$PROOF" 2>&1 || true

cat "$PROOF"

echo ""
echo "Candidate build complete. See $PROVENANCE and $PROOF."
