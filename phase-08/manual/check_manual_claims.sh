#!/bin/bash
# phase-08/manual/check_manual_claims.sh — Phase 8's standing honesty gate for
# docs/manual/.
#
# Why this gate is required-marker + link-integrity based, NOT forbidden-
# string based: a forbidden-literal grep collides with prose that
# legitimately names the thing it forbids (this project's own
# `docs/cline-bench.md` §9 has to spell out its own forbidden sentences in
# order to forbid them — a naive grep over that section would trip on the
# section that is doing the forbidding). Asserting that each required
# honesty marker IS present, and that every path the manual links to
# actually exists, is checkable without that collision.
#
# Scope, stated once and enforced everywhere below: this script reads
# ONLY files under $MANUAL_DIR (default: <repo-root>/docs/manual, or
# <repo-root>/phase-08/manual/fixtures/negative under --negative-control).
# It never reads .planning/, never reads a PLAN.md, and never scans
# docs/*.md outside manual/ — the whole point is to keep this gate from
# colliding with prose that legitimately quotes a forbidden claim
# elsewhere in the repo.
#
# Read-only, re-runnable, mutates nothing.
#
# macOS ships /bin/bash 3.2 (no `declare -A`) — this file uses only
# parallel indexed arrays. It also avoids `"${arr[@]}"`/`"${arr[*]}"` on
# arrays that might be empty under `set -u`: bash 3.2 treats that as an
# unbound-variable error even when the array was explicitly declared empty
# (`arr=()`). Every such expansion below is guarded by an
# `${#arr[@]} -gt 0` check first. `"${!arr[@]}"` (indices) is safe on an
# empty array in this bash and is used instead where it suffices.
#
# Usage:
#   check_manual_claims.sh [--file <name>]... [--out <transcript-path>]
#   check_manual_claims.sh --negative-control [--out <transcript-path>]
#
# With no --file, all five manual documents are in scope (the phase-close
# signature). With one or more --file, only those are in scope — a --file
# takes a basename only ('/' is rejected) and must be one of the five fixed
# manual filenames.
#
# Exit code contract:
#   0 = every CHECK line PASSed
#   1 = at least one CHECK line FAILed
#   2 = usage error, or an in-scope name that is not one of the five
#
# --negative-control mode points MANUAL_DIR at
# phase-08/manual/fixtures/negative/ and INVERTS the expectation: it exits 0
# only if the normal run over that fixture directory FAILs (proving the
# gate is not fail-open), and exits 1 if the fixture somehow passes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MIN_LINES="${MIN_LINES:-60}"
MANUAL_DIR="${MANUAL_DIR:-$REPO_ROOT/docs/manual}"

# The five fixed manual filenames for the whole phase (ASCII names, Korean
# content — see house_rules_for_this_phase in 08-02-PLAN.md: APFS stores
# filenames NFD while a Korean literal typed into this script is NFC, so a
# gate that globbed Korean filenames would mismatch its own literals).
ALL_FILES=(00-getting-started.md 01-cli.md 02-kanban.md 03-mobile.md 04-32k-operations.md)

