# fast 모드 / deep 모드 만들기

> 🔴 **정정 (2026-09-10):** 이 문서는 Phase 9/10 중간에 작성되어 아래 "방법 2"(litellm 별칭)와
> "방법 3"(셸 래퍼)을 각각 Phase 10 "진행 중", Phase 11 "예정"으로 설명했다. **둘 다 그 뒤
> 배포됐다** — 별칭은 `flashnext-plan`/`flashnext-act`로(Phase 10), 래퍼는
> `phase-11/cline-plan`/`phase-11/cline-act` 스크립트로(Phase 11). 아래 본문을 현재 상태로
> 갱신했다.

**목표:** 빠르게 답하는 모드(사고 끔)와 깊게 답하는 모드(사고 켬, `medium`)를 골라 쓰기.

**짧은 답:** 된다. 다만 **어디서 전환하느냐**에 따라 지금 되는 것과 안 되는 것이 갈리고,
`fast`/`deep` 이라는 이름은 이 스택에서 이미 다른 뜻으로 쓰이고 있다.

---

## 🔴 먼저 — 이름이 이미 쓰이고 있다

litellm 설정 파일에 이렇게 적혀 있다:

```
# 🔴 fast/deep 모드는 서버 수준이지 별칭 수준이 아니다.
#   drafter 는 기동 시점에 묶이므로 별칭으로 전환할 수 없다.
#   현재 8000 은 drafter 를 붙인 fast mode 다.
```

여기서 **fast/deep 은 MTP drafter(추측 디코딩) 부착 여부**를 뜻한다. 사고와 무관하고,
서버 기동 시점에 고정되며, 별칭으로는 못 바꾼다.

즉 **축이 두 개다:**

|  | 사고 끔 | 사고 켬 (medium) |
|---|---|---|
| **drafter 붙음** ← 현재 서버 | 지금 기본 상태 | 지금 됨 — `flashnext-plan` (Phase 10 배포) |
| **drafter 없음** | 서버 재기동 필요 | 서버 재기동 필요 |

사고를 켜고 끄는 것을 `fast`/`deep` 이라 부르면, 나중에 누가 "deep 모드"를 보고
**drafter 를 뗀 서버**를 뜻하는지 **사고를 켠 별칭**을 뜻하는지 알 수 없게 된다.

### 권하는 이름

| 대신 | 이유 |
|---|---|
| `act` / `plan` | 이 마일스톤이 이미 쓰는 이름. Cline 의 Act/Plan 모드와 1:1 |
| `quick` / `think` | drafter 축과 헷갈릴 여지 없음 |
| `thinking-off` / `thinking-medium` | 가장 명시적. 이름이 곧 설정 |

아래에서는 **`act`(사고 끔) / `plan`(사고 켬, medium)** 으로 부른다.

---

## 지금 되는 것과 안 되는 것

🔴 **이 표가 핵심이다.** "사고 켬"까지는 어디서나 되지만, **"켬 + medium"** 은 경로를 탄다.

| 원하는 것 | `:8011` 직결 | `:4000` litellm (`flashnext`) | Cline |
|---|---|---|---|
| **act** — 사고 끔 | ✅ 아무것도 안 보냄 | ✅ 아무것도 안 보냄 | ✅ 지금 기본값 |
| 사고 켬, **xhigh** | ✅ `enable_thinking:true` | ✅ `enable_thinking:true` | ❌ 보낼 방법 없음 |
| **plan** — 켬 + **medium** | ✅ `reasoning_effort:medium` | ❌ **400** ¹ | ✅ `flashnext-plan` (배포됨) |

¹ 이 400 은 `flashnext` 별칭(`openai/` 접두사) 기준이다. `hosted_vllm/` 접두사 별칭
(`flashnext-plan`/`flashnext-act`)에 잘못된 `--thinking` 값을 보내면 litellm 의 400 이 아니라
**모델 서버의 500** 이 난다 — 접두사마다 다른 상태 코드다 (`phase-11/OPEN-ITEMS.md` Open Item 1).

### 왜 `:4000` 에서 "켬 + medium" 이 안 되나

두 파라미터를 litellm 이 **다르게 취급한다:**

```
enable_thinking   → 200 통과   (extra_body 로 그대로 전달)
reasoning_effort  → 400 거부   (openai/ 프로바이더의 지원 목록에 없다)
```

