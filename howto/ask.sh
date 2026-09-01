#!/usr/bin/env bash
# 사고 끔/켬 모드로 Qwen3.8 Flash-Next 에 물어본다. :8011 직결이라 재기동이 필요 없다.
#
#   ./howto/ask.sh --act  "질문"    사고 끔 (빠름)
#   ./howto/ask.sh --plan "질문"    사고 켬, medium
#   ./howto/ask.sh --max  "질문"    사고 켬, xhigh (최대)
#
#   -t N   max_tokens (기본: act 256, plan/max 1024)
#   -q     사고 과정 숨기고 답만
#
# 설명: howto/fast-and-deep-mode.md
# bash 3.2 호환.

set -u

MODEL=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
SHIM=http://localhost:8011/v1/chat/completions
LOG=$HOME/llm-system/services/logs/flashnext.err

MODE=""; QUIET=0; MAXTOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --act)  MODE=act;  shift ;;
    --plan) MODE=plan; shift ;;
    --max)  MODE=max;  shift ;;
    -q)     QUIET=1;   shift ;;
    -t)     MAXTOK="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) break ;;
  esac
done

PROMPT="$*"
if [ -z "$MODE" ] || [ -z "$PROMPT" ]; then
  echo "사용법: $0 --act|--plan|--max [-q] [-t N] \"질문\"" >&2
  echo "  --act   사고 끔        --plan  사고 켬 medium        --max  사고 켬 xhigh" >&2
  exit 64
fi

# 사고를 켜면 사고가 완성 예산을 먼저 쓴다. 넉넉히 주지 않으면 답 본문이 빈 채로
# finish_reason=length 로 끝난다 (Phase 9 에서 max_tokens=300 에 실제로 발생).
case "$MODE" in
  act)  EXTRA=""                                                        ; DEF=256  ;;
  plan) EXTRA=',"enable_thinking":true,"reasoning_effort":"medium"'     ; DEF=1024 ;;
  max)  EXTRA=',"enable_thinking":true,"reasoning_effort":"xhigh"'      ; DEF=1024 ;;
esac
[ -n "$MAXTOK" ] || MAXTOK=$DEF

if pgrep -f "probe_.*\.(sh|py)" >/dev/null 2>&1; then
  echo "🟡 프로브가 실행 중이다. 모델이 --max-num-seqs 1 이라 줄을 서게 된다." >&2
fi

MARK=""
[ -r "$LOG" ] && MARK=$(wc -l < "$LOG")

REQ=$(PROMPT="$PROMPT" MODEL="$MODEL" MAXTOK="$MAXTOK" EXTRA="$EXTRA" python3 -c '
import json, os
b = {"model": os.environ["MODEL"],
     "messages": [{"role": "user", "content": os.environ["PROMPT"]}],
     "max_tokens": int(os.environ["MAXTOK"])}
b.update(json.loads("{" + os.environ["EXTRA"].lstrip(",") + "}") if os.environ["EXTRA"] else {})
print(json.dumps(b, ensure_ascii=False))')

T0=$(date +%s)
RESP=$(curl -s --max-time 600 -H 'Content-Type: application/json' -d "$REQ" "$SHIM")
T1=$(date +%s)

echo "$RESP" | RESP_QUIET="$QUIET" RESP_MODE="$MODE" python3 -c '
import json, os, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print("🔴 응답이 JSON 이 아니다:\n" + raw[:500]); sys.exit(1)
if "choices" not in d:
    print("🔴 오류 응답:\n" + json.dumps(d, ensure_ascii=False, indent=2)[:800]); sys.exit(1)
ch = d["choices"][0]; m = ch.get("message", {})
# 계층마다 이름이 다르다: :8011 은 reasoning, litellm 경유는 reasoning_content.
# 한쪽만 보면 거짓 음성이 난다 (Phase 9 에서 실제로 발생).
r = m.get("reasoning") or m.get("reasoning_content") or ""
c = m.get("content") or ""
quiet = os.environ["RESP_QUIET"] == "1"
if r and not quiet:
    print("─── 사고 (%d자) %s" % (len(r), "─" * 30))
    print(r.strip()); print()
if r or os.environ["RESP_MODE"] != "act":
    print("─── 답 %s" % ("─" * 42))
print(c.strip() if c else "(본문이 비었다)")
u = d.get("usage", {})
print()
print("prompt=%s  completion=%s  finish=%s  reasoning=%d자"
      % (u.get("prompt_tokens","?"), u.get("completion_tokens","?"),
         ch.get("finish_reason","?"), len(r)))
if ch.get("finish_reason") == "length" and not c:
    print("🔴 사고가 예산을 다 써서 답이 비었다. -t 로 max_tokens 를 늘려라.")
'

echo "elapsed=$((T1 - T0))s"

# 서버 로그로 귀속 — 설정이 실제로 모델까지 갔는지 보는 유일한 증거.
# 창 안에 Prefill 이 1건이 아니면 다른 테넌트 요청이 낀 것이므로 보고만 하고 단정하지 않는다.
if [ -n "$MARK" ] && [ -r "$LOG" ]; then
  N=$(sed -n "$((MARK+1)),\$p" "$LOG" | grep -c "Prefill started")
  if [ "$N" = "1" ]; then
    TOK=$(sed -n "$((MARK+1)),\$p" "$LOG" | grep "Prefill started" \
          | grep -oE 'prompt_tokens=[0-9]+' | cut -d= -f2)
    echo "서버 로그 prompt_tokens=$TOK  (모드 $MODE)"
  else
    echo "서버 로그: 창 안에 Prefill 이 ${N}건 — 귀속 불가(동시 요청). 토큰 판정 생략."
  fi
fi
