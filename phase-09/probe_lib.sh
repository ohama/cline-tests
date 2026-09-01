#!/usr/bin/env bash
# probe_lib.sh — Phase 9 shared safety envelope + gpu-stream flake discriminator.
#
# WHY THIS FILE EXISTS
# ---------------------
# Phase 9 answers two milestone gates (PRB-01, PRB-04) by firing small HTTP probes
# directly at the running, unmodified stack. Two failure modes would make those
# answers untrustworthy if not mechanically guarded against:
#
#   1. A probe script could (by bug, not by intent) restart a service or write a
#      config file, silently invalidating "stack unchanged" for every result in
#      the run. `preflight`/`postflight` below make that assertion mechanical —
#      by comparing recorded snapshots, not by trusting a script's own claim that
#      it "didn't touch anything".
#
#   2. `~/llm-system/services/logs/flashnext.err` is known (see 09-RESEARCH.md) to
#      occasionally emit `RuntimeError: There is no Stream(gpu, 1) in current
#      thread.` — the process survives and keeps serving requests, but a request
#      that lands during this condition may return an anomalous/wrong-looking
#      result. If a single unlucky sample during this flake window were recorded
#      as a genuine negative, it could flip a milestone gate on pure noise.
#      `flake_window` + `record_verdict` below exist to make that impossible: a
#      single run can NEVER produce a CONFIRMED negative.
#
# THE FOUR-STATE VERDICT RULE (anti-flake rule — read before touching record_verdict)
# -------------------------------------------------------------------------------
#   - expected/positive result, any flake state         -> CONFIRMED
#       (the flake, when it fires, produces anomalous/failed-looking output; it
#        has no mechanism to fabricate a *positive* result, so a positive result
#        needs no flake-window promotion path.)
#   - unexpected/negative result, DIRTY window           -> DISCARDED-FLAKE
#       (caller must re-run — this sample proves nothing either way)
#   - unexpected/negative result, CLEAN window, 1st time  -> PROVISIONAL-NEGATIVE
#   - unexpected/negative result, CLEAN window, 2nd time  -> CONFIRMED-NEGATIVE
#       (only after the SAME label has already recorded a PROVISIONAL-NEGATIVE in
#        a separate, independent CLEAN window in this run's verdicts.tsv)
#   - exhausted retries (3 attempts) without ever landing a CLEAN, reproduced
#     negative                                            -> INDETERMINATE
#       (a legitimate recorded outcome — NOT a gate verdict. Plan 09-04 treats
#        INDETERMINATE as "no answer", never as "fail".)
#
# A single run may never produce a CONFIRMED negative. Period.
#
# MECHANICAL STACK-UNCHANGED ENFORCEMENT
# ---------------------------------------
# `preflight` snapshots (a) the three service PIDs via launchctl and (b) the
# sha256 of litellm-config.yaml + providers.json, into files under the run dir.
# `postflight` recomputes both and FAILS (non-zero exit) the moment either
# differs from the snapshot — see the two `diff`-style comparisons below. This
# phase does not self-repair on a detected drift (복구 절차 없음, 의도적): if
# something outside this phase wrote a config file mid-run, blindly reverting it
# would destroy the evidence that it happened. `postflight` records the mismatch
# and exits non-zero; nothing here attempts to fix it.
set -euo pipefail

# ---- constants --------------------------------------------------------------
MODEL="/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
FLASHNEXT_LOG="$HOME/llm-system/services/logs/flashnext.err"
LITELLM_CFG="$HOME/local-llm-settings/config/litellm-config.yaml"
PROVIDERS_JSON="$HOME/.cline/data/settings/providers.json"
SVC_RE='com\.ohama\.(flashnext|role-shim|litellm)'

# Absolute path to this phase's directory, used to locate phase-01's
# verify_config.sh regardless of caller's cwd assumptions.
PROBE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_CONFIG_SH="$PROBE_LIB_DIR/../phase-01/config/verify_config.sh"

# ---- new_run_dir --------------------------------------------------------------
# Creates and echoes a fresh timestamped run directory under phase-09/results/.
new_run_dir() {
  local tag="$1"
  local dir="phase-09/results/$(date -u +%Y%m%dT%H%M%SZ)-${tag}"
  mkdir -p "$dir"
  echo "$dir"
}

