#!/usr/bin/env bash
# apply_candidate.sh — install phase-10/config/config.yaml.candidate over the
# live litellm config and restart, with the rollback branch wired into the
# same script so it cannot be skipped by an operator improvising mid-outage.
#
# This is a single scripted sequence. Every gate below aborts BEFORE the live
# file is touched if it fails; every step from Step 3 onward that fails
# routes into the rollback branch, which restores the pristine backup,
# restarts again, and verifies health on the restored config -- never a
# creative in-place repair.
#
# Preconditions this script assumes (both already true when this plan runs):
#   - Restart A has already run against the UNMODIFIED config in the SAME
#     run dir this script reads from phase-10/results/CURRENT_MAINTENANCE_RUN.
#   - The human checkpoint in phase-10/CHANGE-BRIEF.md Section 9 has approved
#     THIS EXACT candidate sha256 (verified again below, not assumed).
#
# bash 3.2 compatible (no declare -A).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/.." || exit 2   # repo root, so relative paths in this file match the plan's

LIVE_CFG="/Users/ohama/agent-stack/litellm/config.yaml"
CANDIDATE="phase-10/config/config.yaml.candidate"
BASELINE="phase-10/BASELINE.txt"
BACKUP="phase-10/backups/config.yaml.20260901T053509Z"
FLASHNEXT_LOG="$HOME/llm-system/services/logs/flashnext.err"
ERR_LOG="/Users/ohama/agent-stack/litellm/litellm.err.log"

# shellcheck source=/dev/null
source phase-10/probe_lib10.sh

if [ ! -f "$HERE/results/CURRENT_MAINTENANCE_RUN" ]; then
  echo "FATAL: phase-10/results/CURRENT_MAINTENANCE_RUN not found -- run Task 1 (Restart A) first" >&2
  exit 2
fi
RUN=$(cat "$HERE/results/CURRENT_MAINTENANCE_RUN")
if [ ! -d "$RUN" ]; then
  echo "FATAL: run dir $RUN does not exist" >&2
  exit 2
fi

APPLY_LOG="$RUN/apply.log"
: > "$APPLY_LOG"
log() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$APPLY_LOG"
}

baseline_field() {
  # baseline_field <regex-anchor-line>
  # Extracts the non-blank line immediately following a line matching the
  # given ERE anchor in BASELINE.txt -- same technique rollback_config.sh
  # already uses for its own recorded backup hash.
  local anchor="$1"
  awk -v anchor="$anchor" '
    $0 ~ anchor { want=1; next }
    want==1 {
      gsub(/^[ \t]+|[ \t]+$/, "", $0)
      if (length($0) > 0) { print $0; found=1; exit }
    }
    END { if (!found) exit 1 }
  ' "$BASELINE"
}

BASELINE_LIVE_SHA=$(baseline_field '^1\. live config')
CANDIDATE_SHA_RECORDED=$(baseline_field '^4\. candidate')
BACKUP_SHA_RECORDED=$(baseline_field '^5\. backup just taken')

log "=== apply_candidate.sh starting, run dir $RUN ==="
log "BASELINE_LIVE_SHA=$BASELINE_LIVE_SHA"
log "CANDIDATE_SHA_RECORDED=$CANDIDATE_SHA_RECORDED"
log "BACKUP_SHA_RECORDED=$BACKUP_SHA_RECORDED"

abort_before_install() {
  log "ABORT (pre-install): $*"
  echo "ABORT: $*" >&2
  echo "Nothing was written -- live config is untouched." >&2
  exit 1
}