그런데 **`enable_thinking:true` 단독은 `xhigh`와 같다**(둘 다 +40 토큰, Phase 9 측정).
`medium` 으로 낮추려면 `reasoning_effort` 를 보내야 하는데 그게 막힌다.

**결과: `:4000` 을 통하면 사고는 켤 수 있어도 강도를 못 고른다. 항상 최대치다.**

해법은 별칭 접두사를 `hosted_vllm/` 로 바꾸는 것 — Phase 10 이 했다. 그 결과가
`flashnext-plan`/`flashnext-act` 별칭이다 (`phase-10/PHASE-10-FINDINGS.md`).

---

## 방법 1 — 요청마다 (지금 즉시, 설정 변경 없음)

`:8011` 직결이면 **오늘 당장 둘 다 된다.** 재기동도, 설정 변경도 필요 없다.

```bash
./howto/ask.sh --act  "파이썬 리스트 뒤집는 법"     # 사고 끔, 빠름
./howto/ask.sh --plan "이 설계의 위험은?"           # 사고 켬 medium
./howto/ask.sh --max  "어려운 추론 문제"            # 사고 켬 xhigh
```

직접 curl 로 하려면:

```bash
M=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4

# act — 사고 끔 (기본값이라 아무것도 안 보내면 된다)
curl -s http://localhost:8011/v1/chat/completions -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2\"}],\"max_tokens\":64}"

# plan — 사고 켬, medium
curl -s http://localhost:8011/v1/chat/completions -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2\"}],
       \"enable_thinking\":true,\"reasoning_effort\":\"medium\",\"max_tokens\":256}"
```

🔴 **`max_tokens` 를 넉넉히 줘라.** 사고가 완성 예산을 먼저 쓴다. Phase 9 에서 `xhigh` 에
`max_tokens:300` 을 줬더니 **사고가 예산을 다 써서 답 본문이 빈 채로** 끝났다
(`finish_reason: length`). 사고를 켤 거면 최소 512 이상을 권한다.

**장점:** 지금 된다. 아무것도 안 건드린다.
**단점:** 모든 클라이언트가 매번 보내야 한다. Cline 은 `:4000` 을 쓰므로 해당 없음.

---

## 방법 2 — litellm 별칭 (재기동 필요) ⭐ 배포됨

별칭에 파라미터를 심어두면 **모델 이름만 바꿔서** 모드를 고를 수 있다.
Cline 을 포함해 모든 클라이언트가 혜택을 본다.

```yaml
  - model_name: flashnext-plan
    litellm_params:
      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
      api_base: http://localhost:8011/v1
      api_key: dummy
      enable_thinking: true
      reasoning_effort: medium
```

🔴 **접두사가 `hosted_vllm/` 여야 한다.** `openai/` 로 두면 `reasoning_effort` 때문에
**모든 호출이 400** 이 난다. 설정에 심어도 마찬가지다 — litellm 은 설정값과 클라이언트
전송값을 **합친 뒤에** 검증한다.

확인:

```bash
grep -n reasoning_effort \
  ~/agent-stack/venv/lib/python3.12/site-packages/litellm/llms/hosted_vllm/chat/transformation.py
# 92:  params.extend(["reasoning_effort", "thinking"])
```

act 쪽은 **새 별칭이 필요 없다.** `enable_thinking` 의 기본값이 `false` 라
기존 `flashnext` 가 이미 act 모드다.

**적용하려면 litellm 재기동이 필요하다** — 핫리로드가 없다(`/config/reload` → 404).
재기동 동안 Kanban(`:3484`)과 Telegram 커넥터 요청이 끊긴다.

> **이건 Phase 10 이 했다.** 백업·롤백 리허설·검증 사다리를 갖춰서 유지보수 창 한 번에
> 처리했다. 결과: `phase-10/PHASE-10-FINDINGS.md`.

적용 후 사용:

```bash
cline -P openai-compatible -m flashnext-plan --json "..."   # plan (사고 medium)
cline -P openai-compatible -m flashnext      --json "..."   # act  (사고 없음)
```

`-m` 은 **호출마다** 모델을 고른다. `providers.json` 을 건드리지 않으므로
검증된 `contextWindow: 29000` 설정이 안전하다.

---

## 방법 3 — 셸 래퍼 (배포됨)

