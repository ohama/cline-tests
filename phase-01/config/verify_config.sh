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

models = settings.get("models")
if not isinstance(models, list) or len(models) != 1:
    print(f"FAIL: models[] expected length 1, observed {models!r}")
    sys.exit(1)

if models[0].get("id") != "flashnext":
    print(f"FAIL: models[0].id expected 'flashnext', observed {models[0].get('id')!r}")
    sys.exit(1)

context_window = models[0].get("contextWindow")
if context_window != 32768:
    print(f"FAIL: contextWindow expected 32768, observed {context_window!r}")
    sys.exit(1)

if "flashnext-codex" in raw:
    print(f"FAIL: literal string 'flashnext-codex' found in {path!r}")
    sys.exit(1)

print(
    "OK: providers.json holds flashnext @ localhost:4000/v1, "
    "contextWindow=32768, no codex alias"
)

trigger = context_window * 0.9 * 0.9
print(
    f"predicted trigger (RESEARCH.md decompiled formula) — NOT yet proven to fire: "
    f"contextWindow={context_window} -> trigger={trigger:.0f}"
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