# ---- preflight ----------------------------------------------------------------
# Snapshots service PIDs + config hashes, records the log watermark, and
# confirms the model is idle (in_flight=0) before any probe fires.
preflight() {
  local run_dir="$1"
  : > "$run_dir/preflight.txt"
  {
    echo "=== preflight $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  } >> "$run_dir/preflight.txt"

  launchctl list | grep -E "$SVC_RE" | awk '{print $3" "$1}' | sort > "$run_dir/pids-before.txt"
  local n_lines
  n_lines=$(wc -l < "$run_dir/pids-before.txt" | tr -d ' ')
  if [ "$n_lines" -lt 3 ]; then
    echo "FATAL: expected 3 services (flashnext, role-shim, litellm), found $n_lines" | tee -a "$run_dir/preflight.txt" >&2
    return 1
  fi
  echo "--- pids-before.txt ---" >> "$run_dir/preflight.txt"
  cat "$run_dir/pids-before.txt" >> "$run_dir/preflight.txt"

  shasum -a 256 "$LITELLM_CFG" "$PROVIDERS_JSON" > "$run_dir/hashes-before.txt"
  echo "--- hashes-before.txt ---" >> "$run_dir/preflight.txt"
  cat "$run_dir/hashes-before.txt" >> "$run_dir/preflight.txt"

  LOG_WATERMARK=$(wc -l < "$FLASHNEXT_LOG" | tr -d ' ')
  export LOG_WATERMARK
  echo "LOG_WATERMARK=$LOG_WATERMARK" >> "$run_dir/preflight.txt"

  echo "--- tail -2 $FLASHNEXT_LOG ---" >> "$run_dir/preflight.txt"
  tail -2 "$FLASHNEXT_LOG" >> "$run_dir/preflight.txt" 2>&1 || true

  local attempt=0
  local idle_ok=0
  local last_inflight_line=""
  while [ "$attempt" -lt 10 ]; do
    last_inflight_line=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    if [[ "$last_inflight_line" == *"in_flight=0"* ]]; then
      idle_ok=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle after 10 retries (last in_flight line: $last_inflight_line)" | tee -a "$run_dir/preflight.txt" >&2
    return 1
  fi
  echo "idle check: OK -- $last_inflight_line" >> "$run_dir/preflight.txt"

  echo "--- advisory (hint only, NOT a hard gate): running cline processes ---" >> "$run_dir/preflight.txt"
  pgrep -fl 'bin/\.cline|bin/cline' >> "$run_dir/preflight.txt" 2>/dev/null || echo "(none found)" >> "$run_dir/preflight.txt"

  return 0
}

# ---- postflight ---------------------------------------------------------------
# Recomputes PIDs + config hashes and fails the run (non-zero exit) if either
# differs from the preflight snapshot. Also runs verify_config.sh once
# (non-fatal, recorded) as an independent providers.json shape check.
postflight() {
  local run_dir="$1"
  local ok=1
  : > "$run_dir/postflight.txt"
  echo "=== postflight $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$run_dir/postflight.txt"

  launchctl list | grep -E "$SVC_RE" | awk '{print $3" "$1}' | sort > "$run_dir/pids-after.txt"
  if diff -q "$run_dir/pids-before.txt" "$run_dir/pids-after.txt" > /dev/null 2>&1; then
    echo "OK: service PIDs unchanged (no restart)" >> "$run_dir/postflight.txt"
  else
    {
      echo "FAIL: service PIDs changed -- a service restarted. Stack-unchanged constraint VIOLATED."
      echo "--- before ---"; cat "$run_dir/pids-before.txt"
      echo "--- after ---"; cat "$run_dir/pids-after.txt"
    } >> "$run_dir/postflight.txt"
    ok=0
  fi

  shasum -a 256 "$LITELLM_CFG" "$PROVIDERS_JSON" > "$run_dir/hashes-after.txt"
  if diff -q "$run_dir/hashes-before.txt" "$run_dir/hashes-after.txt" > /dev/null 2>&1; then
    echo "OK: config file hashes unchanged (litellm-config.yaml, providers.json)" >> "$run_dir/postflight.txt"
  else
    {
      echo "FAIL: config file hash changed -- something wrote litellm-config.yaml or providers.json."
      echo "Stack-unchanged constraint VIOLATED."
      echo "--- before ---"; cat "$run_dir/hashes-before.txt"
      echo "--- after ---"; cat "$run_dir/hashes-after.txt"
      echo "복구 절차 없음(의도적): Phase 9 는 어떤 설정도 쓰지 않으므로 이 분기는 발동해서는 안 된다."
      echo "발동했다면 이 페이즈 밖의 무언가가 설정을 바꾼 것이므로, postflight 는 불일치를 기록하고"
      echo "non-zero 로 종료한다. Phase 9 가 스스로 복구를 시도하지 않는다 -- 무엇이 썼는지 모르는 채"
      echo "되돌리면 그 사실 자체가 사라진다."
    } >> "$run_dir/postflight.txt"
    ok=0
  fi

  echo "--- independent check: verify_config.sh (non-fatal, always recorded) ---" >> "$run_dir/postflight.txt"
  if [ -x "$VERIFY_CONFIG_SH" ] || [ -f "$VERIFY_CONFIG_SH" ]; then
    bash "$VERIFY_CONFIG_SH" >> "$run_dir/postflight.txt" 2>&1 || true
  else
    echo "(verify_config.sh not found at $VERIFY_CONFIG_SH -- skipped)" >> "$run_dir/postflight.txt"
  fi

  if [ "$ok" -ne 1 ]; then
    return 1
  fi
  return 0
}

# ---- flake_window ---------------------------------------------------------------
# The gpu-stream flake discriminator (09-RESEARCH.md
# "Distinguishing a Genuine Negative from the no Stream(gpu, 1) Flake").
# Scans flashnext.err from LOG_WATERMARK (set by preflight) to end-of-file for
# `RuntimeError: There is no Stream(gpu, 1) in current thread.` occurrences.
# Echoes CLEAN (count 0) or DIRTY (count>0) on stdout; writes flake-count.txt
# and (if dirty) flake-lines.txt with context for timestamp comparison.
flake_window() {
  local run_dir="$1"
  local count
  count=$(sed -n "${LOG_WATERMARK},\$p" "$FLASHNEXT_LOG" | grep -c 'no Stream(gpu' || true)
  echo "$count" > "$run_dir/flake-count.txt"
  if [ "$count" -gt 0 ]; then
    {
      echo "=== flake window DIRTY -- count=$count (window: log lines $LOG_WATERMARK..EOF) ==="
      sed -n "${LOG_WATERMARK},\$p" "$FLASHNEXT_LOG" | grep -n -B3 -A3 'no Stream(gpu' || true
    } > "$run_dir/flake-lines.txt"
    echo "DIRTY"
  else
    echo "CLEAN"
  fi
}

# ---- record_verdict ---------------------------------------------------------------
# record_verdict <run_dir> <label> <result> <flake_state>
#   <result>      : "expected" (positive/matches-hypothesis) | "unexpected"
#                   (negative/contradicts-hypothesis) | "indeterminate" (caller
#                   has exhausted its 3-attempt retry budget without landing a
#                   reproduced CLEAN-window negative)
#   <flake_state> : "CLEAN" | "DIRTY" (output of flake_window), ignored when
#                   <result> is "expected" or "indeterminate"
#
# Appends one TSV line to "$run_dir"/verdicts.tsv:
#   timestamp \t label \t result \t flake_state \t verdict
#
# Implements the four-state anti-flake rule documented in the header comment
# above. THIS IS THE WHOLE POINT OF THIS FUNCTION:
#   - expected                       -> CONFIRMED (flake cannot fabricate a positive)
#   - unexpected + DIRTY              -> DISCARDED-FLAKE (caller must re-run)
#   - unexpected + CLEAN, 1st time    -> PROVISIONAL-NEGATIVE
#   - unexpected + CLEAN, 2nd time    -> CONFIRMED-NEGATIVE (only after this same
#                                        label already has a PROVISIONAL-NEGATIVE
#                                        recorded from an earlier, independent
#                                        CLEAN window in this same verdicts.tsv)
#   - indeterminate                   -> INDETERMINATE (retries exhausted; this is
#                                        a legitimate recorded outcome, NOT a gate
#                                        verdict -- plan 09-04 treats it as "no
#                                        answer", never as "fail")
#   A single run may never produce a CONFIRMED negative.
record_verdict() {
  local run_dir="$1" label="$2" result="$3" flake_state="${4:-}"
  local ts verdict
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tsv="$run_dir/verdicts.tsv"
  touch "$tsv"

  case "$result" in
    expected)
      verdict="CONFIRMED"
      ;;
    indeterminate)
      verdict="INDETERMINATE"
      ;;
    unexpected)
      if [ "$flake_state" = "DIRTY" ]; then
        verdict="DISCARDED-FLAKE"
      else
        # CLEAN and unexpected. Promote to CONFIRMED-NEGATIVE only if this label
        # already carries a PROVISIONAL-NEGATIVE from a prior, independent CLEAN
        # observation in this same run's verdicts.tsv.
        local prior_provisional
        prior_provisional=$(awk -F'\t' -v l="$label" '$2==l && $5=="PROVISIONAL-NEGATIVE" {c++} END{print c+0}' "$tsv")
        if [ "$prior_provisional" -ge 1 ]; then
          verdict="CONFIRMED-NEGATIVE"
        else
          verdict="PROVISIONAL-NEGATIVE"
        fi
      fi
      ;;
    *)
      echo "record_verdict: unknown result '$result' (expected: expected|unexpected|indeterminate)" >&2
      return 1
      ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$label" "$result" "$flake_state" "$verdict" >> "$tsv"
  echo "$verdict"
}
