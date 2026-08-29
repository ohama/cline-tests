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

exit 0
