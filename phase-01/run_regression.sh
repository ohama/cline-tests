#!/usr/bin/env bash
# run_regression.sh — VER-01: the re-runnable multi-turn compaction regression test.
#
# One command drives Cline's own tool-call loop through 12 filler files (~2,300
# tokens each via read_file), pushing well past the predicted ~26,214-token
# compaction trigger, and hands both oracles (the --json NDJSON stream and a
# flashnext.err slice) to phase-01/parse_result.py for a three-way verdict.
#
# Preflights (all load-bearing, not ceremony — see RESEARCH.md Pitfall 5, live-
# reproduced three times during Plan 01-01's own execution):
#   A) config guard      — phase-01/config/verify_config.sh
#   B) version guard      — phase-01/config/check_versions.sh
#   C) max_tokens budget  — observed.env (via OBSERVED_ENV_PATH) + a trigger
#                           DERIVED from the live contextWindow, never a baked-in 26542
#   D) server reachable   — one cheap read-only GET, never starts/restarts anything
#
# Env knobs:
#   RUN_DRY=1            - skip preflight D and the real cline invocation; copy a
#                           fixture NDJSON into the results dir instead. Proves the
#                           whole pipeline offline (see phase-01/tests/test_harness_dryrun.sh).
#   DRY_FIXTURE=<path>   - which fixture to use under RUN_DRY=1
#                           (default: phase-01/tests/fixtures/outcome3_below_trigger.ndjson)
#   FILLER_COUNT=<int>   - how many wrapped_NN.txt filler files to list in the prompt (default 12)
#   RUN_TIMEOUT=<secs>   - cline -t timeout (default 1800)
#   RESULTS_ROOT=<path>  - parent directory for the timestamped results dir
#                           (default: phase-01/results). The offline dry-run test points
#                           this at phase-01/results/dryrun/ (already gitignored).
#   OBSERVED_ENV_PATH    - where to read CLINE_OBSERVED_MAX_TOKENS from (default:
#                           phase-01/config/observed.env, owned exclusively by Plan 05).
#                           This script only ever READS this path — never creates,
#                           writes, stubs, restores or deletes it. Tests must override
#                           this to a scratch file they own instead of touching the
#                           real one.
#   PROVIDERS_JSON       - override for the live providers.json read in Preflight C's
#                           trigger derivation (default: ~/.cline/data/settings/providers.json),
#                           same convention as verify_config.sh.
#
# Exit code contract (mirrors phase-01/parse_result.py's CLI):
#   0 = compaction_fired (①)   2 = server_400_no_compaction (②)   3 = other (③)
#   1 = a preflight aborted before any run/classification happened

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="phase-01/config/cline-invocation.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "ABORT: $ENV_FILE not found"
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

echo "=== Preflight A: config guard (verify_config.sh) ==="
if ! bash phase-01/config/verify_config.sh; then
  echo "ABORT: verify_config.sh failed — providers.json has drifted (RESEARCH.md Pitfall 5)."
  echo "Run phase-01/config/apply_provider_config.sh and retry."
  exit 1
fi

echo "=== Preflight B: version guard (check_versions.sh) ==="
if ! bash phase-01/config/check_versions.sh; then
  echo "ABORT: check_versions.sh failed — cline/kanban version drift or a non-compliant plist detected."
  exit 1
fi

# check_versions.sh's own Check B ("no drift across invocations") makes a real
# `cline config --json` call to prove version pins survive an intervening
# invocation. Empirically (this plan's own dry-run testing) that real
# invocation DETERMINISTICALLY strips providers.json's models[]/contextWindow
# override every single time — RESEARCH.md Pitfall 5, not a rare race. A hard
# abort here would mean this harness could never pass preflights at all, since
# its own required preflight sequence is what causes the drift. Because we
# know exactly what caused it and exactly how to restore it, heal it via the
# same idempotent writer Plan 01 built for this, then re-verify. This is a
# heal-known-self-inflicted-drift step, not a blanket "silently fix any
# problem" — an external/unexplained drift still has no auto-heal path here.
echo "=== Preflight A2: config guard re-check (check_versions.sh's own drift probe can itself perturb providers.json) ==="
if ! bash phase-01/config/verify_config.sh; then
  echo "NOTICE: providers.json drifted during check_versions.sh's own 'cline config --json' drift probe (RESEARCH.md Pitfall 5, deterministic). Healing via apply_provider_config.sh."
  if ! bash phase-01/config/apply_provider_config.sh; then
    echo "ABORT: apply_provider_config.sh failed while healing post-check_versions.sh drift."
    exit 1
  fi
  if ! bash phase-01/config/verify_config.sh; then
    echo "ABORT: providers.json still fails verify_config.sh after healing — something beyond the known Pitfall 5 pattern is wrong."
    exit 1
  fi
  echo "OK: providers.json healed and re-verified."
