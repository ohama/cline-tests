#!/usr/bin/env bash
# phase-11/probe_lib11.sh — Phase 11 safety envelope (plan 11-04).
#
# Modelled on phase-10/probe_lib10.sh (read that file first) but with THREE
# deliberate differences from it, each documented inline where it applies:
#
#  1. providers.json is judged on `model` and `contextWindow` ONLY, delegated
#     to phase-01/config/verify_config.sh (called with
#     VERIFY_CONFIG_NO_WRAPPER_CHECK=1, so the wrapper section that same
#     script also owns does not fire here and cannot recurse — see
#     phase-11/WRAPPER-DESIGN.md §8 and phase-01/config/verify_config.sh's
#     own header comment). sha256 and updatedAt are recorded as
#     OBSERVATIONS, printed to the postflight log, and NEVER compared for
#     pass/fail. Reason: `cline -m` legitimately rewrites `updatedAt` on
#     every call (.planning/STATE.md 2026-09-01 correction;
#     phase-10/PHASE-10-FINDINGS.md §4.4) — a hash-based guard
#     (phase-10/probe_lib10.sh's own postflight10, which hard-fails on ANY
#     providers.json sha256 change) would fire on every single wrapper
#     invocation this phase makes and be muted within a day.
#  2. com.ohama.litellm's pid must be unchanged, unconditionally. Phase 11
#     opens no maintenance window, unlike Phase 10 — this file's
#     postflight11 takes no third argument naming whether a restart of any
#     service is acceptable, by design, unlike phase-10/probe_lib10.sh's
#     postflight10 (which does take such a parameter).
#  3. A live-request counter with a hard cap, enforced in code, not
#     remembered — phase-10/PHASE-10-FINDINGS.md §4.5: plan 10-04 fired 48
#     requests against a stated budget of 17 and only discovered the
#     overage after the fact.
#
# Reuses phase-09/probe_lib.sh's flake_window()/record_verdict() verbatim, by
# sourcing (not forking) it — the four-state anti-flake rule does not change
# here and should not be re-derived.
#
# 🔴 set -e WARNING (read before adding a new line to this file).
# phase-09/probe_lib.sh itself does `set -euo pipefail` at its own top level.
# Sourcing it below therefore turns -e ON in every shell that sources THIS
# file too, from that line onward — including every probe script in this
# phase. phase-10/PHASE-10-FINDINGS.md §4.2 documents an outage sampler that
# was silently killed by exactly this inherited -e, on the very
# connection-refused event it existed to record, because a command's
# assignment (`out=$(cmd)`) or bare invocation failed outside any
# conditional context. Every place below (and in every script that sources
# this file) that expects a command to legitimately return non-zero — an
# idle-poll retry, a budget-cap check, an intentionally-nonzero
# verify_config.sh call, a real cline invocation whose exit code we want to
# record rather than have kill the script — is written as
# `cmd || var=$?` (var initialised to 0 first) or wrapped in `if`/`||`/`&&`,
# never as a bare `cmd; var=$?` two-liner. Do not "simplify" one of those
# guards; that is exactly the bug this comment exists to prevent recurring.
#
# bash 3.2 compatible: no declare -A, no ${var^^}; bare "${empty[@]}" throws
# under `set -u` on this machine — always use "${arr[@]:-}".
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROVIDERS="$HOME/.cline/data/settings/providers.json"
FLASHNEXT_LOG="$HOME/llm-system/services/logs/flashnext.err"
SVC_RE='com\.ohama\.(flashnext|role-shim|litellm)'
VERIFY_CONFIG_SH="$HERE/../phase-01/config/verify_config.sh"

# ---- reuse phase-09/probe_lib.sh verbatim for flake_window/record_verdict --
# shellcheck source=/dev/null
source "$HERE/../phase-09/probe_lib.sh"

RUN_REQ_CAP="${RUN_REQ_CAP:-14}"
export RUN_REQ_CAP
BUDGET_STATE_FILE="$HERE/results/.budget-watermark-11-04"

