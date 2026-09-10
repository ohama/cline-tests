#!/usr/bin/env bash
# mlx_vlm.server(:8000) 직결로 enable_thinking / reasoning_effort 를 측정한다.
#
#   ./howto/measure-at-8000.sh [출력디렉터리]
#
# 왜 :8000 인가 — 게이트웨이가 하나도 없다. litellm 도 role-shim 도 안 거치므로
# "모델 서버 자신이 이 파라미터를 어떻게 다루는가"를 중간 계층의 해석 없이 본다.
#
# 판정 근거는 HTTP 상태가 아니라 **서버 로그의 prompt_tokens** 다.
# 200 은 "받았다"는 뜻일 뿐 "파라미터가 반영됐다"는 뜻이 아니다.
#
# 설명: howto/measuring-thinking-at-8000.md
# bash 3.2 호환.

set -u

SERVER=http://localhost:8000/v1/chat/completions
HEALTH=http://localhost:8000/health
LOG=$HOME/llm-system/services/logs/flashnext.err
MODEL=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
OUT=${1:-phase-11/results/$(date -u +%Y%m%dT%H%M%SZ)-measure8000}
BUDGET=24          # 이 스크립트가 쏠 수 있는 최대 요청 수. 초과하면 중단한다.

mkdir -p "$OUT" || exit 1
SPENT=0

hr(){ printf '%s\n' "────────────────────────────────────────────────────────────"; }

# ── 사전 확인 ───────────────────────────────────────────────────────────────
if ! curl -s --max-time 5 "$HEALTH" | grep -q '"status":"healthy"'; then
  echo "🔴 :8000 이 healthy 가 아니다. 중단." >&2; exit 2
fi
if [ ! -r "$LOG" ]; then
  echo "🔴 서버 로그를 못 읽는다: $LOG" >&2
  echo "   prompt_tokens 역산이 불가능하므로 중단한다 — 200 만으로는 증명이 안 된다." >&2
  exit 2
fi
INFLIGHT=$(grep -o 'in_flight=[0-9]*' "$LOG" | tail -1 | cut -d= -f2)
if [ "${INFLIGHT:-0}" != "0" ]; then
  echo "🟡 in_flight=$INFLIGHT — 모델이 바쁘다(--max-num-seqs 1). 잠시 후 다시 실행하라." >&2
  exit 3
fi
BASE_COUNT=$(grep -c "Prefill started" "$LOG")
echo "run dir : $OUT"
echo "baseline: Prefill started 누적 $BASE_COUNT, in_flight=0, 예산 $BUDGET"