fi

echo "=== Preflight C: max_tokens budget ==="

# Plan 05 owns the default target of this indirection and runs in this same wave.
# This script only ever READS through OBSERVED_ENV_PATH — it must never create,
# write, stub, restore or delete whatever it points at. Callers that need to test
# this preflight point OBSERVED_ENV_PATH at a scratch file they own instead.
OBSERVED_ENV_PATH="${OBSERVED_ENV_PATH:-phase-01/config/observed.env}"

if [ -f "$OBSERVED_ENV_PATH" ]; then
  # shellcheck source=/dev/null
  source "$OBSERVED_ENV_PATH"
fi

if [ -z "${CLINE_OBSERVED_MAX_TOKENS:-}" ]; then
  echo "ABORT: CLINE_OBSERVED_MAX_TOKENS unknown — run Plan 05 (max_tokens investigation) first"
  exit 1
fi

# Derive the trigger from the LIVE config — never trust a baked-in 26542. Plan 05
# Branch B2 may deliberately lower contextWindow as a max_tokens mitigation, and a
# hardcoded literal would silently make this gate (and the classifier's
# below_trigger call) wrong.
PROVIDERS_JSON_FOR_DERIVATION="${PROVIDERS_JSON:-$HOME/.cline/data/settings/providers.json}"
CONTEXT_WINDOW="$(PROVIDERS_JSON="$PROVIDERS_JSON_FOR_DERIVATION" python3 -c '
import json
import os
path = os.environ["PROVIDERS_JSON"]
with open(path) as f:
    data = json.load(f)
cw = data["providers"]["openai-compatible"]["settings"]["models"][0]["contextWindow"]
print(cw)
')"
EFFECTIVE_TRIGGER="$(python3 -c "print(int($CONTEXT_WINDOW * 0.9 * 0.9))")"

TRIGGER_NOTICE=""
if [ -n "${CLINE_PREDICTED_TRIGGER_TOKENS:-}" ] && [ "$CLINE_PREDICTED_TRIGGER_TOKENS" != "$EFFECTIVE_TRIGGER" ]; then
  TRIGGER_NOTICE="NOTICE: CLINE_PREDICTED_TRIGGER_TOKENS=${CLINE_PREDICTED_TRIGGER_TOKENS} but live contextWindow=${CONTEXT_WINDOW} implies ${EFFECTIVE_TRIGGER}; using ${EFFECTIVE_TRIGGER}"
  echo "$TRIGGER_NOTICE"
fi

BUDGET_SUM=$((EFFECTIVE_TRIGGER + CLINE_OBSERVED_MAX_TOKENS))
if [ "$BUDGET_SUM" -ge "$CLINE_SERVER_MAX_KV_SIZE" ]; then
  echo "ABORT: budget exceeded — the server would 400 before the compaction trigger is ever reached."
  echo "  EFFECTIVE_TRIGGER=${EFFECTIVE_TRIGGER}"
  echo "  CLINE_OBSERVED_MAX_TOKENS=${CLINE_OBSERVED_MAX_TOKENS}"
  echo "  sum=${BUDGET_SUM}"
  echo "  CLINE_SERVER_MAX_KV_SIZE=${CLINE_SERVER_MAX_KV_SIZE}"
  exit 1
fi

echo "OK: EFFECTIVE_TRIGGER=${EFFECTIVE_TRIGGER} + CLINE_OBSERVED_MAX_TOKENS=${CLINE_OBSERVED_MAX_TOKENS} = ${BUDGET_SUM} < CLINE_SERVER_MAX_KV_SIZE=${CLINE_SERVER_MAX_KV_SIZE}"