rollback_branch() {
  local reason="$1"
  log "=== ROLLBACK BRANCH TRIGGERED: $reason ==="
  ROLLBACK_LOG="$RUN/rollback.log"
  {
    echo "=== rollback triggered $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "reason: $reason"
  } > "$ROLLBACK_LOG"

  echo "--- step 1: rollback_config.sh ---" | tee -a "$ROLLBACK_LOG"
  if bash phase-10/rollback_config.sh "$BACKUP" 2>&1 | tee -a "$ROLLBACK_LOG"; then
    echo "rollback_config.sh: OK" | tee -a "$ROLLBACK_LOG"
  else
    echo "rollback_config.sh: FAILED -- live file state uncertain, manual inspection required" | tee -a "$ROLLBACK_LOG"
    log "=== ROLLBACK ITSELF FAILED -- STOP, DO NOT IMPROVISE ==="
    echo "WINDOW STATUS: ROLLED-BACK ATTEMPT FAILED -- manual operator intervention required" | tee -a "$ROLLBACK_LOG"
    exit 1
  fi

  echo "--- step 2: restart_service.sh (restore restart) ---" | tee -a "$ROLLBACK_LOG"
  if bash phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 60 2>&1 | tee -a "$ROLLBACK_LOG"; then
    echo "restart_service.sh (rollback restart): OK" | tee -a "$ROLLBACK_LOG"
  else
    echo "restart_service.sh (rollback restart): FAILED" | tee -a "$ROLLBACK_LOG"
    log "=== ROLLBACK RESTART FAILED -- STOP ==="
    echo "WINDOW STATUS: ROLLED-BACK ATTEMPT FAILED -- manual operator intervention required" | tee -a "$ROLLBACK_LOG"
    exit 1
  fi

  echo "--- step 3: health_check.sh ROLLBACK ---" | tee -a "$ROLLBACK_LOG"
  if bash phase-10/health_check.sh ROLLBACK "$ERRLOG_WATERMARK_B" 2>&1 | tee -a "$ROLLBACK_LOG"; then
    echo "health_check.sh ROLLBACK: OK" | tee -a "$ROLLBACK_LOG"
  else
    echo "health_check.sh ROLLBACK: FAILED" | tee -a "$ROLLBACK_LOG"
    log "=== ROLLBACK HEALTH CHECK FAILED -- STOP ==="
    echo "WINDOW STATUS: ROLLED-BACK ATTEMPT FAILED health verification -- manual operator intervention required" | tee -a "$ROLLBACK_LOG"
    exit 1
  fi

  echo "--- step 4: postflight10 (expect BASELINE live sha, restart_expected=1) ---" | tee -a "$ROLLBACK_LOG"
  if postflight10 "$RUN" "$BASELINE_LIVE_SHA" 1 2>&1 | tee -a "$ROLLBACK_LOG"; then
    echo "postflight10 (rollback): OK" | tee -a "$ROLLBACK_LOG"
  else
    echo "postflight10 (rollback): FAILED" | tee -a "$ROLLBACK_LOG"
    log "=== ROLLBACK POSTFLIGHT FAILED -- STOP ==="
    echo "WINDOW STATUS: ROLLED-BACK ATTEMPT FAILED postflight -- manual operator intervention required" | tee -a "$ROLLBACK_LOG"
    exit 1
  fi

  echo "" | tee -a "$ROLLBACK_LOG"
  echo "WINDOW STATUS: ROLLED-BACK" | tee -a "$ROLLBACK_LOG"
  log "=== ROLLBACK COMPLETE AND VERIFIED -- window disposition: ROLLED-BACK ==="
  echo ""
  echo "DISPOSITION: ROLLED-BACK. Reason: $reason. See $ROLLBACK_LOG"
  exit 0
}

# ==========================================================================
# GATE 1 -- preconditions. Abort BEFORE anything is written if any fails.
# ==========================================================================
log "--- GATE 1: preconditions ---"

if [ ! -f "$RUN/health-A.tsv" ]; then
  abort_before_install "GATE 1: $RUN/health-A.tsv not found -- Restart A's health check never ran"
fi
HEALTH_A_FAILS=$(awk -F'\t' 'NR>1 && $2!="PASS"{c++} END{print c+0}' "$RUN/health-A.tsv")
if [ "$HEALTH_A_FAILS" -ne 0 ]; then
  abort_before_install "GATE 1: $RUN/health-A.tsv has $HEALTH_A_FAILS non-PASS row(s) -- Restart A's health check did not fully pass"
fi
log "GATE 1: health-A.tsv all PASS"

LIVE_SHA_NOW=$(shasum -a 256 "$LIVE_CFG" | awk '{print $1}')
if [ "$LIVE_SHA_NOW" != "$BASELINE_LIVE_SHA" ]; then
  abort_before_install "GATE 1: live config sha256 ($LIVE_SHA_NOW) != BASELINE.txt ($BASELINE_LIVE_SHA) -- something already changed it"
fi
log "GATE 1: live config sha256 still equals BASELINE ($LIVE_SHA_NOW)"

if [ ! -f "$BACKUP" ]; then
  abort_before_install "GATE 1: backup file $BACKUP not found"
fi
BACKUP_SHA_NOW=$(shasum -a 256 "$BACKUP" | awk '{print $1}')
if [ "$BACKUP_SHA_NOW" != "$BACKUP_SHA_RECORDED" ]; then
  abort_before_install "GATE 1: backup sha256 ($BACKUP_SHA_NOW) != BASELINE.txt recorded backup sha ($BACKUP_SHA_RECORDED)"
fi
log "GATE 1: backup file present and sha256 matches BASELINE ($BACKUP_SHA_NOW)"

