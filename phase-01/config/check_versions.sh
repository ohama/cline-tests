#!/usr/bin/env bash
# check_versions.sh — CFG-05/CFG-06 drift assertion + plist EnvironmentVariables scanner.
#
# Sources phase-01/config/cline-invocation.env and performs three checks:
#   A) installed binary version == pinned version (cline + kanban), cross-checked against the
#      npm package.json manifest (binary and package can disagree).
#   B) no drift across invocations — run --version, do one more real invocation, run --version
#      again, assert unchanged. This is the actual CFG-05 claim: cline background-updates itself
#      on invocation, so a single --version check at the top of a script is not sufficient proof.
#   C) every ~/Library/LaunchAgents/*.plist that invokes cline or kanban carries
#      CLINE_NO_AUTO_UPDATE=1 in its EnvironmentVariables dict. Vacuous pass if none exist yet
#      (Phase 5 creates them) — this check is armed for reuse.
#
# LAUNCHAGENTS_DIR env override lets tests point the plist scanner at a fixture directory instead
# of the real ~/Library/LaunchAgents (never write to the real one from this script).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/cline-invocation.env"

LAUNCHAGENTS_DIR="${LAUNCHAGENTS_DIR:-$HOME/Library/LaunchAgents}"

PROBLEMS=0

ok() { echo "OK: $*"; }
fail() { echo "FAIL: $*"; PROBLEMS=$((PROBLEMS + 1)); }

echo "--- Check A: version pins (CFG-05, CFG-06) ---"

CLINE_VERSION_A="$("$CLINE_BIN" --version)"
if [ "$CLINE_VERSION_A" = "$CLINE_PINNED_VERSION" ]; then
  ok "cline --version reports pinned $CLINE_PINNED_VERSION"
else
  fail "cline --version reports '$CLINE_VERSION_A', expected '$CLINE_PINNED_VERSION'"
fi

KANBAN_VERSION_A="$("$KANBAN_BIN" --version)"
if [ "$KANBAN_VERSION_A" = "$KANBAN_PINNED_VERSION" ]; then
  ok "kanban --version reports pinned $KANBAN_PINNED_VERSION"
else
  fail "kanban --version reports '$KANBAN_VERSION_A', expected '$KANBAN_PINNED_VERSION'"
fi

CLINE_PKG_VERSION="$(grep -m1 '"version"' /opt/homebrew/lib/node_modules/cline/package.json | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
if [ "$CLINE_PKG_VERSION" = "$CLINE_PINNED_VERSION" ]; then
  ok "cline npm package.json version matches pinned $CLINE_PINNED_VERSION"
else
  fail "cline npm package.json reports '$CLINE_PKG_VERSION', expected '$CLINE_PINNED_VERSION'"
fi

KANBAN_PKG_VERSION="$(grep -m1 '"version"' /opt/homebrew/lib/node_modules/kanban/package.json | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
if [ "$KANBAN_PKG_VERSION" = "$KANBAN_PINNED_VERSION" ]; then
  ok "kanban npm package.json version matches pinned $KANBAN_PINNED_VERSION"
else
  fail "kanban npm package.json reports '$KANBAN_PKG_VERSION', expected '$KANBAN_PINNED_VERSION'"
fi

echo "--- Check B: no drift across invocations (the actual CFG-05 claim) ---"

# Intervening real cline invocation. Read-only: does NOT touch providers.json (no `cline auth`).
CLINE_NO_AUTO_UPDATE=1 "$CLINE_BIN" config --json >/dev/null 2>&1 || true

CLINE_VERSION_B="$("$CLINE_BIN" --version)"
if [ "$CLINE_VERSION_B" = "$CLINE_PINNED_VERSION" ]; then
  ok "cline --version still reports $CLINE_PINNED_VERSION after an intervening 'cline config --json' invocation"
else
  fail "cline --version drifted to '$CLINE_VERSION_B' after an intervening invocation (expected '$CLINE_PINNED_VERSION')"
fi

KANBAN_VERSION_B="$("$KANBAN_BIN" --version)"
if [ "$KANBAN_VERSION_B" = "$KANBAN_PINNED_VERSION" ]; then
  ok "kanban --version still reports $KANBAN_PINNED_VERSION on a second invocation"
else
  fail "kanban --version drifted to '$KANBAN_VERSION_B' on a second invocation (expected '$KANBAN_PINNED_VERSION')"
fi

echo "--- Check C: plist EnvironmentVariables (CFG-05 for launchd surfaces) ---"

if [ ! -d "$LAUNCHAGENTS_DIR" ]; then
  ok "no LaunchAgents directory at $LAUNCHAGENTS_DIR — vacuous pass"
else
  MATCHED_ANY=0
  shopt -s nullglob
  for plist in "$LAUNCHAGENTS_DIR"/*.plist; do
    MATCHES=$(plutil -convert json -o - "$plist" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

label = data.get("Label", "")
program = data.get("Program", "") or ""
args = data.get("ProgramArguments", []) or []
haystack = " ".join([program] + [str(a) for a in args]).lower()

if "cline" in haystack or "kanban" in haystack:
    env = data.get("EnvironmentVariables", {}) or {}
    val = env.get("CLINE_NO_AUTO_UPDATE")
    status = "PASS" if str(val) == "1" else "FAIL"
    print(label + "\t" + status + "\t" + repr(val))
' ) || true

    if [ -n "$MATCHES" ]; then
      MATCHED_ANY=1
      while IFS=$'\t' read -r label status val; do
        [ -z "$label" ] && continue
        if [ "$status" = "PASS" ]; then
          ok "plist '$label' ($plist) carries CLINE_NO_AUTO_UPDATE=1"
        else
          fail "plist '$label' ($plist) missing CLINE_NO_AUTO_UPDATE=1 (found: $val)"
        fi
      done <<< "$MATCHES"
    fi
  done
  shopt -u nullglob

  if [ "$MATCHED_ANY" -eq 0 ]; then
    ok "no cline/kanban launchd plists exist yet (Phase 5 creates them) — this check is armed for reuse"
  fi
fi

echo "---"
if [ "$PROBLEMS" -eq 0 ]; then
  echo "check_versions: PASS"
  exit 0
else
  echo "check_versions: FAIL ($PROBLEMS problems)"
  exit 1
fi