# ---- new_run_dir11 <tag> ----------------------------------------------------
new_run_dir11() {
  local tag="$1"
  local dir
  dir="$HERE/results/$(date -u +%Y%m%dT%H%M%SZ)-${tag}"
  mkdir -p "$dir"
  echo "$dir"
}

# ---- providers_fields <out_file> -------------------------------------------
# Extracts model / contextWindow / updatedAt / sha256 from the REAL
# providers.json into 4 exported vars (PROV_MODEL, PROV_CTXWIN,
# PROV_UPDATEDAT, PROV_SHA256) and writes a small `key=value` block to
# <out_file>. Never itself aborts the caller on a read failure (internal
# `|| true` guards) — the hard judgement of these fields lives in
# postflight11, not here.
providers_fields() {
  local out_file="$1"
  PROV_SHA256="$(shasum -a 256 "$PROVIDERS" 2>/dev/null | awk '{print $1}')"
  local py_out
  py_out="$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    s = d["providers"]["openai-compatible"]["settings"]
    print(s.get("model", ""))
    print(s.get("contextWindow", ""))
    print(d["providers"]["openai-compatible"].get("updatedAt", ""))
except Exception as e:
    print("READ_ERROR")
    print("READ_ERROR")
    print(str(e))
' "$PROVIDERS" 2>/dev/null)" || true
  PROV_MODEL="$(printf '%s\n' "$py_out" | sed -n 1p)"
  PROV_CTXWIN="$(printf '%s\n' "$py_out" | sed -n 2p)"
  PROV_UPDATEDAT="$(printf '%s\n' "$py_out" | sed -n 3p)"
  {
    echo "model=$PROV_MODEL"
    echo "contextWindow=$PROV_CTXWIN"
    echo "updatedAt=$PROV_UPDATEDAT"
    echo "sha256=$PROV_SHA256"
  } > "$out_file"
  export PROV_MODEL PROV_CTXWIN PROV_UPDATEDAT PROV_SHA256
}

# ---- wait_idle11 ------------------------------------------------------------
# Same pattern as phase-09/phase-10's own idle-poll: confirm in_flight=0
# before firing anything, 10 retries at 3s, same as this project's standing
# "polite tenant" convention (--max-num-seqs 1, shared with Kanban/Telegram).
wait_idle11() {
  local attempt=0 idle_ok=0 last=""
  while [ "$attempt" -lt 10 ]; do
    last=$(grep 'in_flight=' "$FLASHNEXT_LOG" | tail -1 || true)
    case "$last" in
      *"in_flight=0"*) idle_ok=1; break ;;
    esac
    attempt=$((attempt + 1))
    sleep 3
  done
  if [ "$idle_ok" -ne 1 ]; then
    echo "FATAL: model not idle after 10 retries (last in_flight line: $last)" >&2
    return 1
  fi
  echo "idle check: OK -- $last"
  return 0
}

# ---- init_budget_watermark11 ------------------------------------------------
# Idempotent: writes the CURRENT flashnext.err line count to
# BUDGET_STATE_FILE only if that file does not already exist. This makes the
# watermark PERSISTENT and SHARED across every probe script this plan runs
# (probe_open_items.sh, probe_wrapper_volume.sh, and this file's own
# selftest) — the 14-request cap is a whole-plan budget, not a per-script
# one, so the denominator every script measures against must be the same
# single point in time: the moment the very first probe script in this
# plan's execution called this function.
init_budget_watermark11() {
  mkdir -p "$HERE/results"
  if [ ! -f "$BUDGET_STATE_FILE" ]; then
    wc -l < "$FLASHNEXT_LOG" | tr -d ' ' > "$BUDGET_STATE_FILE"
    echo "budget watermark initialised: $(cat "$BUDGET_STATE_FILE") (line count of $FLASHNEXT_LOG at this plan's first probe-lib call)" >&2
  fi
}

