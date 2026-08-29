#!/usr/bin/env bash
# apply_provider_config.sh
#
# Idempotent writer for the Cline `openai-compatible` provider config that
# points Cline at the local `flashnext` model (litellm :4000) and overrides
# the contextWindow to 32768 (CFG-01, CFG-02, CFG-07).
#
# Safe to run repeatedly: re-running produces the same end state.
#
# Env overrides (for testing against a scratch copy instead of the real file):
#   PROVIDERS_JSON  - path to providers.json (default: ~/.cline/data/settings/providers.json)
#
# When PROVIDERS_JSON is NOT the default path, the `cline auth` step is
# skipped (that command only ever writes the real file) and only the
# python3 JSON merge + assert-after-write steps run against the override path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROVIDERS_JSON="$HOME/.cline/data/settings/providers.json"
PROVIDERS_JSON="${PROVIDERS_JSON:-$DEFAULT_PROVIDERS_JSON}"
BACKUPS_DIR="$SCRIPT_DIR/backups"

mkdir -p "$BACKUPS_DIR"

if [ -f "$PROVIDERS_JSON" ]; then
  ts="$(date +%Y%m%dT%H%M%S)"
  cp "$PROVIDERS_JSON" "$BACKUPS_DIR/providers.json.$ts"
  echo "Backed up existing $PROVIDERS_JSON to $BACKUPS_DIR/providers.json.$ts"
fi

if [ "$PROVIDERS_JSON" = "$DEFAULT_PROVIDERS_JSON" ]; then
  echo "Running: cline auth openai-compatible -b http://localhost:4000/v1 -k dummy -m flashnext"
  CLINE_NO_AUTO_UPDATE=1 cline auth openai-compatible \
    -b http://localhost:4000/v1 \
    -k dummy \
    -m flashnext
else
  echo "PROVIDERS_JSON override detected ($PROVIDERS_JSON) - skipping 'cline auth' (test mode)"
fi

PROVIDERS_JSON="$PROVIDERS_JSON" python3 - <<'PY'
import json
import os

path = os.environ["PROVIDERS_JSON"]

with open(path) as f:
    data = json.load(f)

data["lastUsedProvider"] = "openai-compatible"

providers = data.setdefault("providers", {})
oc = providers.setdefault("openai-compatible", {})
settings = oc.setdefault("settings", {})

settings["provider"] = "openai-compatible"
settings["apiKey"] = "dummy"
settings["model"] = "flashnext"
settings["baseUrl"] = "http://localhost:4000/v1"
settings["models"] = [
    {"id": "flashnext", "contextWindow": 32768, "maxTokens": 4096}
]

with open(path, "w") as f:
    f.write(json.dumps(data, indent=2))
    f.write("\n")
PY

PROVIDERS_JSON="$PROVIDERS_JSON" python3 - <<'PY'
import json
import os
import sys

path = os.environ["PROVIDERS_JSON"]

with open(path) as f:
    raw = f.read()

data = json.loads(raw)
settings = data["providers"]["openai-compatible"]["settings"]

errors = []

if settings.get("baseUrl") != "http://localhost:4000/v1":
    errors.append(f"baseUrl wrong: {settings.get('baseUrl')!r}")

if settings.get("model") != "flashnext":
    errors.append(f"model wrong: {settings.get('model')!r}")

models = settings.get("models") or []
if not models or models[0].get("contextWindow") != 32768:
    errors.append(f"contextWindow wrong: {models}")

if "flashnext-codex" in raw:
    errors.append("literal string 'flashnext-codex' found in serialized providers.json")

if errors:
    sys.stderr.write("apply_provider_config.sh: post-write assertion FAILED:\n")
    for e in errors:
        sys.stderr.write(f"  - {e}\n")
    sys.exit(1)

print(
    f"OK: baseUrl={settings['baseUrl']} model={settings['model']} "
    f"contextWindow={models[0]['contextWindow']}"
)
PY

echo "apply_provider_config.sh: providers.json set to openai-compatible/flashnext @ http://localhost:4000/v1, contextWindow=32768"
