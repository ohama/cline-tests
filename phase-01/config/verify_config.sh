#!/usr/bin/env bash
# verify_config.sh
#
# Pre-run guard: asserts ~/.cline/data/settings/providers.json still holds
# the flashnext provider override (CFG-01, CFG-02, CFG-07). RESEARCH.md
# Pitfall 5 observed manually-added providers.json fields silently
# disappearing after a few `cline` invocations; a regression run against a
# silently-reverted config would measure the 128k fallback and report a
# false result. Call this immediately before every real test run.
#
# Env overrides (for testing against a scratch copy instead of the real file):
#   PROVIDERS_JSON  - path to providers.json (default: ~/.cline/data/settings/providers.json)
#
# Exit 0 + "OK: ..." on success.
# Exit 1 + "FAIL: <which assertion> ... <observed value>" on any failure.
#
# --- 2026-09-02 addition (plan 11-03, USE-02, ROADMAP Phase 11 criterion 2) ---
# This script now also asserts the cline-plan/cline-act wrapper pairing (mode flag vs. alias)
# and the absence of --thinking passthrough, via phase-11/verify_wrappers.sh, in a section
# appended near the end of this file. That check cannot live in the providers.json assertions
# above: providers.json records neither the mode flag nor which alias a given invocation used
# (phase-10/VRF-04-OBSERVATION.md §1) — there is nothing left in it to inspect after the fact.
#
# Exit 3 (not 1) means the WRAPPER check failed, not a providers.json assertion above — a caller
# can tell the two apart by exit code alone and must not "heal" a wrapper fault by re-applying
# provider config (phase-04/run_headless.sh and phase-04/verify_sandbox_via_cline.sh both guard
# on this distinction).
#
# Two additional env knobs control the wrapper section only (the providers.json assertions above
# are unaffected by both):
#   VERIFY_CONFIG_NO_WRAPPER_CHECK=1  - skip the wrapper section entirely. This is the recursion
#                                       brake: phase-11/wrapper_common.sh's own pre-run/post-run
#                                       calls back into this script export this on every call, so
#                                       this script never re-enters phase-11/verify_wrappers.sh
#                                       (which would otherwise call the wrappers, which call this
#                                       script, forever).
#   PROVIDERS_JSON=<non-default path> - also skips the wrapper section. A scratch-providers test
#                                       has no business also gating on the live wrapper set.
# Both skips print a line beginning "SKIP[WRAPPER]:" — visibly, never silently.
# See phase-11/WRAPPER-DESIGN.md §8 and phase-11/verify_wrappers.sh for the full rationale.

set -euo pipefail

DEFAULT_PROVIDERS_JSON="$HOME/.cline/data/settings/providers.json"
PROVIDERS_JSON="${PROVIDERS_JSON:-$DEFAULT_PROVIDERS_JSON}"

set +e
PROVIDERS_JSON="$PROVIDERS_JSON" python3 - <<'PY'
import json
import os
import sys

path = os.environ["PROVIDERS_JSON"]

try:
    with open(path) as f:
        raw = f.read()
except OSError as e:
    print(f"FAIL: could not read {path!r}: {e}")
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"FAIL: {path!r} is not valid JSON: {e}")
    sys.exit(1)

try:
    settings = data["providers"]["openai-compatible"]["settings"]
except (KeyError, TypeError):
    print("FAIL: providers.openai-compatible.settings missing entirely")
    sys.exit(1)

base_url = settings.get("baseUrl")
if base_url != "http://localhost:4000/v1":
    print(f"FAIL: baseUrl expected 'http://localhost:4000/v1', observed {base_url!r}")
    sys.exit(1)

model = settings.get("model")
if model != "flashnext":
    print(f"FAIL: model expected 'flashnext', observed {model!r}")
    sys.exit(1)

# 🔴 2026-08-30 정정 — contextWindow 는 settings 최상위 필드다.
# provider-settings.ts:266 이 settings.contextWindow 를 maxInputTokens 로 매핑하고,
# 압축 트리거가 그 값을 읽는다. models[] 는 VS Code 용 경로이고 CLI 는 무시한다.
context_window = settings.get("contextWindow")
if context_window != 29000:
    print(f"FAIL: top-level contextWindow expected 29000, observed {context_window!r}")
    sys.exit(1)