RUN_DRY="${RUN_DRY:-0}"

echo "=== Preflight D: server reachable ==="
if [ "$RUN_DRY" = "1" ]; then
  echo "SKIPPED (RUN_DRY=1)"
else
  HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:4000/v1/models || echo "000")"
  case "$HTTP_CODE" in
    2??)
      echo "OK: server reachable (http_code=$HTTP_CODE)"
      ;;
    *)
      echo "ABORT: server not reachable at http://localhost:4000/v1/models (http_code=$HTTP_CODE). This script never starts/restarts services — that is a human decision."
      exit 1
      ;;
  esac
fi

# RESULTS_ROOT lets the offline dry-run test (phase-01/tests/test_harness_dryrun.sh)
# contain its throwaway results under the already-gitignored phase-01/results/dryrun/
# instead of littering the real results directory. Defaults to the real location.
RESULTS_ROOT="${RESULTS_ROOT:-phase-01/results}"
RESULTS_DIR="$RESULTS_ROOT/$(date -u +%Y-%m-%dT%H%M%SZ)-$$"
mkdir -p "$RESULTS_DIR"
echo "=== Results directory: $RESULTS_DIR ==="

cp "$PROVIDERS_JSON_FOR_DERIVATION" "$RESULTS_DIR/providers.json"

{
  echo "cline: $("$CLINE_BIN" --version)"
  echo "kanban: $("$KANBAN_BIN" --version)"
} > "$RESULTS_DIR/versions.txt"

FILLER_COUNT="${FILLER_COUNT:-12}"
RUN_TIMEOUT="${RUN_TIMEOUT:-1800}"

{
  echo "OBSERVED_ENV_PATH=$OBSERVED_ENV_PATH"
  echo "CLINE_OBSERVED_MAX_TOKENS=$CLINE_OBSERVED_MAX_TOKENS"
  echo "PROVIDERS_JSON=$PROVIDERS_JSON_FOR_DERIVATION"
  echo "CONTEXT_WINDOW=$CONTEXT_WINDOW"
  echo "EFFECTIVE_TRIGGER=$EFFECTIVE_TRIGGER"
  echo "CLINE_PREDICTED_TRIGGER_TOKENS=${CLINE_PREDICTED_TRIGGER_TOKENS:-unset}"
  echo "CLINE_SERVER_MAX_KV_SIZE=$CLINE_SERVER_MAX_KV_SIZE"
  [ -n "$TRIGGER_NOTICE" ] && echo "$TRIGGER_NOTICE"
  echo "CLINE_PROVIDER=$CLINE_PROVIDER"
  echo "CLINE_MODEL=$CLINE_MODEL"
  echo "CLINE_COMPACTION_MODE=$CLINE_COMPACTION_MODE"
  echo "CLINE_COMMON_FLAGS=$CLINE_COMMON_FLAGS"
  echo "RUN_DRY=$RUN_DRY"
  echo "FILLER_COUNT=$FILLER_COUNT"
  echo "RUN_TIMEOUT=$RUN_TIMEOUT"
} > "$RESULTS_DIR/env.txt"

wc -c < "$FLASHNEXT_ERR_LOG" > "$RESULTS_DIR/log_offset.txt"
LOG_OFFSET="$(cat "$RESULTS_DIR/log_offset.txt")"

echo "=== Building prompt ($FILLER_COUNT filler files) ==="
FILE_LIST=""
for ((i = 1; i <= FILLER_COUNT; i++)); do
  padded="$(printf '%02d' "$i")"
  FILE_LIST="${FILE_LIST}${REPO_ROOT}/phase-01/filler/wrapped_${padded}.txt"$'\n'
done
FILE_LIST_TMP="$RESULTS_DIR/.file_list.tmp"
printf '%s' "$FILE_LIST" > "$FILE_LIST_TMP"
python3 - "$FILE_LIST_TMP" "phase-01/prompts/growth_prompt.txt" "$RESULTS_DIR/prompt.txt" <<'PY'
import sys
file_list_path, template_path, out_path = sys.argv[1:4]
file_list = open(file_list_path).read().rstrip("\n")
template = open(template_path).read()
rendered = template.replace("{{FILE_LIST}}", file_list)
open(out_path, "w").write(rendered)
PY
rm -f "$FILE_LIST_TMP"