# ---- count_requests_since <watermark_line_count> ---------------------------
# Counts `Generation queued` lines STRICTLY AFTER the given watermark (a line
# count, e.g. from `wc -l` at some earlier point). One `Generation queued`
# line is emitted per accepted model request — 1:1 with `Prefill started` in
# this log (cross-checked at plan-execution time: both counts equal 902
# immediately before this plan's Task 1 ran).
count_requests_since() {
  local watermark="${1:-0}"
  local n
  n=$(tail -n "+$((watermark + 1))" "$FLASHNEXT_LOG" 2>/dev/null | grep -c 'Generation queued') || true
  [ -z "${n:-}" ] && n=0
  printf '%s' "$n"
}

# ---- assert_budget <run_dir> ------------------------------------------------
# Call BEFORE every live request (curl or cline/wrapper invocation). Aborts
# the WHOLE SCRIPT (exit 1) if the running total, measured against this
# plan's persistent shared watermark, is already at or over RUN_REQ_CAP —
# refusing to let one more request push the plan over budget. This function
# only ever CHECKS; the row recording a request that actually fired happens
# in log_budget_row, called after the request.
assert_budget() {
  local run_dir="${1:-}"
  init_budget_watermark11
  local baseline current
  baseline="$(cat "$BUDGET_STATE_FILE")"
  current="$(count_requests_since "$baseline")"
  if [ "$current" -ge "$RUN_REQ_CAP" ]; then
    echo "ABORT[BUDGET]: running_total=$current is already >= cap=$RUN_REQ_CAP (baseline_line=$baseline in $FLASHNEXT_LOG) -- refusing to issue another live request" >&2
    if [ -n "$run_dir" ]; then
      if [ ! -s "$run_dir/budget.tsv" ]; then
        printf 'seq\tlabel\trequests_this_step\trunning_total\tcap\n' > "$run_dir/budget.tsv"
      fi
      printf 'ABORT\tbudget-cap-reached\t0\t%s\t%s\n' "$current" "$RUN_REQ_CAP" >> "$run_dir/budget.tsv"
    fi
    exit 1
  fi
}

# ---- log_budget_row <run_dir> <seq> <label> <requests_this_step> -----------
# Call AFTER every live request, whether or not it was the request expected
# (an operational retry counts too — it is still a request against the
# shared model). Appends one row to "$run_dir"/budget.tsv: seq, label,
# requests_this_step, running_total, cap. running_total is RECOMPUTED from
# the log every time (never accumulated in a shell variable), so it can
# never silently drift from what the log actually shows.
log_budget_row() {
  local run_dir="$1" seq="$2" label="$3" step="$4"
  init_budget_watermark11
  local baseline current
  baseline="$(cat "$BUDGET_STATE_FILE")"
  current="$(count_requests_since "$baseline")"
  if [ ! -s "$run_dir/budget.tsv" ]; then
    printf 'seq\tlabel\trequests_this_step\trunning_total\tcap\n' > "$run_dir/budget.tsv"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$seq" "$label" "$step" "$current" "$RUN_REQ_CAP" >> "$run_dir/budget.tsv"
}