if settings.get("models"):
    print(
        "FAIL: settings.models[] present — CLI 가 읽지 않는 경로다. "
        "이 값이 있으면 최상위 contextWindow 를 넣었다는 사실이 가려진다"
    )
    sys.exit(1)

if "flashnext-codex" in raw:
    print(f"FAIL: literal string 'flashnext-codex' found in {path!r}")
    sys.exit(1)

print(
    "OK: providers.json holds flashnext @ localhost:4000/v1, "
    "top-level contextWindow=29000, no models[] override, no codex alias"
)

# 최상위 contextWindow 는 maxInputTokens 로 그대로 들어가므로 트리거는 ×0.9 한 번뿐이다.
# (maxInputTokens 가 없을 때만 contextWindow×0.9 후 다시 ×0.9 인 2단 폴백이 적용된다.)
trigger = context_window * 0.9
print(
    f"trigger = maxInputTokens x 0.9 = {trigger:.0f} "
    f"— PROVEN to fire: phase-01/results/exp-verify29k/ (2026-08-30, 서버 400 0건)"
)
PY
py_status=$?
set -e

if [ "$py_status" -ne 0 ]; then
  exit 1
fi

if [ "$PROVIDERS_JSON" = "$DEFAULT_PROVIDERS_JSON" ]; then
  if grep -rl 'flashnext-codex' "$HOME/.cline" >/dev/null 2>&1; then
    echo "FAIL: literal string 'flashnext-codex' found somewhere under $HOME/.cline"
    grep -rl 'flashnext-codex' "$HOME/.cline" 2>/dev/null
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Wrapper section (USE-02, ROADMAP Phase 11 criterion 2, plan 11-03).
#
# A mode/alias mismatch or a leaked --thinking flag is a property of an INVOCATION, not of
# providers.json — providers.json records neither the mode flag nor which alias a given call
# used (phase-10/VRF-04-OBSERVATION.md §1: `cline -m` leaves `model` at "flashnext" regardless
# of which alias actually ran). So this section delegates to phase-11/verify_wrappers.sh, which
# inspects the wrapper SCRIPTS themselves (static content) and the argv they actually construct
# (behavioural, against a stub binary) instead of anything in this file.
#
# RECURSION BRAKE: phase-11/wrapper_common.sh's own pre-run/post-run config-guard calls to THIS
# script export VERIFY_CONFIG_NO_WRAPPER_CHECK=1 on every internal call, specifically so this
# section does not re-enter phase-11/verify_wrappers.sh (which in turn runs the wrappers, which
# would otherwise call this script again, forever). When that variable is set, this section is
# skipped, visibly, on stdout — never silently.
#
# PROVIDERS_JSON OVERRIDE BRAKE: a caller pointing PROVIDERS_JSON at a scratch copy (testing
# against a fixture, not the live wrapper set) has no business also gating on the live wrappers,
# so this section is skipped there too, for the same reason.
# ---------------------------------------------------------------------------
if [ "${VERIFY_CONFIG_NO_WRAPPER_CHECK:-0}" = "1" ]; then
  echo "SKIP[WRAPPER]: wrapper check suppressed by VERIFY_CONFIG_NO_WRAPPER_CHECK=1"
elif [ "$PROVIDERS_JSON" != "$DEFAULT_PROVIDERS_JSON" ]; then
  echo "SKIP[WRAPPER]: wrapper check suppressed — PROVIDERS_JSON is set to a non-default path ($PROVIDERS_JSON)"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  VERIFY_WRAPPERS_SH="$ROOT/phase-11/verify_wrappers.sh"
  set +e
  WRAPPER_OUT="$(bash "$VERIFY_WRAPPERS_SH" 2>&1)"
  WRAPPER_STATUS=$?
  set -e
  echo "$WRAPPER_OUT"
  if [ "$WRAPPER_STATUS" -ne 0 ]; then
    echo "FAIL[WRAPPER]: mode/alias pairing check failed — see above"
    exit 3
  fi
fi

exit 0