별칭이 생긴 뒤 다음 문제는 **모드와 별칭을 실수로 어긋나게 쓰는 것**을 막는 일이었다.
Phase 11 이 이를 **셸 함수가 아니라 실행 파일 스크립트**로 만들었다 — 셸 함수 형태
(`cline-plan() { ... "$@"; }`)는 `phase-11/WRAPPER-DESIGN.md` §2 가 기각했다:
`"$@"` 가 호출자의 `--thinking high` 나 두 번째 `-m` 을 그대로 통과시켜, 별칭이 주입한
설정을 조용히 덮어쓸 수 있기 때문이다.

```bash
./phase-11/cline-plan "..."   # 항상 -p -m flashnext-plan
./phase-11/cline-act  "..."   # 항상 act 별칭, -p 없음
```

래퍼는 화이트리스트에 없는 인자(예: `--thinking`, 두 번째 `-m`)를 조용히 무시하지 않고
**거부**한다. 불일치를 주입한 네거티브 테스트(`phase-11/wrapper_argv_test.sh`)로 검출을
확인했다. 동작 원리는 `qanda/003-how-the-wrappers-work.md`.

---

## 방법별 비교

| | 방법 1 요청마다 | 방법 2 별칭 | 방법 3 래퍼 |
|---|---|---|---|
| 지금 되나 | ✅ | ✅ | ✅ |
| 재기동 | 불필요 | **필요** | 불필요 |
| Cline 에서 | ❌ | ✅ | ✅ |
| 강도 선택 | ✅ | ✅ | ✅ |
| 실수 방지 | ❌ | ❌ | ✅ |

---

## 모드가 실제로 걸렸는지 확인

**응답만 보고 판단하지 마라.** 사고가 짧으면 `reasoning` 이 비어 보일 수 있다.
서버 로그의 `prompt_tokens` 로 역산하는 것이 확실하다.

```bash
./howto/check-thinking.sh
```

같은 요청에 설정만 바꿨을 때의 **델타**:

| 설정 | 델타 |
|---|---|
| 미지정 (act) | 기준 |
| `medium` (plan) | **−2** |
| `xhigh` / `enable_thinking:true` | **+40** |

🔴 **`medium` 의 −2 는 판정 근거로 쓰기엔 너무 좁다.** 무관한 프롬프트 수정 하나로
뒤집힌다. 도달을 **증명**할 땐 `xhigh`(+40)를 쓰고, 실사용은 `medium` 으로 한다.

🔴 **절대값이 아니라 델타를 봐라.** 절대값은 과거에 이동한 적이 있다.

---

## 자주 묻는 것

**Q. `enable_thinking:true` 만 넣으면 안 되나?**
된다. 다만 그건 **`xhigh`** 다 — 최대 강도. `medium` 을 원하면 `reasoning_effort` 를
같이 보내야 한다. 둘 다 넣으면 `reasoning_effort` 가 이긴다.

**Q. 사고를 켜면 컨텍스트가 빨리 차나?**
**아니다.** 되먹인 사고 트레이스는 `prompt_tokens` 를 전혀 늘리지 않는다
(2,497자 트레이스로 16/16 측정, 전부 `delta=0`). 서버가 토큰화 전에 버린다.
늘어나는 건 **응답 생성 시간과 완성 토큰**이지 프롬프트가 아니다.

**Q. `high` 는?**
없다. `xhigh` 다. `high` 를 보내면 500 이 난다.

**Q. drafter 를 떼면 더 깊게 생각하나?**
그 축은 사고와 무관하다. drafter 는 **속도** 최적화(추측 디코딩)다. 다만 떼면
`thinking_budget` 을 쓸 수 있게 되는데, 지금 구성에서는 500 이 난다.

---

## 근거

| 사실 | 출처 |
|---|---|
| `enable_thinking:true` == `xhigh` (둘 다 +40) | `phase-09/PRB-03-ORACLE.md` §2b |
| `et-medium` == `medium` (effort 가 이긴다) | 같은 곳 |
| `:4000` 에서 `enable_thinking:true` → 200, reasoning 30자 | `phase-09/results/20260901T014027Z-prb01-02/prb02.tsv` |
| `reasoning_effort` → 400 (openai/ 프로바이더) | `10-RESEARCH.md` Q1 |
| 사고 되먹임 토큰 비용 0 | `phase-09/PRB-04-FINDINGS.md` |
| `xhigh` 가 `max_tokens:300` 을 다 써서 본문이 빔 | `phase-09/PRB-03-ORACLE.md` §3 |
