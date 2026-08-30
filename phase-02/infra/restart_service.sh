#!/bin/bash
# phase-02/infra/restart_service.sh — shared bootout -> bootstrap -> poll
# restart helper for a single launchd label. Authored here; invoked by
# plans 02-02 and 02-03. Generalized in 05-02 to also cover portless
# labels (Phase 5's telegram connector service binds no port at all while
# its token slot is left empty) — this is the ONLY sanctioned launchd
# restart helper in the whole project; it is extended in place, never
# forked.
#
# Usage: restart_service.sh <label> <port|none> [--timeout SECONDS]
#
# Sequence: plutil -lint -> launchctl bootout -> wait for teardown ->
# launchctl bootstrap -> poll healthy. launchctl's "restart the
# already-loaded definition without re-reading the file" subcommand is
# NOT a substitute for bootout+bootstrap after a plist edit. This script
# never sends a termination signal directly to the process and never
# toggles the older load-state subcommands (fights KeepAlive, burns
# ThrottleInterval).
#
# Portless labels (<port> == "none"): there is no listening socket to poll,
# so "healthy" cannot mean "port is listening". `state = running` ALONE is
# explicitly not proof either — a job stuck in a KeepAlive restart loop
# reports `running` on almost every sample taken mid-loop. Instead this
# script requires the SAME pid across two samples separated by at least
# 10 seconds: a pid that survives a >=10s window is a job that has settled,
# not one that is still cycling.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

usage() {
  echo "Usage: $0 <label> <port|none> [--timeout SECONDS]" >&2
  exit 2
}

