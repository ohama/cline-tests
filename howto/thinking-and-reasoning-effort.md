# Qwen3.8 Flash-Next 의 thinking 설정 — 어디서 어떻게 확인하나

**질문:** `enable_thinking` 과 `reasoning_effort` 가 지금 어떻게 설정돼 있고,
그게 실제로 먹히는지 내가 직접 어떻게 확인하나?

**답은 세 층으로 나뉜다.** 이 셋은 서로 다른 질문이고, 자주 혼동된다.

| 층 | 답하는 질문 | 확인 방법 |
|---|---|---|
| **1. 문서** | 이 모델이 **지원하는** 값은? | 파일 읽기 |
| **2. 설정** | 지금 **적혀 있는** 값은? | 설정 파일 읽기 |
| **3. 동작** | 그게 실제로 **모델까지 갔나**? | 서버 로그 |

🔴 **3층이 핵심이다.** HTTP 200 은 "게이트웨이가 받았다"는 뜻이지 "모델이 그 설정으로
생각했다"는 뜻이 아니다. 이 프로젝트는 v1 에서 설정 파일에 값이 멀쩡히 있는데도 CLI 가
그 칸을 읽지 않아 이틀을 썼다.

---

## 빠른 길 — 스크립트 하나

```bash
./howto/check-thinking.sh            # 라이브 확인 (모델에 요청 3건)
./howto/check-thinking.sh --offline  # 파일만 읽음 (모델 안 건드림)
```

아래는 그 스크립트가 무엇을 왜 확인하는지에 대한 설명이다.

---

## 1층. 이 모델이 지원하는 값

**출처:** `~/local-llm-settings/VALIDATED.md` §4 — 서버에 직접 물어서 확인된 기록

```bash
sed -n '/^## 4/,/^## 5/p' ~/local-llm-settings/VALIDATED.md
```

| 파라미터 | 값 | 결과 |
|---|---|---|
| `enable_thinking` | `false` **(기본값)** | 사고 없음, 바로 답 |
| | `true` | `reasoning` 필드에 사고 과정 |
| `reasoning_effort` | `low` / `medium` / `xhigh` | ✅ |
| | `high` | ❌ **500** — 이 모델에 없는 값 |
| `thinking_budget` | 아무 값 | ❌ **500** — drafter 와 함께 못 쓴다 |

### 함정 셋

🔴 **`high` 는 없다. `xhigh` 다.** 흔한 이름이라 반사적으로 쓰기 쉽다.

```
Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low.
```

🔴 **`enable_thinking` 의 기본값은 `false`** 다. 아무것도 안 보내면 사고하지 않는다.

🔴 **`thinking_budget` 은 현재 구성에서 못 쓴다.** 지금 `:8000` 은 drafter 를 붙인
fast mode 이고, 둘은 같이 못 간다. 쓰려면 drafter 없이 재기동해야 한다.

---

## 2층. 지금 설정 파일에 적혀 있는 값

### 🔴 설정 파일이 두 개다. 하나는 가짜다

```bash
# litellm 이 실제로 읽는 파일 — 이걸 고쳐야 한다
/Users/ohama/agent-stack/litellm/config.yaml

# 생성된 사본 — 고쳐봐야 아무 효과 없다. sync.sh 가 덮어쓴다
~/local-llm-settings/config/litellm-config.yaml
```

어느 쪽이 진짜인지는 launchd 가 넘기는 인자로 확인한다:

```bash
plutil -p ~/Library/LaunchAgents/com.ohama.litellm.plist | grep -A6 ProgramArguments
```

### 별칭에 thinking 설정이 있는지 보기

```bash
grep -nE "model_name|enable_thinking|reasoning_effort" /Users/ohama/agent-stack/litellm/config.yaml
```

**2026-09-01 현재: 어느 별칭에도 thinking 파라미터가 없다.** 전부 모델 기본값
(`enable_thinking: false`)으로 동작한다. Phase 10 이 `flashnext-plan` 별칭을 추가하면서
바뀔 예정이다.

### 접두사가 중요하다

```yaml
model: openai//path/to/model         # reasoning_effort 를 넣으면 400
model: hosted_vllm//path/to/model    # reasoning_effort 허용
```

설치된 litellm 1.86.1 에서 `openai` 프로바이더는 `reasoning_effort` 를 지원 목록에
넣지 않는다. 직접 확인하려면:

```bash
grep -n "reasoning_effort" \
  /Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/llms/hosted_vllm/chat/transformation.py
#   → 92:  params.extend(["reasoning_effort", "thinking"])

grep -n "reasoning_effort" \
  /Users/ohama/agent-stack/venv/lib/python3.12/site-packages/litellm/llms/openai/chat/gpt_transformation.py
#   → (아무것도 안 나옴)
```

🔴 **litellm 은 설정에 심은 파라미터와 클라이언트가 보낸 파라미터를 하나로 합친 뒤에
검증한다.** "설정에 넣으면 검증을 우회한다"는 직관은 틀렸다.

---

## 3층. 실제로 모델까지 갔는지 확인 (가장 중요)

### 방법 A — 응답에 사고가 들어있나

가장 직접적이다. 요청을 보내고 응답 필드를 본다.

```bash
curl -s http://localhost:8011/v1/chat/completions \
  -H 'Content-Type: application/json' -d '{
    "model": "/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4",
    "messages": [{"role":"user","content":"2+2는?"}],
    "reasoning_effort": "medium",
    "max_tokens": 64
  }' | python3 -m json.tool
```