INFLIGHT_OK=0
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  LAST_INFLIGHT=$(grep 'in_flight=' "$FLASHNEXT_LOG" 2>/dev/null | tail -1 || true)
  case "$LAST_INFLIGHT" in
    *"in_flight=0"*) INFLIGHT_OK=1; break ;;
  esac
  sleep 3
done
if [ "$INFLIGHT_OK" -ne 1 ]; then
  abort_before_install "GATE 1: model not idle (in_flight != 0) before install -- last: $LAST_INFLIGHT"
fi
log "GATE 1: in_flight=0 confirmed"
log "GATE 1: ALL PRECONDITIONS PASS"

# Captured here (before Gate 2) rather than immediately before Restart B, so
# it is already defined if the rollback branch fires from Gate 2's failure
# -- the rollback path's own health check needs a watermark too.
ERRLOG_WATERMARK_B=$(wc -l < "$ERR_LOG" | tr -d ' ')
log "errlog watermark captured pre-Gate-2 (reused for Restart B / rollback health scans): $ERRLOG_WATERMARK_B"

# ==========================================================================
# GATE 2 -- re-validate the EXACT bytes about to be installed, run NOW.
# ==========================================================================
log "--- GATE 2: re-validate candidate bytes with the full ladder (now, not just at authoring time) ---"

CANDIDATE_SHA_NOW=$(shasum -a 256 "$CANDIDATE" | awk '{print $1}')
if [ "$CANDIDATE_SHA_NOW" != "$CANDIDATE_SHA_RECORDED" ]; then
  abort_before_install "GATE 2: candidate sha256 ($CANDIDATE_SHA_NOW) != BASELINE.txt recorded / approved sha ($CANDIDATE_SHA_RECORDED) -- the approval in CHANGE-BRIEF.md Section 9 does not cover these bytes"
fi
log "GATE 2: candidate sha256 matches the approved sha256 from CHANGE-BRIEF.md Section 9 ($CANDIDATE_SHA_NOW)"

set +e
LADDER_OUT=$(bash phase-10/validate_config.sh "$CANDIDATE" 2>&1)
LADDER_RC=$?
set -e
echo "$LADDER_OUT" | tee -a "$APPLY_LOG"
LADDER_RUN_DIR=$(cat phase-10/results/CURRENT_VALIDATE_RUN 2>/dev/null || true)
if [ -n "$LADDER_RUN_DIR" ] && [ -f "$LADDER_RUN_DIR/ladder.tsv" ]; then
  cp "$LADDER_RUN_DIR/ladder.tsv" "$RUN/ladder-preinstall.tsv" || true
fi
if [ "$LADDER_RC" -ne 0 ]; then
  abort_before_install "GATE 2: validate_config.sh exited non-zero against the exact candidate bytes -- see $LADDER_RUN_DIR"
fi
log "GATE 2: validate_config.sh PASSED (4/4 rungs) against the exact candidate bytes, run dir $LADDER_RUN_DIR"

# ==========================================================================
# STEP 3 -- install.
# ==========================================================================
log "--- STEP 3: install candidate over live path ---"
if ! cp -p "$CANDIDATE" "$LIVE_CFG"; then
  abort_before_install "STEP 3: cp of candidate over live path did not exit 0"
fi
LIVE_SHA_AFTER_INSTALL=$(shasum -a 256 "$LIVE_CFG" | awk '{print $1}')
if [ "$LIVE_SHA_AFTER_INSTALL" != "$CANDIDATE_SHA_RECORDED" ]; then
  log "STEP 3: FATAL -- live sha256 after cp ($LIVE_SHA_AFTER_INSTALL) != candidate sha256 ($CANDIDATE_SHA_RECORDED)"
  rollback_branch "post-install hash mismatch: cp did not produce the expected bytes"
fi
log "STEP 3: install OK -- live config sha256 now equals candidate sha256 ($LIVE_SHA_AFTER_INSTALL)"

