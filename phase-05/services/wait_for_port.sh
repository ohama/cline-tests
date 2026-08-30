#!/bin/bash
# phase-05/services/wait_for_port.sh — generic bounded TCP-connect primitive.
#
# Usage: wait_for_port.sh <host> <port> <timeout_s> <interval_s>
#
# Loops `nc -z` until it succeeds (exit 0) or timeout_s elapses (exit 1,
# with a single explicit stderr line naming host, port and elapsed seconds).
# Never a fixed `sleep` as a substitute for polling. Prints at most one
# progress line per UPSTREAM_WAIT_PROGRESS_EVERY seconds (default 60) —
# launchd never rotates these logs, so a per-poll line is unacceptable.
#
# `nc -z -G 2 -w 2` confirmed live on this machine: exit 0 against the open
# :4000, exit 1 against a refused :1.
#
# This is a generic primitive; phase-05/services/wait_for_upstream.sh (the
# actual production readiness gate) uses it as its cheapest first stage.
set -uo pipefail  # NOT -e: a refused connection is data, not a script bug.

HOST="${1:?usage: wait_for_port.sh <host> <port> <timeout_s> <interval_s>}"
PORT="${2:?usage: wait_for_port.sh <host> <port> <timeout_s> <interval_s>}"
TIMEOUT_S="${3:?usage: wait_for_port.sh <host> <port> <timeout_s> <interval_s>}"
INTERVAL_S="${4:?usage: wait_for_port.sh <host> <port> <timeout_s> <interval_s>}"

PROGRESS_EVERY="${UPSTREAM_WAIT_PROGRESS_EVERY:-60}"

WAITED=0
LAST_PROGRESS=0
while :; do
  if /usr/bin/nc -z -G 2 -w 2 "$HOST" "$PORT" 2>/dev/null; then
    exit 0
  fi

  if [ "$WAITED" -ge "$TIMEOUT_S" ]; then
    echo "wait_for_port.sh: timed out after ${WAITED}s waiting for ${HOST}:${PORT}" >&2
    exit 1
  fi

  if [ $((WAITED - LAST_PROGRESS)) -ge "$PROGRESS_EVERY" ]; then
    echo "wait_for_port.sh: still waiting for ${HOST}:${PORT} (${WAITED}s elapsed)" >&2
    LAST_PROGRESS="$WAITED"
  fi

  # Clamp the sleep to whatever remains of the timeout budget.
  REMAINING=$((TIMEOUT_S - WAITED))
  SLEEP_S="$INTERVAL_S"
  if [ "$REMAINING" -lt "$SLEEP_S" ]; then
    SLEEP_S="$REMAINING"
  fi
  if [ "$SLEEP_S" -le 0 ]; then
    SLEEP_S=1
  fi
  sleep "$SLEEP_S"
  WAITED=$((WAITED + SLEEP_S))
done
