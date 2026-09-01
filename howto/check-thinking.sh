#!/usr/bin/env bash
# Qwen3.8 Flash-Next 의 thinking 설정을 확인한다.
#
#   ./howto/check-thinking.sh            라이브 확인 (모델에 tiny 요청 3건)
#   ./howto/check-thinking.sh --offline  파일만 읽는다 (모델 안 건드림)
#
# 설명: howto/thinking-and-reasoning-effort.md
# bash 3.2 호환 (이 머신에 연관 배열 없음).

set -u

LIVE_CFG=/Users/ohama/agent-stack/litellm/config.yaml
MIRROR_CFG=$HOME/local-llm-settings/config/litellm-config.yaml
FLASHNEXT_LOG=$HOME/llm-system/services/logs/flashnext.err
MODEL=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
SHIM=http://localhost:8011/v1/chat/completions
GATEWAY=http://localhost:4000/v1/chat/completions

OFFLINE=0
[ "${1:-}" = "--offline" ] && OFFLINE=1

hr() { printf '%s\n' "────────────────────────────────────────────────────────────"; }
h()  { echo; hr; echo "$1"; hr; }

h "1. 설정 파일 — 어느 쪽이 진짜인가"

PLIST_CFG=$(plutil -p "$HOME/Library/LaunchAgents/com.ohama.litellm.plist" 2>/dev/null \
            | grep -A8 ProgramArguments | grep -o '"/[^"]*config\.yaml"' | tr -d '"')
if [ -n "$PLIST_CFG" ]; then
  echo "launchd 가 litellm 에 넘기는 설정:  $PLIST_CFG"
  [ "$PLIST_CFG" = "$LIVE_CFG" ] && echo "  → 예상과 일치" \
                                 || echo "  🔴 예상($LIVE_CFG)과 다르다. 아래 결과를 믿지 마라."
else
  echo "🔴 plist 를 못 읽었다. litellm 이 어느 설정을 쓰는지 확인 불가."
fi
if [ -f "$MIRROR_CFG" ]; then
  if diff -q "$LIVE_CFG" "$MIRROR_CFG" >/dev/null 2>&1; then
    echo "사본($MIRROR_CFG)은 현재 원본과 동일 — sync 됨"
  else
    echo "🟡 사본이 원본과 다르다. sync.sh 가 아직 안 돌았거나 사본을 직접 고쳤다."
    echo "   사본을 고쳐도 litellm 에는 아무 효과가 없다."
  fi
fi

h "2. 별칭에 thinking 파라미터가 적혀 있나"

if grep -qE "enable_thinking|reasoning_effort" "$LIVE_CFG" 2>/dev/null; then
  grep -nE "model_name|enable_thinking|reasoning_effort" "$LIVE_CFG"
else
  echo "어느 별칭에도 thinking 파라미터가 없다."
  echo "→ 전부 모델 기본값으로 동작한다 (enable_thinking: false = 사고 안 함)."
  echo
  echo "현재 별칭:"
  grep -n "model_name" "$LIVE_CFG" | sed 's/^/  /'
fi
echo
echo "별칭별 접두사 (reasoning_effort 수용 여부를 가른다):"
# 두 서식을 모두 잡는다: 여러 줄 블록의 "model:" 과 한 줄 litellm_params 의 "{ model: }"
grep -oE "model: [a-z_]+/(chat_completions/)?" "$LIVE_CFG" \
  | sed 's/model: //' | sort | uniq -c \
  | awk '{printf "  %-26s %s개 별칭\n", $2, $1}'
echo
echo "  openai/                    reasoning_effort 넣으면 400"
echo "  openai/chat_completions/   Responses API 브릿지 — codex 계열"
echo "  hosted_vllm/               reasoning_effort 허용"

h "3. 이 모델이 지원하는 값 (VALIDATED.md §4)"
cat <<'TBL'
  enable_thinking   false (기본)   사고 없음
                    true           reasoning 필드에 사고 과정
  reasoning_effort  low/medium/xhigh   OK
                    high           ❌ 500 — 이 모델에 없는 값. xhigh 를 써라
  thinking_budget   아무 값        ❌ 500 — drafter 와 함께 못 쓴다
TBL

if [ "$OFFLINE" = "1" ]; then
  h "라이브 확인은 건너뛴다 (--offline)"
  echo "모델에 실제로 도달하는지 보려면 --offline 없이 실행하라."
  exit 0
