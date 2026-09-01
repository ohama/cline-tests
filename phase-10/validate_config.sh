#!/usr/bin/env bash
# validate_config.sh <config-path> [--port N]
#
# The pre-install validation ladder plan 10-03 must pass before it is allowed
# to overwrite /Users/ohama/agent-stack/litellm/config.yaml. litellm's
# launchd job has KeepAlive:true and NO --config fallback: a config that
# fails to parse, or that pydantic rejects at startup, takes the whole
# gateway down into a ThrottleInterval:10 crash loop -- and Kanban (:3484)
# and the Telegram connector go with it. Four rungs, cheapest/fastest first:
#
#   Rung 1: YAML parses at all.
#   Rung 2: no drop_params family anywhere (CFG-14 -- banned as project
#           policy: it turns a rejected param into a silent HTTP 200 no-op).
#   Rung 3: the flashnext / flashnext-codex regression baseline survives,
#           deep-equal (CFG-13). Secondary/blind to comment loss -- the raw
#           line-range diff in build_candidate.sh's own proof covers that.
#   Rung 4: the REAL litellm binary boots the config on a scratch port. This
#           is the rung that matters: rungs 1-3 cannot see pydantic-level
#           LiteLLM_Params rejection, which only happens at process startup.
#
# Exits non-zero on the first rung that fails. Never installs anything --
# that is plan 10-03's job, not this script's.
#
# bash 3.2 compatible (no declare -A) -- this machine's default /bin/bash.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE="/Users/ohama/agent-stack/litellm/config.yaml"
LITELLM_BIN="/Users/ohama/agent-stack/venv/bin/litellm"

