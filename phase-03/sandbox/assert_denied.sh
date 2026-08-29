#!/bin/bash
# assert_denied.sh — the false-pass-discriminating assertion helper every
# denial test in phase 3 routes through.
#
# A non-zero exit code alone is NOT evidence of a sandbox denial. This
# helper exists because a (deny default) profile crashes real binaries
# with SIGABRT and zero stderr, and a naive rc!=0 check would report that
# broken sandbox as a passing test. See 03-RESEARCH.md Pitfall 1 (crash,
# not denial) and Pitfall 5 (fail-open profile, not restrictive).
#
# macOS /bin/bash is 3.2: this script avoids declare -A and ${var^^},
# using only plain variables and a single command array.
#
# Interface:
#   assert_denied.sh --label <name> --profile <sandbox.sb> --expect deny|allow \
#                    [--target <path>] [--expect-stdout <exact string>] \
#                    [--write-target <path>] [--skip-control] \
#                    -- <command> [args...]
#
# Exit codes: 0 = PASS, 1 = FAIL, 2 = CRASHED/inconclusive.
set -uo pipefail

LABEL=""
PROFILE=""
EXPECT=""
TARGET=""
EXPECT_STDOUT=""
HAVE_EXPECT_STDOUT=0
WRITE_TARGET=""
SKIP_CONTROL=0
COMMAND=()

while [ $# -gt 0 ]; do
  case "$1" in
    --label)
      LABEL="$2"; shift 2 ;;
    --profile)
      PROFILE="$2"; shift 2 ;;
    --expect)
      EXPECT="$2"; shift 2 ;;
    --target)
      TARGET="$2"; shift 2 ;;
    --expect-stdout)
      EXPECT_STDOUT="$2"; HAVE_EXPECT_STDOUT=1; shift 2 ;;
    --write-target)
      WRITE_TARGET="$2"; shift 2 ;;
    --skip-control)
      SKIP_CONTROL=1; shift ;;
    --)
      shift
      COMMAND=("$@")
      break
      ;;
    *)
      echo "assert_denied.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$LABEL" ] || [ -z "$PROFILE" ] || [ -z "$EXPECT" ] || [ ${#COMMAND[@]} -eq 0 ]; then
  echo "assert_denied.sh: --label, --profile, --expect and -- <command> are all required" >&2
  exit 1
fi

if [ "$EXPECT" != "allow" ] && [ "$EXPECT" != "deny" ]; then
  echo "assert_denied.sh: --expect must be 'allow' or 'deny', got: $EXPECT" >&2
  exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/assert_denied.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

record_evidence() {
  if [ -n "${EVIDENCE_DIR:-}" ]; then
    mkdir -p "$EVIDENCE_DIR"
    {
      echo "=== CASE $LABEL ==="
      echo "--- command ---"
      printf '%s\n' "${COMMAND[@]}"
      echo "--- rc ---"
      echo "$SBX_RC"
      echo "--- stdout ---"
      cat "$SBX_OUT" 2>/dev/null
      echo "--- stderr ---"
      cat "$SBX_ERR" 2>/dev/null
      echo
    } >> "$EVIDENCE_DIR/$LABEL.txt"
  fi
}

# --- 1. CONTROL run (unsandboxed), unless --skip-control ---
if [ "$SKIP_CONTROL" -eq 0 ]; then
  CTRL_OUT="$WORKDIR/control.stdout"
  CTRL_ERR="$WORKDIR/control.stderr"
  "${COMMAND[@]}" >"$CTRL_OUT" 2>"$CTRL_ERR"
  CTRL_RC=$?
  if [ "$CTRL_RC" -ne 0 ]; then
    echo "CASE $LABEL FAIL control-failed rc=$CTRL_RC"
    exit 1
  fi
  if [ -n "$WRITE_TARGET" ]; then
    if [ ! -e "$WRITE_TARGET" ]; then
      echo "CASE $LABEL FAIL control-failed rc=0 write-target-not-created=$WRITE_TARGET"
      exit 1
    fi
    rm -f "$WRITE_TARGET"
  fi
fi

# --- 2. SANDBOXED run ---
SBX_OUT="$WORKDIR/sbx.stdout"
SBX_ERR="$WORKDIR/sbx.stderr"
/usr/bin/sandbox-exec -f "$PROFILE" "${COMMAND[@]}" >"$SBX_OUT" 2>"$SBX_ERR"
SBX_RC=$?

# --- 3. --expect allow ---
if [ "$EXPECT" = "allow" ]; then
  if [ "$SBX_RC" -ne 0 ]; then
    echo "CASE $LABEL FAIL not-allowed rc=$SBX_RC"
    record_evidence
    exit 1
  fi
  if [ "$HAVE_EXPECT_STDOUT" -eq 1 ]; then
    ACTUAL_STDOUT="$(cat "$SBX_OUT")"
    if [ "$ACTUAL_STDOUT" != "$EXPECT_STDOUT" ]; then
      echo "CASE $LABEL FAIL stdout-mismatch got=[$ACTUAL_STDOUT] want=[$EXPECT_STDOUT]"
      record_evidence
      exit 1
    fi
  fi
  echo "CASE $LABEL PASS allowed"
  record_evidence
  exit 0
fi

# --- 4. --expect deny ---
# Classification order matters: a crash must never be credited as a denial.
if [ "$SBX_RC" -gt 128 ]; then
  echo "CASE $LABEL FAIL crashed-signal rc=$SBX_RC"
  record_evidence
  exit 2
fi

if [ "$SBX_RC" -eq 0 ]; then
  echo "CASE $LABEL FAIL not-denied"
  record_evidence
  exit 1
fi

if [ ! -s "$SBX_ERR" ]; then
  echo "CASE $LABEL FAIL crashed-silent rc=$SBX_RC"
  record_evidence
  exit 2
fi

if ! grep -qE 'Operation not permitted|EPERM|not permitted' "$SBX_ERR"; then
  FIRST_LINE="$(head -n1 "$SBX_ERR")"
  echo "CASE $LABEL FAIL wrong-error $FIRST_LINE"
  record_evidence
  exit 1
fi

if [ -n "$TARGET" ]; then
  TARGET_BASENAME="$(basename "$TARGET")"
  if ! grep -qF "$TARGET_BASENAME" "$SBX_ERR"; then
    echo "CASE $LABEL FAIL error-names-wrong-path"
    record_evidence
    exit 1
  fi
fi

if [ -n "$WRITE_TARGET" ]; then
  if [ -e "$WRITE_TARGET" ]; then
    echo "CASE $LABEL FAIL write-succeeded"
    record_evidence
    exit 1
  fi
fi

echo "CASE $LABEL PASS denied"
record_evidence
exit 0