# Honesty-marker registry: two parallel indexed arrays, MARKER_FILE[i] owns
# MARKER_TOKEN[i]. Every pair below must appear as visible-prose literal
# text somewhere in the file it is assigned to.
MARKER_FILE=(
  00-getting-started.md 00-getting-started.md 00-getting-started.md 00-getting-started.md
  01-cli.md 01-cli.md 01-cli.md 01-cli.md
  02-kanban.md 02-kanban.md 02-kanban.md
  03-mobile.md 03-mobile.md 03-mobile.md 03-mobile.md
  04-32k-operations.md 04-32k-operations.md
)
MARKER_TOKEN=(
  "[GAP-CLINE-VERSION]" "[GAP-REBOOT]" "[GAP-READONLY]" "[GAP-PORT3000]"
  "[GAP-PLANMODE]" "[GAP-CHECKPOINT-CLINE]" "[GAP-READONLY]" "[GAP-CLINE-VERSION]"
  "[GAP-WORKTREE]" "[GAP-CHECKPOINT-KANBAN]" "[GAP-READONLY]"
  "[GAP-IPAD]" "[GAP-TELEGRAM-INDICATOR]" "[GAP-TELEGRAM-TOKEN]" "[GAP-PORT3000]"
  "[GAP-COMPACTION-CONFIG]" "[GAP-BENCH]"
)

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------
FILE_ARGS=()
OUT_PATH=""
NEGATIVE_CONTROL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      if [ $# -lt 2 ]; then
        echo "check_manual_claims.sh: --file requires an argument" >&2
        exit 2
      fi
      case "$2" in
        */*)
          echo "check_manual_claims.sh: --file must be a basename (no '/'), got: $2" >&2
          exit 2
          ;;
      esac
      FILE_ARGS+=("$2")
      shift 2
      ;;
    --negative-control)
      NEGATIVE_CONTROL=1
      shift
      ;;
    --out)
      if [ $# -lt 2 ]; then
        echo "check_manual_claims.sh: --out requires an argument" >&2
        exit 2
      fi
      OUT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: check_manual_claims.sh [--file <name>]... [--out <transcript-path>]"
      echo "       check_manual_claims.sh --negative-control [--out <transcript-path>]"
      exit 0
      ;;
    *)
      echo "check_manual_claims.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Validate --file basenames and build the in-scope list. Guarded against the
# bash-3.2 empty-array/set-u pitfall documented at the top of this file.
if [ "${#FILE_ARGS[@]}" -gt 0 ]; then
  for f in "${FILE_ARGS[@]}"; do
    VALID=0
    for CANON in "${ALL_FILES[@]}"; do
      [ "$f" = "$CANON" ] && VALID=1
    done
    if [ "$VALID" -eq 0 ]; then
      echo "check_manual_claims.sh: not one of the five manual files: $f" >&2
      exit 2
    fi
  done
  IN_SCOPE=("${FILE_ARGS[@]}")
else
  IN_SCOPE=("${ALL_FILES[@]}")
fi

if [ "$NEGATIVE_CONTROL" -eq 1 ]; then
  MANUAL_DIR="$SCRIPT_DIR/fixtures/negative"
fi

if [ -n "$OUT_PATH" ]; then
  mkdir -p "$(dirname "$OUT_PATH")"
  : > "$OUT_PATH"
fi

vlog() {
  if [ -n "$OUT_PATH" ]; then
    echo "$1" | tee -a "$OUT_PATH"
  else
    echo "$1"
  fi
}

# ---------------------------------------------------------------------------
# Case bookkeeping.
# ---------------------------------------------------------------------------
CASE_IDS=()
CASE_RCS=()

record_check() {
  local id="$1" rc="$2" detail="$3"
  CASE_IDS+=("$id")
  CASE_RCS+=("$rc")
  if [ "$rc" -eq 0 ]; then
    vlog "CHECK $id PASS — $detail"
  else
    vlog "CHECK $id FAIL — $detail"
  fi
}

# ---------------------------------------------------------------------------
# C1-exists — file present under $MANUAL_DIR, at least $MIN_LINES lines.
# ---------------------------------------------------------------------------
check_c1_exists() {
  local f="$1" path="$MANUAL_DIR/$f" lines
  if [ ! -f "$path" ]; then
    record_check "C1-exists:$f" 1 "missing under $MANUAL_DIR"
    return 1
  fi
  lines="$(wc -l < "$path" | tr -d ' ')"
  if [ "$lines" -lt "$MIN_LINES" ]; then
    record_check "C1-exists:$f" 1 "$lines lines, MIN_LINES=$MIN_LINES"
    return 1
  fi
  record_check "C1-exists:$f" 0 "$lines lines"
  return 0
}

# ---------------------------------------------------------------------------
# C2-evidence-pointer — first 15 lines contain literal '근거 문서:' AND at
# least one docs/ path (the anti-duplication rule from 08-RESEARCH.md §B1).
# ---------------------------------------------------------------------------
check_c2_evidence() {
  local f="$1" path="$MANUAL_DIR/$f"
  if head -n 15 "$path" | grep -qF '근거 문서:' && head -n 15 "$path" | grep -qE 'docs/'; then
    record_check "C2-evidence-pointer:$f" 0 "'근거 문서:' + docs/ path present in first 15 lines"
  else
    record_check "C2-evidence-pointer:$f" 1 "missing '근거 문서:' or a docs/ path in first 15 lines"
  fi
}

# ---------------------------------------------------------------------------
# C3-markers — every honesty marker the registry assigns to this file is
# present as literal text.
# ---------------------------------------------------------------------------
check_c3_markers() {
  local f="$1" path="$MANUAL_DIR/$f"
  local missing=()
  local i tok
  for i in "${!MARKER_FILE[@]}"; do
    if [ "${MARKER_FILE[$i]}" = "$f" ]; then
      tok="${MARKER_TOKEN[$i]}"
      if ! grep -qF -- "$tok" "$path"; then
        missing+=("$tok")
      fi
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    record_check "C3-markers:$f" 0 "all required markers present"
  else
    record_check "C3-markers:$f" 1 "missing: ${missing[*]}"
  fi
}

# ---------------------------------------------------------------------------
# C4-links — every repo-relative path token in the file (prefix docs/,
# phase-0, workspace/, bench/, or .planning/) must resolve under $REPO_ROOT.
# ---------------------------------------------------------------------------
extract_links() {
  local path="$1"
  grep -oE '(docs/|phase-0|workspace/|bench/|\.planning/)[A-Za-z0-9._/-]*' "$path" \
    | sed -E 's/[.,):`]+$//' \
    | sort -u
}

check_c4_links() {
  local f="$1" path="$MANUAL_DIR/$f"
  local dangling=()
  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    if [ ! -e "$REPO_ROOT/$tok" ]; then
      dangling+=("$tok")
    fi
  done < <(extract_links "$path")
  if [ "${#dangling[@]}" -eq 0 ]; then
    record_check "C4-links:$f" 0 "no dangling paths"
  else
    record_check "C4-links:$f" 1 "dangling: ${dangling[*]}"
  fi
}

# ---------------------------------------------------------------------------
# C5-index — only when 00-getting-started.md is in scope: it must reference
# all four of the other manual filenames by name.
# ---------------------------------------------------------------------------
check_c5_index() {
  local path="$MANUAL_DIR/00-getting-started.md"
  local missing=()
  local other
  for other in 01-cli.md 02-kanban.md 03-mobile.md 04-32k-operations.md; do
    if ! grep -qF -- "$other" "$path"; then
      missing+=("$other")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    record_check "C5-index" 0 "references all four other manual files"
  else
    record_check "C5-index" 1 "missing references: ${missing[*]}"
  fi
}

# ---------------------------------------------------------------------------
# Run the gate over $IN_SCOPE / $MANUAL_DIR, then tally.
# ---------------------------------------------------------------------------
run_gate() {
  local f has_00=0
  for f in "${IN_SCOPE[@]}"; do
    check_c1_exists "$f"
  done
  for f in "${IN_SCOPE[@]}"; do
    if [ -f "$MANUAL_DIR/$f" ]; then
      check_c2_evidence "$f"
      check_c3_markers "$f"
      check_c4_links "$f"
    fi
    [ "$f" = "00-getting-started.md" ] && has_00=1
  done
  if [ "$has_00" -eq 1 ] && [ -f "$MANUAL_DIR/00-getting-started.md" ]; then
    check_c5_index
  fi
}

tally() {
  local total="${#CASE_IDS[@]}" passed=0 failed=0 i
  for i in "${!CASE_RCS[@]}"; do
    if [ "${CASE_RCS[$i]}" -eq 0 ]; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
  done
  vlog "CASES $passed/$total"
  if [ "$failed" -gt 0 ]; then
    GATE_RC=1
  else
    GATE_RC=0
  fi
}

# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------
vlog "=== check_manual_claims.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog "MANUAL_DIR=$MANUAL_DIR"
vlog "IN_SCOPE=${IN_SCOPE[*]}"
vlog "NEGATIVE_CONTROL=$NEGATIVE_CONTROL"
vlog ""

GATE_RC=0
run_gate
tally

if [ "$NEGATIVE_CONTROL" -eq 1 ]; then
  if [ "$GATE_RC" -eq 1 ]; then
    vlog "NEGATIVE_CONTROL: gate correctly rejected the broken fixture corpus (fail-closed proof)"
    vlog "MANUAL_CLAIMS_GATE: PASS"
    exit 0
  else
    vlog "NEGATIVE_CONTROL: gate PASSED a deliberately broken fixture corpus — FAIL-OPEN"
    vlog "MANUAL_CLAIMS_GATE: FAIL"
    exit 1
  fi
else
  if [ "$GATE_RC" -eq 0 ]; then
    vlog "MANUAL_CLAIMS_GATE: PASS"
  else
    vlog "MANUAL_CLAIMS_GATE: FAIL"
  fi
  exit "$GATE_RC"
fi