if [ $# -lt 2 ]; then
  usage
fi

LABEL="$1"
PORT="$2"
shift 2

if [ "$PORT" = "none" ]; then
  PORTLESS=1
else
  PORTLESS=0
fi

TIMEOUT=240

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      ;;
  esac
done

UID_NUM="$(id -u)"
CURRENT_STEP="startup"

print_rollback() {
  local rc="$1"
  local step="${CURRENT_STEP:-unknown step}"
  local newest
  echo "RESTART FAILED: $LABEL ($step, rc=$rc)" >&2
  echo "ROLLBACK:" >&2
  newest="$(ls -t "$BACKUP_DIR/$LABEL.plist."* 2>/dev/null | head -1 || true)"
  if [ -n "$newest" ]; then
    echo "  cp -p $newest $LAUNCH_AGENTS_DIR/$LABEL.plist" >&2
  else
    echo "  (no backup found in $BACKUP_DIR)" >&2
  fi
  echo "  plutil -lint $LAUNCH_AGENTS_DIR/$LABEL.plist          # must print OK" >&2
  echo "  launchctl bootout   gui/$UID_NUM/$LABEL   # ignore \"No such process\"" >&2
  echo "  launchctl bootstrap gui/$UID_NUM $LAUNCH_AGENTS_DIR/$LABEL.plist" >&2
}

# Every non-zero exit — lint abort, unexpected bootout failure, failed
# bootstrap, or poll timeout — routes through here. No-op on exit 0.
trap 'rc=$?; if [ "$rc" -ne 0 ]; then print_rollback "$rc"; fi' EXIT

# ---------------------------------------------------------------------------
# Step 1: plist must exist
# ---------------------------------------------------------------------------
PLIST="$LAUNCH_AGENTS_DIR/$LABEL.plist"
if [ ! -f "$PLIST" ]; then
  echo "plist not found: $PLIST" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: plutil lint — mandatory, comes first. A malformed plist that gets
# booted out and then fails to bootstrap leaves the service DOWN.
# ---------------------------------------------------------------------------
CURRENT_STEP="plutil lint"
LINT_OUT="$(plutil -lint "$PLIST" 2>&1)"
if ! printf '%s\n' "$LINT_OUT" | grep -qE ': OK$'; then
  echo "plutil -lint did not report OK: $LINT_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: bootout — tolerate "No such process" (already unloaded), abort on
# any other non-zero exit.
# ---------------------------------------------------------------------------
CURRENT_STEP="bootout"
set +e
BOOTOUT_OUT="$(launchctl bootout "gui/$UID_NUM/$LABEL" 2>&1)"
BOOTOUT_RC=$?
set -e
if [ "$BOOTOUT_RC" -ne 0 ]; then
  if ! printf '%s\n' "$BOOTOUT_OUT" | grep -qi "No such process"; then
    echo "launchctl bootout failed: $BOOTOUT_OUT" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 3b: WAIT FOR TEARDOWN before bootstrapping.
#
# `launchctl bootout` is ASYNCHRONOUS: it returns as soon as the unload is
# requested, not when the job is actually gone. Bootstrapping while the label
# is still registered / the old process is still exiting fails with the opaque
# `Bootstrap failed: 5: Input/output error`.
#
# This bit us for real: flashnext holds a 104 GiB model, so teardown takes
# seconds, and two consecutive live restart attempts failed identically at the
# bootstrap step while a control test on a throwaway label (no heavy process to
# tear down) succeeded every time. Both rollbacks then bootstrapped fine — the
# `cp` + `plutil -lint` in between happened to give teardown the time it needed.
#
# So: poll until the label is genuinely out of the domain AND (for a
# port-bound label) the port is free. Portless labels (PORT=none) have no
# socket to probe, so the teardown condition there is "label no longer
# registered" alone — the poll itself is NOT skipped or weakened, only the
# lsof probe is.
# ---------------------------------------------------------------------------
CURRENT_STEP="wait for teardown"
TEARDOWN_TIMEOUT="${TEARDOWN_TIMEOUT:-120}"
TD_WAITED=0
while [ "$TD_WAITED" -lt "$TEARDOWN_TIMEOUT" ]; do
  set +e
  launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1
  STILL_REGISTERED=$?
  if [ "$PORTLESS" -eq 1 ]; then
    TD_LISTEN=""
  else
    TD_LISTEN="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null)"
  fi
  set -e
  # STILL_REGISTERED != 0 means launchctl could no longer find the service.
  if [ "$STILL_REGISTERED" -ne 0 ] && [ -z "$TD_LISTEN" ]; then
    break
  fi
  printf 'o' >&2
  sleep 2
  TD_WAITED=$((TD_WAITED + 2))
done
echo "" >&2
if [ "$STILL_REGISTERED" -eq 0 ] || [ -n "$TD_LISTEN" ]; then
  if [ "$PORTLESS" -eq 1 ]; then
    echo "label still registered after ${TD_WAITED}s" >&2
  else
    echo "label still registered or port $PORT still bound after ${TD_WAITED}s" >&2
  fi
  exit 1
fi
# Small settle margin: the domain can report the job gone a beat before
# launchd is ready to accept a fresh bootstrap for the same label.
sleep 3
echo "teardown confirmed after ${TD_WAITED}s" >&2

# ---------------------------------------------------------------------------
# Step 4: bootstrap — reload from the (edited) file on disk.
# ---------------------------------------------------------------------------
CURRENT_STEP="bootstrap"
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

# ---------------------------------------------------------------------------
# Step 5: poll until healthy — no fixed sleep (cold load can take ~45s+).
#
# Numeric-port labels: require BOTH state=running AND the port actually
# listening — unchanged from before this generalization.
#
# Portless labels (PORT=none): there is no socket to poll, and `state =
# running` alone is NOT proof of health — a job stuck in a KeepAlive restart
# loop reports `running` on almost every sample taken mid-loop. Require the
# SAME pid across two samples separated by at least 10 seconds instead: a
# pid that survives that window is a job that has settled, not one still
# cycling. If the pid changes between samples, this is treated as a failure
# ("restarting rather than settling"), not a pass.
# ---------------------------------------------------------------------------
CURRENT_STEP="health poll timeout"
WAITED=0
PID=""

if [ "$PORTLESS" -eq 1 ]; then
  PID1=""
  while [ "$WAITED" -lt "$TIMEOUT" ]; do
    set +e
    PRINT_OUT="$(launchctl print "gui/$UID_NUM/$LABEL" 2>&1)"
    set -e
    STATE="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
    CUR_PID="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"
    if [ "$STATE" = "running" ] && [ -n "$CUR_PID" ]; then
      PID1="$CUR_PID"
      break
    fi
    printf '.' >&2
    sleep 2
    WAITED=$((WAITED + 2))
  done
  echo "" >&2

  if [ "$STATE" != "running" ] || [ -z "$PID1" ]; then
    echo "timed out after ${WAITED}s waiting for $LABEL to report running with a pid" >&2
    exit 1
  fi

  CURRENT_STEP="pid-stability sample (>=10s)"
  STABILITY_WAIT="${STABILITY_WAIT:-10}"
  echo "sampled pid=$PID1 after ${WAITED}s; waiting ${STABILITY_WAIT}s before re-sampling for stability" >&2
  sleep "$STABILITY_WAIT"
  WAITED=$((WAITED + STABILITY_WAIT))

  set +e
  PRINT_OUT2="$(launchctl print "gui/$UID_NUM/$LABEL" 2>&1)"
  set -e
  STATE2="$(printf '%s\n' "$PRINT_OUT2" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
  PID2="$(printf '%s\n' "$PRINT_OUT2" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"

  if [ "$STATE2" != "running" ] || [ -z "$PID2" ] || [ "$PID2" != "$PID1" ]; then
    echo "job is restarting rather than settling: pid=$PID1 at first sample, state=$STATE2 pid=$PID2 ${STABILITY_WAIT}s later" >&2
    exit 1
  fi
  PID="$PID2"
else
  while [ "$WAITED" -lt "$TIMEOUT" ]; do
    set +e
    PRINT_OUT="$(launchctl print "gui/$UID_NUM/$LABEL" 2>&1)"
    set -e
    STATE="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
    set +e
    LISTEN_OUT="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null)"
    set -e
    if [ "$STATE" = "running" ] && [ -n "$LISTEN_OUT" ]; then
      PID="$(printf '%s\n' "$PRINT_OUT" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"
      break
    fi
    printf '.' >&2
    sleep 2
    WAITED=$((WAITED + 2))
  done
  echo "" >&2

  if [ "$STATE" != "running" ] || [ -z "$LISTEN_OUT" ]; then
    echo "timed out after ${WAITED}s waiting for $LABEL to be running with port $PORT listening" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 6: success
# ---------------------------------------------------------------------------
CURRENT_STEP="done"
echo "RESTART OK: $LABEL pid=$PID port=$PORT waited=${WAITED}s"
exit 0