fi

h "4. 라이브 확인 — 설정이 모델까지 가는가"

if pgrep -f "probe_.*\.(sh|py)" >/dev/null 2>&1; then
  echo "🔴 다른 프로브가 실행 중이다. 모델이 --max-num-seqs 1 이라 측정이 섞인다."
  echo "   끝난 뒤 다시 실행하라. 중단한다."
  exit 2
fi
if [ ! -r "$FLASHNEXT_LOG" ]; then
  echo "🔴 서버 로그를 못 읽는다: $FLASHNEXT_LOG"
  echo "   prompt_tokens 역산이 불가능하므로 중단한다 — HTTP 200 만으로는 증명이 안 된다."
  exit 2
fi

# 같은 본문에 effort 만 바꿔 3건. 각 요청을 로그 워터마크로 귀속시킨다
# (tail -N 은 다른 테넌트 요청이 끼면 조용히 틀린다).
probe() {
  label="$1"; extra="$2"
  mark=$(wc -l < "$FLASHNEXT_LOG")
  body="{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4$extra}"
  code=$(curl -s -o /tmp/.ct.$$ -w '%{http_code}' --max-time 60 \
         -H 'Content-Type: application/json' -d "$body" "$SHIM")
  sleep 1
  lines=$(sed -n "$((mark+1)),\$p" "$FLASHNEXT_LOG" | grep -c "Prefill started")
  tok=$(sed -n "$((mark+1)),\$p" "$FLASHNEXT_LOG" | grep "Prefill started" \
        | grep -oE 'prompt_tokens=[0-9]+' | head -1 | cut -d= -f2)
  if [ "$lines" != "1" ]; then
    printf '  %-28s HTTP %s   prompt_tokens=?  🟡 로그에 %s건 — 귀속 불가(다른 요청이 끼었다)\n' \
      "$label" "$code" "$lines"
    echo "?" ; return
  fi
  printf '  %-28s HTTP %s   prompt_tokens=%s\n' "$label" "$code" "$tok"
  echo "$tok"
}

echo "같은 요청('hi', max_tokens=4)에 effort 만 바꿔 3건 — :8011 직결"
echo
BASE=$(probe "미지정 (기준)"            "" | tail -1)
MED=$(probe  "reasoning_effort: medium" ",\"reasoning_effort\":\"medium\"" | tail -1)
XH=$(probe   "reasoning_effort: xhigh"  ",\"reasoning_effort\":\"xhigh\"" | tail -1)
rm -f /tmp/.ct.$$

echo
if [ "$BASE" = "?" ] || [ "$MED" = "?" ] || [ "$XH" = "?" ]; then
  echo "🟡 표본 하나 이상이 귀속 불가 — 델타를 계산하지 않는다."
  echo "   모델이 한가할 때 다시 실행하라."
  exit 3
fi

echo "델타 (절대값이 아니라 이것을 봐라 — 절대값은 과거에 이동한 적이 있다):"
printf '  medium  %+d   기대 -2\n'  "$((MED - BASE))"
printf '  xhigh   %+d   기대 +40\n' "$((XH  - BASE))"
echo
if [ "$((MED - BASE))" = "-2" ] && [ "$((XH - BASE))" = "40" ]; then
  echo "✅ 두 델타 모두 기대와 일치 — reasoning_effort 가 모델까지 도달하고 있다."
else
  echo "🟡 델타가 기대와 다르다. 이것은 고장일 수도 있고, 시스템 프롬프트가"
  echo "   바뀐 것일 수도 있다. phase-09/PRB-03-ORACLE.md 의 측정 조건과 대조하라."
fi

h "5. litellm 경유 — 게이트웨이가 파라미터를 막는가"
gw() {
  printf '  %-34s ' "$1"
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 60 \
    -H 'Content-Type: application/json' -H 'Authorization: Bearer dummy' \
    -d "{\"model\":\"flashnext\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4$2}" \
    "$GATEWAY"
}
gw "reasoning_effort: medium" ",\"reasoning_effort\":\"medium\""
gw "enable_thinking: true"    ",\"enable_thinking\":true"
echo
echo "  400 = litellm 이 막았다 (별칭 접두사가 openai/ 라서)"
echo "  200 = 통과했다. 단 모델 도달 증거는 아니다 — 위 4번이 그 증거다."
echo
echo "설명: howto/thinking-and-reasoning-effort.md"