# ── 한 요청 = 한 측정 ───────────────────────────────────────────────────────
# 요청마다 로그 워터마크로 귀속시킨다. tail -N 은 쓰지 않는다 —
# Kanban·Telegram 이 같은 모델을 쓰므로 마지막 줄이 내 요청이라는 보장이 없다.
probe() {
  label="$1"; extra="$2"; maxtok="${3:-4}"

  if [ "$SPENT" -ge "$BUDGET" ]; then
    echo "🔴 예산 $BUDGET 소진. 중단." >&2; exit 4
  fi

  mark=$(wc -l < "$LOG")
  body=$(MODEL="$MODEL" EXTRA="$extra" MAXTOK="$maxtok" python3 -c '
import json, os
b = {"model": os.environ["MODEL"],
     "messages": [{"role": "user", "content": "hi"}],
     "max_tokens": int(os.environ["MAXTOK"])}
e = os.environ["EXTRA"]
if e: b.update(json.loads("{" + e.lstrip(",") + "}"))
print(json.dumps(b))')

  code=$(curl -s -o "$OUT/raw-$label.json" -w '%{http_code}' --max-time 300 \
         -H 'Content-Type: application/json' -d "$body" "$SERVER")
  SPENT=$((SPENT + 1))
  sleep 1

  # 창 안에 Prefill 이 정확히 1건이 아니면 귀속 불가 — 숫자를 지어내지 않는다.
  n=$(sed -n "$((mark+1)),\$p" "$LOG" | grep -c "Prefill started")
  if [ "$n" = "1" ]; then
    tok=$(sed -n "$((mark+1)),\$p" "$LOG" | grep "Prefill started" \
          | grep -oE 'prompt_tokens=[0-9]+' | cut -d= -f2)
  else
    tok="AMBIG($n)"
  fi

  # 두 필드명을 모두 읽는다. 한쪽만 보면 거짓 음성이 난다.
  read rlen clen err <<EOF
$(python3 - "$OUT/raw-$label.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("0 0 unparseable"); raise SystemExit
if "choices" not in d:
    msg = json.dumps(d)[:120].replace(" ", "_")
    print("0 0 " + msg); raise SystemExit
m = d["choices"][0].get("message", {})
r = m.get("reasoning") or m.get("reasoning_content") or ""
c = m.get("content") or ""
print("%d %d -" % (len(r), len(c)))
PY
)
EOF

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$code" "$tok" "$rlen" "$clen" "$err" >> "$OUT/sweep.tsv"
  printf '  %-22s HTTP %-4s prompt_tokens=%-8s reasoning=%-5s content=%s\n' \
         "$label" "$code" "$tok" "$rlen" "$clen"
}

printf 'arm\thttp_code\tprompt_tokens\treasoning_chars\tcontent_chars\tnote\n' > "$OUT/sweep.tsv"

# ── 스윕 A/B — 같은 본문에 파라미터만 바꾼다 ────────────────────────────────
for sweep in A B; do
  hr; echo "스윕 $sweep  (본문 고정: \"hi\", max_tokens=4)"; hr
  probe "$sweep-unspecified"   ""
  probe "$sweep-et-false"      ',"enable_thinking":false'
  probe "$sweep-et-true"       ',"enable_thinking":true'
  probe "$sweep-low"           ',"reasoning_effort":"low"'
  probe "$sweep-medium"        ',"reasoning_effort":"medium"'
  probe "$sweep-xhigh"         ',"reasoning_effort":"xhigh"'
  probe "$sweep-high"          ',"reasoning_effort":"high"'
  probe "$sweep-et-medium"     ',"enable_thinking":true,"reasoning_effort":"medium"'
  probe "$sweep-budget"        ',"thinking_budget":512'
done

# ── 내용 확인 — 토큰이 아니라 실제 사고가 나오나 ────────────────────────────
hr; echo "내용 확인 (max_tokens=256)"; hr
probe "content-unspecified" ""                                 256
probe "content-medium"      ',"reasoning_effort":"medium"'     256
probe "content-et-medium"   ',"enable_thinking":true,"reasoning_effort":"medium"' 256

# ── 결과 ────────────────────────────────────────────────────────────────────
hr
END_COUNT=$(grep -c "Prefill started" "$LOG")
echo "요청: $SPENT 발사 / 예산 $BUDGET   서버 로그 증가: $((END_COUNT - BASE_COUNT))"
echo

echo "델타 (미지정 대비 — 절대값이 아니라 이것을 봐라):"
awk -F'\t' '
  NR>1 && $1 ~ /^A-/ { sub(/^A-/,"",$1); a[$1]=$3 }
  END {
    base = a["unspecified"] + 0
    n = split("et-false et-true low medium xhigh high et-medium budget", k, " ")
    for (i = 1; i <= n; i++) {
      v = a[k[i]]
      if (v ~ /^[0-9]+$/) printf "  %-12s %6d  %+d\n", k[i], v, v - base
      else               printf "  %-12s %6s  (측정 불가 — 아래 HTTP 코드 참조)\n", k[i], v
    }
  }' "$OUT/sweep.tsv"
echo
echo "스윕 A/B 일치 여부:"
awk -F'\t' 'NR>1{s=substr($1,1,1); k=substr($1,3); if(s=="A")a[k]=$3; if(s=="B")b[k]=$3}
  END{d=0; for(x in a) if(a[x]!=b[x]){printf "  ✗ %s: A=%s B=%s\n",x,a[x],b[x]; d++}
      if(d==0) print "  ✅ 전 항목 일치 (재현됨)"}' "$OUT/sweep.tsv"

echo
echo "전체 표: $OUT/sweep.tsv"
echo "원시 응답: $OUT/raw-*.json"