# ---- preflight11 <run_dir> --------------------------------------------------
preflight11() {
  local run_dir="$1"
  : > "$run_dir/preflight.txt"
  echo "=== preflight11 $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$run_dir/preflight.txt"

  launchctl list | grep -E "$SVC_RE" | awk '{print $3" "$1}' | sort > "$run_dir/pids-before.txt"
  local n_lines
  n_lines=$(wc -l < "$run_dir/pids-before.txt" | tr -d ' ')
  if [ "$n_lines" -lt 3 ]; then
    echo "FATAL: expected 3 services (flashnext, role-shim, litellm), found $n_lines" | tee -a "$run_dir/preflight.txt" >&2
    return 1
  fi
  echo "--- pids-before.txt ---" >> "$run_dir/preflight.txt"
  cat "$run_dir/pids-before.txt" >> "$run_dir/preflight.txt"

  providers_fields "$run_dir/providers-before.txt"
  echo "--- providers-before.txt (OBSERVATIONS ONLY -- sha256/updatedAt are never judged, model/contextWindow are) ---" >> "$run_dir/preflight.txt"
  cat "$run_dir/providers-before.txt" >> "$run_dir/preflight.txt"

  LOG_WATERMARK=$(wc -l < "$FLASHNEXT_LOG" | tr -d ' ')
  export LOG_WATERMARK
  echo "LOG_WATERMARK=$LOG_WATERMARK (this script's own flake-window anchor, per phase-09/probe_lib.sh's flake_window)" >> "$run_dir/preflight.txt"

  init_budget_watermark11
  echo "BUDGET_STATE_FILE=$BUDGET_STATE_FILE watermark=$(cat "$BUDGET_STATE_FILE") cap=$RUN_REQ_CAP (persistent across every probe script this plan runs)" >> "$run_dir/preflight.txt"

  if ! wait_idle11 >> "$run_dir/preflight.txt" 2>&1; then
    echo "FATAL: model not idle" | tee -a "$run_dir/preflight.txt" >&2
    return 1
  fi

  echo "--- advisory (hint only, NOT a hard gate): running cline processes ---" >> "$run_dir/preflight.txt"
  pgrep -fl 'bin/\.cline|bin/cline' >> "$run_dir/preflight.txt" 2>/dev/null || echo "(none found)" >> "$run_dir/preflight.txt"

  cline --version > "$run_dir/cline-version-before.txt" 2>&1 || true
  echo "cline --version (before): $(cat "$run_dir/cline-version-before.txt")" >> "$run_dir/preflight.txt"

  return 0
}

