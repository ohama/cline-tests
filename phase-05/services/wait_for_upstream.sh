#!/bin/bash
# phase-05/services/wait_for_upstream.sh — the production readiness gate both
# Phase 5 wrappers (run_kanban_service.sh, run_telegram_service.sh) call.
#
# Usage: wait_for_upstream.sh [timeout_s] [interval_s]
#   defaults: $UPSTREAM_WAIT_TIMEOUT / $UPSTREAM_WAIT_INTERVAL (config.env)
#
# Each poll iteration must pass all THREE stages, in this order (cheapest
# first, so the common not-yet-up case costs a refused TCP connect and
# nothing else):
#   1. TCP    — can we even connect to mlx_vlm.server's OWN port (:8000)?
#   2. HEALTH — is flashnext actually loaded? GET $FLASHNEXT_HEALTH_URL and
#      require status == "healthy" AND a non-null, non-empty loaded_model.
#      (Confirmed live: GET http://127.0.0.1:8000/health returns
#      {"status":"healthy","loaded_model":"/Users/.../Qwen3.8-Flash-Next-MLX-oQ4",...}
#      in ~10ms. This is the stage a listening-proxy check cannot fake.)
#   3. ALIAS  — is the alias the surfaces actually call being advertised?
#      GET $LITELLM_MODELS_URL and require the body to contain
#      "$LITELLM_ALIAS". Mirrors verify_no_regression.sh's Check 5 method
#      exactly, and covers the reverse failure (flashnext healthy but
#      litellm not yet serving), which the flashnext-only probe would miss.
#
# Deliberately NOT done: a full POST /v1/chat/completions round-trip (the
# only fully decisive probe) — it costs a real inference on every service
# start and can take ~64s TTFT, unacceptable in a readiness loop. Stages 1-3
# are all sub-20ms and together establish "flashnext is loaded AND reachable
# through the alias", which is the readiness condition these two surfaces
# need. This residual is repeated in docs/services.md.
#
# WHY THE READINESS TARGET IS FLASHNEXT ITSELF, NOT LITELLM'S PORT: litellm
# is a lightweight Python proxy that binds its own listener INDEPENDENTLY of
# whether flashnext has loaded — a bare TCP probe against :4000 would report
# "ready" instantly in exactly the scenario SVC-04 cares about (flashnext
# deliberately down; or at boot, while a 104 GiB model is still loading).
#
# PACING — the outer loop always sleeps at the tail, whichever stage failed.
# After ANY failed iteration, sleep interval_s (clamped to whatever remains
# of the timeout budget) before retrying. Do NOT rely on stage 1's own
# internal bounded wait as the loop's only pacing: once flashnext's TCP port
# is open, stage 1 returns near-instantly on every iteration, so a stage-2 or
# stage-3 failure would otherwise spin curl/python3 subprocesses for the
# whole 20-300s budget — real CPU and subprocess churn in exactly the
# listening-but-not-ready case this gate exists to handle correctly. This
# mirrors the house convention in phase-02/infra/restart_service.sh's
# health-poll loop, which sleeps at the tail unconditionally.
#
# Exit 0 the moment all three stages pass; exit 1 at the bounded timeout with
# ONE stderr line naming which stage was still failing and the elapsed
# seconds. Every URL/host/port comes from config.env so a caller (or a later
# verification plan) can override them to emulate failure modes.
set -uo pipefail  # NOT -e: a failed stage is data, not a script bug.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

TIMEOUT_S="${1:-$UPSTREAM_WAIT_TIMEOUT}"
INTERVAL_S="${2:-$UPSTREAM_WAIT_INTERVAL}"
PROGRESS_EVERY="${UPSTREAM_WAIT_PROGRESS_EVERY:-60}"

check_flashnext_health() {
  local body
  body="$(curl -sf -m 3 "$FLASHNEXT_HEALTH_URL" 2>/dev/null)" || return 1
  [ -n "$body" ] || return 1
  python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)
if d.get("status") != "healthy":
    sys.exit(1)
loaded_model = d.get("loaded_model")
if not loaded_model:
    sys.exit(1)
sys.exit(0)
' "$body"
}

check_litellm_alias() {
  local body
  body="$(curl -sf -m 3 "$LITELLM_MODELS_URL" 2>/dev/null)" || return 1
  [ -n "$body" ] || return 1
  printf '%s' "$body" | grep -q "\"$LITELLM_ALIAS\""
}

# WAITED is real wall-clock elapsed seconds since this loop started, read
# from bash's own $SECONDS (auto-incrementing since shell start) rather than
# hand-accumulated from the tail sleep alone. Found live in 05-03's dead-port
# case: stage 1 is itself a bounded retry (wait_for_port.sh is called with
# TIMEOUT_S=$INTERVAL_S), so when TCP is the failing stage every iteration
# already spends up to INTERVAL_S seconds INSIDE the stage-1 call before the
# outer loop's own tail sleep adds another INTERVAL_S — hand-accumulating
# WAITED by only the tail-sleep amount silently ignored that first half and
# let the real bound run to roughly 2x the configured UPSTREAM_WAIT_TIMEOUT.
# This was never exercised in 05-01's live checks because those forced stage
# 2/3 failures only, where stage 1 (TCP) passes near-instantly every
# iteration. $SECONDS-based accounting is correct regardless of which stage
# fails or how long its checks take.
LOOP_START=$SECONDS
LAST_PROGRESS=0
FAILED_STAGE=""

while :; do
  FAILED_STAGE=""

  # ---- Stage 1: TCP -----------------------------------------------------
  if ! bash "$SCRIPT_DIR/wait_for_port.sh" "$FLASHNEXT_HOST" "$FLASHNEXT_PORT" "$INTERVAL_S" 1 2>/dev/null; then
    FAILED_STAGE="1-tcp(${FLASHNEXT_HOST}:${FLASHNEXT_PORT})"
  fi

  # ---- Stage 2: flashnext health ------------------------------------------
  if [ -z "$FAILED_STAGE" ] && ! check_flashnext_health; then
    FAILED_STAGE="2-flashnext-health($FLASHNEXT_HEALTH_URL)"
  fi

  # ---- Stage 3: litellm advertises the alias ------------------------------
  if [ -z "$FAILED_STAGE" ] && ! check_litellm_alias; then
    FAILED_STAGE="3-litellm-alias($LITELLM_ALIAS)"
  fi

  if [ -z "$FAILED_STAGE" ]; then
    exit 0
  fi

  WAITED=$((SECONDS - LOOP_START))

  if [ "$WAITED" -ge "$TIMEOUT_S" ]; then
    echo "wait_for_upstream.sh: timed out after ${WAITED}s — stage $FAILED_STAGE still failing" >&2
    exit 1
  fi

  if [ $((WAITED - LAST_PROGRESS)) -ge "$PROGRESS_EVERY" ]; then
    echo "wait_for_upstream.sh: still waiting (${WAITED}s elapsed, stage $FAILED_STAGE failing)" >&2
    LAST_PROGRESS="$WAITED"
  fi

  # Tail-of-loop pacing, clamped to whatever remains of the timeout budget —
  # applies no matter which of the three stages just failed.
  REMAINING=$((TIMEOUT_S - WAITED))
  SLEEP_S="$INTERVAL_S"
  if [ "$REMAINING" -lt "$SLEEP_S" ]; then
    SLEEP_S="$REMAINING"
  fi
  if [ "$SLEEP_S" -le 0 ]; then
    SLEEP_S=1
  fi
  sleep "$SLEEP_S"
done