echo "=== Running (RUN_DRY=$RUN_DRY) ==="
if [ "$RUN_DRY" = "1" ]; then
  DRY_FIXTURE="${DRY_FIXTURE:-phase-01/tests/fixtures/outcome3_below_trigger.ndjson}"
  cp "$DRY_FIXTURE" "$RESULTS_DIR/ndjson.log"
  echo "DRY_RUN (fixture: $DRY_FIXTURE)" > "$RESULTS_DIR/cline_exit.txt"
  echo "OK: dry-run fixture copied into $RESULTS_DIR/ndjson.log"
else
  # -c sets the agent's WORKING DIRECTORY (verified from `cline --help` on 3.0.53:
  #   "-c, --cwd <path>  Working directory"). It is NOT the config-directory flag —
  #   those are `--config <path>` and `--data-dir <path>`, and we deliberately do
  #   NOT pass either: this test must run against the REAL ~/.cline config, because
  #   CFG-01/CFG-02 are precisely the claim that the real providers.json takes effect.
  # Why point cwd at the filler dir: it makes the run's workspace a fixed,
  #   deterministic set of 12 byte-identical generated files instead of the whole
  #   repo, whose contents grow with every results directory. Any workspace-derived
  #   context therefore stays constant across re-runs, which is what VER-01's
  #   "re-runnable" means. File resolution is unaffected — growth_prompt.txt uses
  #   absolute paths.
  # --auto-approve true is passed explicitly even though `cline --help` confirms it
  #   is the default, for the same reason --compaction is pinned: defaults must not
  #   be load-bearing.
  set +e
  CLINE_NO_AUTO_UPDATE=1 "$CLINE_BIN" $CLINE_COMMON_FLAGS --json --auto-approve true \
    -c "${REPO_ROOT}/phase-01/filler" -t "$RUN_TIMEOUT" "$(cat "$RESULTS_DIR/prompt.txt")" \
    2>"$RESULTS_DIR/stderr.log" | tee "$RESULTS_DIR/ndjson.log"
  CLINE_EXIT="${PIPESTATUS[0]}"
  set -e
  echo "$CLINE_EXIT" > "$RESULTS_DIR/cline_exit.txt"
  echo "cline exited $CLINE_EXIT (this is DATA, not a script failure — continuing to classification)"
fi

echo "=== Slicing server log (read-only on the source) ==="
tail -c +"$((LOG_OFFSET + 1))" "$FLASHNEXT_ERR_LOG" > "$RESULTS_DIR/flashnext_window.log"

echo "=== Preflight A, re-run post-run (durability evidence for Pitfall 5) ==="
set +e
bash phase-01/config/verify_config.sh > "$RESULTS_DIR/config_post_run.txt" 2>&1
POST_STATUS=$?
set -e
echo "exit=$POST_STATUS" >> "$RESULTS_DIR/config_post_run.txt"
if [ "$POST_STATUS" -ne 0 ]; then
  echo "WARNING: providers.json drifted DURING this run — see $RESULTS_DIR/config_post_run.txt"
fi

echo "=== Classifying ==="
set +e
python3 phase-01/parse_result.py \
  --ndjson "$RESULTS_DIR/ndjson.log" \
  --server-log "$RESULTS_DIR/flashnext_window.log" \
  --predicted-trigger "$EFFECTIVE_TRIGGER" \
  --out "$RESULTS_DIR"
CLASSIFY_EXIT=$?
set -e

case "$CLASSIFY_EXIT" in
  0) echo "RESULT: (1) compaction_fired — see $RESULTS_DIR/verdict.md" ;;
  2) echo "RESULT: (2) server_400_no_compaction — see $RESULTS_DIR/verdict.md" ;;
  3) echo "RESULT: (3) other — see $RESULTS_DIR/verdict.md" ;;
  *) echo "RESULT: unexpected classifier exit code $CLASSIFY_EXIT — see $RESULTS_DIR/verdict.md" ;;
esac

exit "$CLASSIFY_EXIT"