if [ $# -lt 1 ]; then
  echo "usage: validate_config.sh <config-path> [--port N]" >&2
  exit 2
fi
CFG="$1"
shift
PORT=4010
while [ $# -gt 0 ]; do
  case "$1" in
    --port)
      PORT="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Hard refusal: nothing this script does may ever bind 3000 (public Tailscale
# Funnel) or 4000 (the live litellm). This is the ONLY place those two ports
# are referenced in this file.
if [ "$PORT" = "3000" ] || [ "$PORT" = "4000" ]; then
  echo "REFUSED: port $PORT is banned -- 3000 is the public Tailscale Funnel target, 4000 is the live litellm. Choose a different scratch port." >&2
  exit 2
fi

if [ ! -f "$CFG" ]; then
  echo "FATAL: config not found at $CFG" >&2
  exit 2
fi

# ---- reuse the Phase 9 safety envelope verbatim -- NOT reimplemented ----
# Provides preflight()/postflight(): snapshots the 3 tracked service PIDs and
# the litellm-config.yaml/providers.json hashes before this ladder runs, and
# fails non-zero the moment either differs afterward. This is how "the live
# stack was never touched" is proven mechanically rather than asserted.
# shellcheck source=/dev/null
source "$HERE/../phase-09/probe_lib.sh"

RUN="$HERE/results/$(date -u +%Y%m%dT%H%M%SZ)-validate"
mkdir -p "$RUN"
echo "$RUN" > "$HERE/results/CURRENT_VALIDATE_RUN"
LADDER_TSV="$RUN/ladder.tsv"
: > "$LADDER_TSV"

log_rung() {
  local n="$1" name="$2" result="$3" detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$n" "$name" "$result" "$detail" >> "$LADDER_TSV"
  echo "RUNG $n: $result -- $name ($detail)"
}

fail_out() {
  # Common failure exit: record postflight (best-effort, never masks the
  # real failure), then exit non-zero.
  postflight "$RUN" > /dev/null 2>&1 || true
  echo "LADDER FAILED. See $RUN/ladder.tsv and $RUN/postflight.txt" >&2
  exit 1
}

echo "=== validate_config.sh: $CFG (scratch port $PORT) ==="
echo "run dir: $RUN"

echo "--- preflight (Phase 9 safety envelope) ---"
if ! preflight "$RUN"; then
  echo "FATAL: preflight failed (service count wrong, or model not idle) -- see $RUN/preflight.txt" >&2
  exit 1
fi

# ============================================================
# Rung 1 -- YAML parses
# ============================================================
RUNG1_ERR="$RUN/rung1-stderr.txt"
if CFG_PATH="$CFG" python3 -c "import os,yaml,sys; yaml.safe_load(open(os.environ['CFG_PATH']))" 2>"$RUNG1_ERR"; then
  log_rung 1 yaml-parses PASS "python3 yaml.safe_load succeeded"
else
  log_rung 1 yaml-parses FAIL "$(tr '\n' ' ' < "$RUNG1_ERR")"
  fail_out
fi

# ============================================================
# Rung 2 -- drop_params ban (CFG-14)
# ============================================================
RUNG2_HITS="$RUN/rung2-hits.txt"
if grep -in 'drop_params' "$CFG" > "$RUNG2_HITS" 2>/dev/null; then
  log_rung 2 drop_params-ban FAIL "found: $(tr '\n' ';' < "$RUNG2_HITS")"
  fail_out
else
  log_rung 2 drop_params-ban PASS "no drop_params (any form) found anywhere in the file"
fi

# ============================================================
# Rung 3 -- flashnext / flashnext-codex baseline preserved (CFG-13)
# Secondary/semantic check only -- blind to comment loss and would pass a
# whole-file YAML re-dump. build_candidate.sh's own raw line-range diff
# proof (Task 1) is what catches that; the two checks cover each other's
# blind spot, so both are kept.
# ============================================================
RUNG3_OUT="$RUN/rung3-compare.txt"
if LIVE_PATH="$LIVE" CAND_PATH="$CFG" python3 - > "$RUNG3_OUT" 2>&1 <<'PY'
import os
import sys
import yaml

live = yaml.safe_load(open(os.environ["LIVE_PATH"]))
cand = yaml.safe_load(open(os.environ["CAND_PATH"]))


def find(doc, name):
    for e in doc.get("model_list", []) or []:
        if e.get("model_name") == name:
            return e
    return None


ok = True
for name in ("flashnext", "flashnext-codex"):
    a = find(live, name)
    b = find(cand, name)
    print(f"--- {name} ---")
    print("live:      ", a)
    print("candidate: ", b)
    if a is None or b is None or a != b:
        print(f"MISMATCH: {name}")
        ok = False
    else:
        print(f"MATCH: {name}")

sys.exit(0 if ok else 1)
PY
then
  log_rung 3 baseline-preserved PASS "flashnext + flashnext-codex deep-equal live vs candidate (see rung3-compare.txt)"
else
  log_rung 3 baseline-preserved FAIL "see $RUNG3_OUT"
  cat "$RUNG3_OUT"
  fail_out
fi

# ============================================================
# Rung 4 -- the real binary boots it, on a scratch port, probed with
# GET /v1/models ONLY (never /health -- that issues a real completion and
# would take the model's single --max-num-seqs 1 slot away from
# Kanban/Telegram; never any endpoint that reaches mlx_vlm.server).
# ============================================================
SCRATCH_LOG="$RUN/scratch-boot.log"
SCRATCH_MODELS="$RUN/scratch-models.json"
SCRATCH_PID=""

cleanup_scratch() {
  if [ -n "$SCRATCH_PID" ] && kill -0 "$SCRATCH_PID" 2>/dev/null; then
    kill "$SCRATCH_PID" 2>/dev/null || true
    local waited=0
    while kill -0 "$SCRATCH_PID" 2>/dev/null && [ "$waited" -lt 10 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if kill -0 "$SCRATCH_PID" 2>/dev/null; then
      echo "scratch pid $SCRATCH_PID still alive after 10s, escalating to kill -9" >> "$SCRATCH_LOG"
      kill -9 "$SCRATCH_PID" 2>/dev/null || true
    fi
  fi
}
trap cleanup_scratch EXIT

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN > /dev/null 2>&1; then
  log_rung 4 real-boot FAIL "port $PORT already in use before boot attempt"
  fail_out
fi

: > "$SCRATCH_LOG"
"$LITELLM_BIN" --config "$CFG" --port "$PORT" --host 127.0.0.1 >> "$SCRATCH_LOG" 2>&1 &
SCRATCH_PID=$!
echo "scratch litellm launched: pid=$SCRATCH_PID port=$PORT config=$CFG" | tee -a "$SCRATCH_LOG"

BOOTED=0
PROCESS_DIED=0
elapsed=0
while [ "$elapsed" -lt 90 ]; do
  if curl -sf "http://127.0.0.1:${PORT}/v1/models" -o "$SCRATCH_MODELS" 2>/dev/null; then
    BOOTED=1
    break
  fi
  # Fail fast on a real startup crash (e.g. an unhandled pydantic/config
  # AttributeError during load_config()) instead of waiting out the full
  # 90s timeout for a process that has already exited -- observed live
  # against a seeded null litellm_params mutant: uvicorn's lifespan raises,
  # prints "Application startup failed. Exiting.", and the process is gone
  # well under 90s, yet /v1/models never binds even briefly.
  if ! kill -0 "$SCRATCH_PID" 2>/dev/null; then
    PROCESS_DIED=1
    break
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

if [ "$PROCESS_DIED" -eq 1 ]; then
  log_rung 4 real-boot FAIL "scratch litellm process (pid $SCRATCH_PID) exited after ${elapsed}s before ever serving /v1/models -- see scratch-boot.log for the crash"
  echo "--- last 40 lines of $SCRATCH_LOG ---" >&2
  tail -40 "$SCRATCH_LOG" >&2
  fail_out
fi

if [ "$BOOTED" -ne 1 ]; then
  log_rung 4 real-boot FAIL "timed out after ${elapsed}s waiting for GET /v1/models on 127.0.0.1:${PORT}"
  echo "--- last 40 lines of $SCRATCH_LOG ---" >&2
  tail -40 "$SCRATCH_LOG" >&2
  fail_out
fi

IDS_SORTED=$(jq -r '.data[].id' "$SCRATCH_MODELS" 2>/dev/null | sort)
MISSING=""
for want in flashnext flashnext-plan flashnext-act flashnext-reach-xhigh; do
  if ! printf '%s\n' "$IDS_SORTED" | grep -qx "$want"; then
    MISSING="$MISSING $want"
  fi
done

if [ -n "$MISSING" ]; then
  log_rung 4 real-boot FAIL "booted but /v1/models missing:$MISSING (got: $(printf '%s' "$IDS_SORTED" | tr '\n' ',' ))"
  fail_out
else
  log_rung 4 real-boot PASS "booted on 127.0.0.1:${PORT} after ${elapsed}s, all 4 aliases served"
fi

# cleanup_scratch fires via the EXIT trap below, tearing the scratch process
# down before this script's exit status reaches the caller.

echo "--- postflight (Phase 9 safety envelope) ---"
if ! postflight "$RUN"; then
  echo "FATAL: postflight detected a stack mutation during this ladder run -- see $RUN/postflight.txt" >&2
  exit 1
fi

echo "VALIDATION LADDER: ALL 4 RUNGS PASSED"
echo "run dir: $RUN"
exit 0