🔴 **필드 이름이 계층마다 다르다.** 둘 다 봐야 한다:

| 계층 | 필드 이름 |
|---|---|
| `:8011` 직결 | `.choices[0].message.reasoning` |
| `:4000` litellm 경유 | `.choices[0].message.reasoning_content` |

한쪽만 보고 "비어 있다"고 판단하면 **거짓 음성**이 난다. Phase 9 에서 실제로 이 실수가
났고, 파라미터가 안 먹는다고 잘못 읽었다.

### 방법 B — 서버 로그의 `prompt_tokens` 로 역산 ⭐

**이게 진짜 증거다.** effort 값에 따라 시스템 프롬프트 길이가 달라지므로,
`prompt_tokens` 를 보면 설정이 모델까지 갔는지 알 수 있다.

```bash
tail -5 ~/llm-system/services/logs/flashnext.err | grep "Prefill started"
```

```
2026-08-29 14:32:27 - INFO - Prefill started: request=82e2… prompt_tokens=22 …
                                                            ^^^^^^^^^^^^^^^^
```

**같은 요청 본문**에 effort 만 바꿔가며 보내면 이 값이 이렇게 움직인다:

| 설정 | 델타 (미지정 대비) |
|---|---|
| 미지정 | 기준 |
| `medium` | **−2** |
| `low` | **+28** |
| `xhigh` | **+40** |
| `enable_thinking: true` 단독 | **+40** (= xhigh 와 동일) |
| `enable_thinking: true` + `medium` | **−2** (= medium 과 동일) |

🔴 **절대값을 믿지 말고 델타를 봐라.** 절대값은 시간이 지나며 이동했다
(23/21/51/63 → 13/11/41/53). 원인은 규명되지 않았지만 **델타는 비트 단위로 보존**됐다.
그래서 "medium 이면 11이어야 한다"는 틀린 기준이고, "미지정보다 2 적어야 한다"가 맞다.

🔴 **`medium` 의 −2 마진은 판정 기준으로 쓰기엔 너무 좁다.** 무관한 시스템 프롬프트
수정 한 번에 뒤집힌다. 설정 도달을 **증명**할 때는 `low`(+28)나 `xhigh`(+40)를 쓰고,
`medium` 은 배포용으로만 쓴다.

### 방법 C — litellm 이 거부하는지

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/v1/chat/completions \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer dummy' \
  -d '{"model":"flashnext","messages":[{"role":"user","content":"hi"}],
       "reasoning_effort":"medium","max_tokens":4}'
```

| 결과 | 의미 |
|---|---|
| `400` | litellm 이 막았다 — 별칭 접두사가 `openai/` 이기 때문 |
| `200` | 통과했다 — 단, **모델까지 갔다는 증거는 아니다.** 방법 B 로 확인하라 |

`enable_thinking` 은 같은 별칭에서 `200` 이 난다. **두 파라미터가 다르게 취급된다.**

---

## 자주 헷갈리는 것들

**Q. `enable_thinking: true` 와 `reasoning_effort: xhigh` 는 뭐가 다른가?**
토큰 수준에서 **완전히 같다** (둘 다 +40). VALIDATED.md 의 주장을 Phase 9 가 재측정해
확인했다.

**Q. 둘 다 넣으면?**
`reasoning_effort` 가 이긴다. `enable_thinking:true` + `medium` 은 `medium` 단독과
**토큰 단위로 동일**하다. 즉 effort 를 명시하면 `enable_thinking` 은 아무 변화도 만들지
않는다. (해롭지도 않아서 이중 안전장치로 함께 넣는다.)

**Q. 사고 내용이 다음 턴 컨텍스트에 쌓여서 32K 를 빨리 채우나?**
**아니다. 0 토큰이다.** 2,497자 트레이스를 되먹여도 필드를 통째로 뺀 것과 `prompt_tokens`
가 같다(46 고정, 16/16 측정). 서버가 그 필드를 토큰화 전에 버린다.
단, **Cline 자체는 사고를 컨텍스트에 다시 붙인다** — 통과하는 이유는 "안 붙여서"가 아니라
"붙여도 공짜라서"다.

**Q. Cline 의 Plan/Act 모드가 이 설정과 연동되나?**
**현재는 아니다.** 소스상 연결이 없다. `--plan` 은 명령 실행을 막을 뿐이고,
thinking 은 `--thinking` 플래그가 따로 관장한다. 그 둘을 잇는 것이 v1.1 의 목표다.

---

## 근거 문서

| 파일 | 내용 |
|---|---|
| `~/local-llm-settings/VALIDATED.md` §4 | 서버가 지원하는 값 (원 기록) |
| `phase-09/PRB-03-ORACLE.md` | 이 스택에서 재측정한 토큰 표, 델타 오라클 |
| `phase-09/PRB-04-FINDINGS.md` | 사고 트레이스 토큰 비용 0 측정 |
| `phase-09/GATE-VERDICT.md` | 게이트 판정과 반증 조건 |
| `docs/plan-act-reasoning-design.md` | Plan/Act ↔ effort 설계 |

재현용 스크립트는 `phase-09/probe_*.sh` / `probe_*.py` 에 있다. 전부 안전 외피
(`phase-09/probe_lib.sh`)를 거쳐 PID·설정 해시를 전후로 대조한다.
