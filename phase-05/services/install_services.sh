#!/bin/bash
# phase-05/services/install_services.sh — idempotent launchd plist installer.
#
# Usage: install_services.sh <label> [--dry-run]
#
# Single responsibility: this script WRITES FILES. It never talks to
# launchd (no bootstrap, no bootout, no kickstart) — bringing a label up
# is the one sanctioned helper's job, phase-02/infra/restart_service.sh,
# because that script is the only thing in this project that encodes the
# async-bootout teardown poll (docs/infra-hardening.md sec 6). This
# separation means a bad `cp` here can never leave a label mid-bootout.
#
# Steps: validate label -> mkdir -p target dirs (BEFORE the plist lands,
# since WorkingDirectory pointing at a missing dir fails the launchd job)
# -> plutil -lint the STAGED plist -> backup the live plist if it differs
# -> install (or no-op if already byte-identical) -> print the next
# command, never run it.
#
# macOS /bin/bash is 3.2 (no `declare -A`); this script only uses indexed
# constructs, so it is safe as /bin/bash rather than requiring homebrew bash.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

usage() {
  echo "Usage: $0 <label> [--dry-run]" >&2
  exit 2
}

if [ $# -lt 1 ]; then
  usage
fi

# Accept --dry-run in either position (both `install_services.sh <label>
# --dry-run` and `install_services.sh --dry-run <label>` are natural to
# type), while still requiring exactly one positional <label> argument.
DRY_RUN=0
LABEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -*)
      echo "unknown argument: $1" >&2
      usage
      ;;
    *)
      if [ -n "$LABEL" ]; then
        echo "unexpected extra argument: $1" >&2
        usage
      fi
      LABEL="$1"
      shift
      ;;
  esac
done

if [ -z "$LABEL" ]; then
  usage
fi

# ---------------------------------------------------------------------------
# Step 1: validate the label is exactly one of the two Phase 5 labels.
# Anything else exits 2 (usage error), same convention as restart_service.sh.
# ---------------------------------------------------------------------------
if [ "$LABEL" = "$KANBAN_LABEL" ]; then
  PORT="$KANBAN_PORT"
elif [ "$LABEL" = "$TELEGRAM_LABEL" ]; then
  PORT="none"
elif [ "$LABEL" = "$KANBAN_PROXY_LABEL" ]; then
  PORT="$KANBAN_PROXY_PORT"
else
  echo "unknown label: $LABEL (expected $KANBAN_LABEL, $TELEGRAM_LABEL, or $KANBAN_PROXY_LABEL)" >&2
  exit 2
fi

STAGED_PLIST="$STAGED_PLISTS_DIR/$LABEL.plist"
LIVE_PLIST="$LAUNCH_AGENTS_DIR/$LABEL.plist"

if [ ! -f "$STAGED_PLIST" ]; then
  echo "staged plist not found: $STAGED_PLIST" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would mkdir -p $SANDBOX_WORKDIR $SERVICE_LOG_DIR $BACKUP_DIR"
  echo "DRY RUN: would plutil -lint $STAGED_PLIST"
  if [ -f "$LIVE_PLIST" ]; then
    if cmp -s "$STAGED_PLIST" "$LIVE_PLIST"; then
      echo "DRY RUN: unchanged: $LABEL (staged and live are byte-identical, nothing would be written)"
    else
      echo "DRY RUN: would back up $LIVE_PLIST to $BACKUP_DIR/$LABEL.plist.<UTC timestamp>"
      echo "DRY RUN: would cp -p $STAGED_PLIST $LIVE_PLIST"
    fi
  else
    echo "DRY RUN: would cp -p $STAGED_PLIST $LIVE_PLIST (no live plist currently installed)"
  fi
  echo "DRY RUN: next command (not run): phase-02/infra/restart_service.sh $LABEL $PORT"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 2: mkdir -p target dirs BEFORE the plist lands. workspace/scratch-repo/
# is gitignored, so a fresh checkout does not have it; WorkingDirectory
# pointing at a missing directory makes launchd fail the job outright.
# ---------------------------------------------------------------------------
mkdir -p "$SANDBOX_WORKDIR" "$SERVICE_LOG_DIR" "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# Step 3: lint the STAGED plist first. Never install an unlintable plist —
# a booted-out label that then fails to bootstrap leaves the service DOWN.
# ---------------------------------------------------------------------------
LINT_OUT="$(plutil -lint "$STAGED_PLIST" 2>&1)"
if ! printf '%s\n' "$LINT_OUT" | grep -qE ': OK$'; then
  echo "plutil -lint did not report OK for staged plist: $LINT_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 4/5: idempotence — if a live plist already exists and is
# byte-identical to staged, this is a no-op. Otherwise, if a live plist
# exists and DIFFERS, back it up first (timestamped, never overwritten).
# ---------------------------------------------------------------------------
if [ -f "$LIVE_PLIST" ]; then
  if cmp -s "$STAGED_PLIST" "$LIVE_PLIST"; then
    echo "unchanged: $LABEL"
    exit 0
  fi
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$LIVE_PLIST" "$BACKUP_DIR/$LABEL.plist.$TS"
  echo "backed up existing $LIVE_PLIST -> $BACKUP_DIR/$LABEL.plist.$TS" >&2
fi

# ---------------------------------------------------------------------------
# Step 6: install. Lint the installed copy too (cheap, catches a corrupted
# cp) before declaring success.
# ---------------------------------------------------------------------------
cp -p "$STAGED_PLIST" "$LIVE_PLIST"
LINT_OUT2="$(plutil -lint "$LIVE_PLIST" 2>&1)"
if ! printf '%s\n' "$LINT_OUT2" | grep -qE ': OK$'; then
  echo "plutil -lint did not report OK for installed plist: $LINT_OUT2" >&2
  exit 1
fi
echo "installed: $LABEL"

# ---------------------------------------------------------------------------
# Step 7: do NOT bootstrap. Print the exact next command as the last line.
# ---------------------------------------------------------------------------
echo "next: phase-02/infra/restart_service.sh $LABEL $PORT"