# ==========================================================================
# STEP 4 -- Restart B.
# ==========================================================================
log "--- STEP 4: Restart B ---"
OUTAGE_B_TSV="$RUN/outage-B.tsv"
: > "$OUTAGE_B_TSV"
(
  # `set -e` is active in this subshell (inherited from the parent, which
  # picked it up when it sourced phase-10/probe_lib10.sh -> phase-09/
  # probe_lib.sh's own `set -euo pipefail`). curl exits non-zero (7,
  # connection refused) for every sample taken WHILE litellm is actually
  # down -- i.e. exactly the samples this sampler exists to record. An
  # unguarded `CODE=$(curl ...)` is a simple command whose exit status IS
  # curl's exit status; under `-e` that silently kills this subshell on the
  # very FIRST such sample, well before the outage ends, with no error
  # printed anywhere -- discovered for real during this plan's own Restart
  # B (outage-B.tsv came back with exactly one row). The `|| true` below is
  # not decorative: it is what keeps this loop alive through the outage it
  # is supposed to be measuring.
  while true; do
    EPOCH_MS=$(python3 -c 'import time; print(int(time.time()*1000))' || true)
    CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4000/v1/models 2>/dev/null || true)
    if [ -z "$CODE" ]; then CODE="000"; fi
    printf '%s\t%s\n' "$EPOCH_MS" "$CODE" >> "$OUTAGE_B_TSV"
    sleep 0.5
  done
) &
SAMPLER_PID=$!
log "outage sampler (Restart B) pid=$SAMPLER_PID -> $OUTAGE_B_TSV"

T0_B=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "T0_B=$T0_B"
set +e
bash phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 60 > "$RUN/restart-B.log" 2>&1
RESTART_B_RC=$?
set -e
T1_B=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "T1_B=$T1_B restart_service.sh exit=$RESTART_B_RC"
cat "$RUN/restart-B.log" | tee -a "$APPLY_LOG"

sleep 2
kill "$SAMPLER_PID" 2>/dev/null || true
wait "$SAMPLER_PID" 2>/dev/null || true

{
  echo "T0_B=$T0_B"
  echo "T1_B=$T1_B"
  echo "restart_service.sh exit code: $RESTART_B_RC"
} > "$RUN/restart-B-timestamps.txt"

if [ "$RESTART_B_RC" -ne 0 ]; then
  log "STEP 4: Restart B FAILED"
  rollback_branch "Restart B (restart_service.sh) exited non-zero"
fi
log "STEP 4: Restart B OK"

# ==========================================================================
# STEP 5 -- health.
# ==========================================================================
log "--- STEP 5: health_check.sh B ---"
set +e
bash phase-10/health_check.sh B "$ERRLOG_WATERMARK_B" 2>&1 | tee -a "$APPLY_LOG"
HEALTH_B_RC=${PIPESTATUS[0]}
set -e
if [ "$HEALTH_B_RC" -ne 0 ]; then
  log "STEP 5: health_check.sh B FAILED"
  rollback_branch "health_check.sh B reported at least one failing check"
fi
log "STEP 5: health_check.sh B PASSED"

log "--- STEP 5b: assert all 4 aliases served ---"
ALIASES_BODY="$RUN/health-B-aliases.json"
if ! curl -sf http://127.0.0.1:4000/v1/models -o "$ALIASES_BODY"; then
  log "STEP 5b: curl to /v1/models FAILED"
  rollback_branch "STEP 5b: could not fetch /v1/models to verify the 4 aliases"
fi
set +e
IDS_SORTED=$(jq -r '.data[].id' "$ALIASES_BODY" 2>/dev/null | sort)
set -e
echo "$IDS_SORTED" | tee -a "$APPLY_LOG"
MISSING=""
for want in flashnext flashnext-act flashnext-plan flashnext-reach-xhigh; do
  if ! printf '%s\n' "$IDS_SORTED" | grep -qx "$want"; then
    MISSING="$MISSING $want"
  fi
done
if [ -n "$MISSING" ]; then
  log "STEP 5b: FAIL -- missing aliases:$MISSING"
  rollback_branch "STEP 5b: /v1/models is missing expected alias(es):$MISSING"
fi
log "STEP 5b: all 4 aliases served (flashnext, flashnext-plan, flashnext-act, flashnext-reach-xhigh)"

# ==========================================================================
# STEP 6 -- envelope.
# ==========================================================================
log "--- STEP 6: postflight10 (expect candidate sha, restart_expected=1) ---"
set +e
postflight10 "$RUN" "$CANDIDATE_SHA_RECORDED" 1
POSTFLIGHT_RC=$?
set -e
cat "$RUN/postflight.txt" | tee -a "$APPLY_LOG"
if [ "$POSTFLIGHT_RC" -ne 0 ]; then
  log "STEP 6: postflight10 FAILED"
  rollback_branch "postflight10 after Restart B reported a hard failure"
fi
log "STEP 6: postflight10 PASSED"

echo "" | tee -a "$APPLY_LOG"
echo "WINDOW STATUS: INSTALLED" | tee -a "$APPLY_LOG"
log "=== apply_candidate.sh COMPLETE -- window disposition: INSTALLED ==="
echo ""
echo "DISPOSITION: INSTALLED. Live config sha256 = $LIVE_SHA_AFTER_INSTALL"
exit 0
