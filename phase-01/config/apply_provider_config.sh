#!/usr/bin/env bash
# apply_provider_config.sh
#
# Idempotent writer for the Cline `openai-compatible` provider config that
# points Cline at the local `flashnext` model (litellm :4000) and overrides
# the context window (CFG-01, CFG-02, CFG-07).
#
# 🔴 2026-08-30 정정 — contextWindow 는 settings 의 **최상위** 필드다.
#   provider-settings.ts:150  contextWindow: z.number().int().positive().optional()
#   provider-settings.ts:266  maxInputTokens: settings.contextWindow
#   handler-factory.ts        "maxInputTokens is where ProviderSettings.contextWindow
#                              lands via toProviderConfig (the providers.json path
#                              used by CLI/Core hosts)"
#   `models[]` 는 VS Code 용 per-model override 경로이며 CLI 는 읽지 않는다.
#   이전 버전은 models[] 에 넣었고, 그래서 자동 압축이 전혀 발동하지 않았다.
#
# 🔴 값이 32768 이 아니라 29000 인 이유 — 오버슈트.
#   트리거는 maxInputTokens × 0.9 이고, 실제 압축은 트리거를 약 2,700~3,100 토큰
#   초과한 뒤에 발동한다(한 턴 늦게 반응). 서버 예산은 prompt + max_tokens ≤ 32768,
#   max_tokens 실측값은 2048 이다.
#     32768 → trigger 29,491 + 오버슈트 3,100 + 2,048 = 34,639  ❌ 벽을 넘는다
#     29000 → trigger 26,100 + 오버슈트 3,130 + 2,048 = 31,278  ✅ 실측 완주
#   근거: phase-01/results/exp-verify29k/ (필러 18개 완주, 서버 400 0건)
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
# 최상위 contextWindow — 이것이 maxInputTokens 로 매핑되어 압축 트리거를 결정한다.
settings["contextWindow"] = 29000
# models[] 는 CLI 가 읽지 않는 경로이며, cline 이 기동 시 정규화하면서 버린다.
# 남겨두면 "설정이 사라진다"는 오해만 만들므로 명시적으로 제거한다.
settings.pop("models", None)

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

ctx = settings.get("contextWindow")
if ctx != 29000:
    errors.append(f"top-level contextWindow wrong: {ctx!r} (expected 29000)")

if settings.get("models"):
    errors.append(
        "settings.models[] present — CLI 가 읽지 않는 경로다. 최상위 contextWindow 를 써야 한다"
    )

if "flashnext-codex" in raw:
    errors.append("literal string 'flashnext-codex' found in serialized providers.json")

if errors:
    sys.stderr.write("apply_provider_config.sh: post-write assertion FAILED:\n")
    for e in errors:
        sys.stderr.write(f"  - {e}\n")
    sys.exit(1)

print(
    f"OK: baseUrl={settings['baseUrl']} model={settings['model']} "
    f"contextWindow={ctx} (top-level) -> trigger={int(ctx * 0.9)}"
)
PY

echo "apply_provider_config.sh: providers.json set to openai-compatible/flashnext @ http://localhost:4000/v1, top-level contextWindow=29000 (trigger 26100)"