# ---- postflight11 <run_dir> -------------------------------------------------
postflight11() {
  local run_dir="$1"
  local ok=1
  : > "$run_dir/postflight.txt"
  echo "=== postflight11 $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$run_dir/postflight.txt"

  launchctl list | grep -E "$SVC_RE" | awk '{print $3" "$1}' | sort > "$run_dir/pids-after.txt"

  local svc before after
  for svc in com.ohama.flashnext com.ohama.role-shim com.ohama.litellm; do
    before=$(awk -v s="$svc" '$1==s{print $2}' "$run_dir/pids-before.txt")
    after=$(awk -v s="$svc" '$1==s{print $2}' "$run_dir/pids-after.txt")
    if [ -n "$before" ] && [ "$before" = "$after" ]; then
      echo "OK: $svc pid unchanged ($before)" >> "$run_dir/postflight.txt"
    else
      echo "FAIL: $svc pid changed (before=$before after=$after) -- Phase 11 opens NO maintenance window; MUST NEVER restart (this file's postflight11 accepts no argument that would make a service restart acceptable, unlike phase-10/probe_lib10.sh's postflight10)" >> "$run_dir/postflight.txt"
      ok=0
    fi
  done

  providers_fields "$run_dir/providers-after.txt"
  echo "--- providers-after.txt (OBSERVATIONS ONLY -- sha256/updatedAt are never judged, model/contextWindow are) ---" >> "$run_dir/postflight.txt"
  cat "$run_dir/providers-after.txt" >> "$run_dir/postflight.txt"

  local model_before ctxwin_before model_after ctxwin_after
  model_before=$(awk -F= '$1=="model"{print $2}' "$run_dir/providers-before.txt")
  ctxwin_before=$(awk -F= '$1=="contextWindow"{print $2}' "$run_dir/providers-before.txt")
  model_after=$(awk -F= '$1=="model"{print $2}' "$run_dir/providers-after.txt")
  ctxwin_after=$(awk -F= '$1=="contextWindow"{print $2}' "$run_dir/providers-after.txt")

  if [ "$model_before" = "$model_after" ] && [ "$model_before" = "flashnext" ]; then
    echo "OK: providers.json model unchanged ('$model_before') -- JUDGED field" >> "$run_dir/postflight.txt"
  else
    echo "FAIL: providers.json model drifted (before='$model_before' after='$model_after') -- JUDGED field" >> "$run_dir/postflight.txt"
    ok=0
  fi
  if [ "$ctxwin_before" = "$ctxwin_after" ] && [ "$ctxwin_before" = "29000" ]; then
    echo "OK: providers.json contextWindow unchanged ('$ctxwin_before') -- JUDGED field" >> "$run_dir/postflight.txt"
  else
    echo "FAIL: providers.json contextWindow drifted (before='$ctxwin_before' after='$ctxwin_after') -- JUDGED field" >> "$run_dir/postflight.txt"
    ok=0
  fi

  local updatedat_before updatedat_after sha_before sha_after
  updatedat_before=$(awk -F= '$1=="updatedAt"{print $2}' "$run_dir/providers-before.txt")
  updatedat_after=$(awk -F= '$1=="updatedAt"{print $2}' "$run_dir/providers-after.txt")
  sha_before=$(awk -F= '$1=="sha256"{print $2}' "$run_dir/providers-before.txt")
  sha_after=$(awk -F= '$1=="sha256"{print $2}' "$run_dir/providers-after.txt")
  if [ "$updatedat_before" = "$updatedat_after" ]; then
    echo "OBSERVATION (not judged): updatedAt unchanged ($updatedat_before)" >> "$run_dir/postflight.txt"
  else
    echo "OBSERVATION (not judged): updatedAt moved ($updatedat_before -> $updatedat_after) -- EXPECTED, cline -m rewrites it every call (.planning/STATE.md 2026-09-01 correction)" >> "$run_dir/postflight.txt"
  fi
  if [ "$sha_before" = "$sha_after" ]; then
    echo "OBSERVATION (not judged): providers.json sha256 unchanged ($sha_before)" >> "$run_dir/postflight.txt"
  else
    echo "OBSERVATION (not judged): providers.json sha256 moved ($sha_before -> $sha_after) -- expected side effect of the updatedAt rewrite above, never itself a failure condition in this file" >> "$run_dir/postflight.txt"
  fi

  echo "--- delegated invariant: VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash $VERIFY_CONFIG_SH ---" >> "$run_dir/postflight.txt"
  local vc_out vc_status=0
  vc_out="$(VERIFY_CONFIG_NO_WRAPPER_CHECK=1 bash "$VERIFY_CONFIG_SH" 2>&1)" || vc_status=$?
  echo "$vc_out" >> "$run_dir/postflight.txt"
  echo "verify_config.sh exit status: $vc_status" >> "$run_dir/postflight.txt"
  if [ "$vc_status" -ne 0 ]; then
    echo "FAIL: verify_config.sh (providers.json section) exited non-zero -- this is the delegated invariant this file relies on instead of a hash comparison" >> "$run_dir/postflight.txt"
    ok=0
  fi

  cline --version > "$run_dir/cline-version-after.txt" 2>&1 || true
  echo "cline --version (after): $(cat "$run_dir/cline-version-after.txt")" >> "$run_dir/postflight.txt"
  if [ -f "$run_dir/cline-version-before.txt" ]; then
    if diff -q "$run_dir/cline-version-before.txt" "$run_dir/cline-version-after.txt" >/dev/null 2>&1; then
      echo "OK: cline --version stable across this script's run" >> "$run_dir/postflight.txt"
    else
      echo "LOUD: cline --version DRIFTED during this script's run (before=$(cat "$run_dir/cline-version-before.txt") after=$(cat "$run_dir/cline-version-after.txt")) -- the comparison this run made spans two binaries" | tee -a "$run_dir/postflight.txt" >&2
    fi
  fi

  # ---- no self-repair -- same rule as Phase 9/10 ----
  if [ "$ok" -ne 1 ]; then
    echo "postflight11: one or more HARD checks FAILED -- no self-repair performed. See above." >> "$run_dir/postflight.txt"
    return 1
  fi
  return 0
}
