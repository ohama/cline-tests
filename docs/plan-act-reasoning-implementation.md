# 구현 계획: Act = thinking off · Plan = `reasoning_effort: medium`

> **2026-09-10 정정.** 이 계획은 **v1.1 에서 구현됐다** — 별칭(`flashnext-plan`/`flashnext-act`)은
> Phase 10, 래퍼(`phase-11/cline-plan`/`phase-11/cline-act`)는 Phase 11 이 만들었다.
> `cline-plan → flashnext-plan` 배포 결정은 **keep** 이며, §T6(Gate②) 사전 등록 규칙의 기계적
> 출력 `revert` 를 인간이 **override** 한 결과다(분류 `override-with-reason`,
> `phase-11/AB-RESULTS.md` §11). override 의 근거는 A/B 가 정확도 개선을 찾았기 때문이
> **아니다** — 두 arm 이 동등하게 시도된 구간(과제 01–06, N=5)에서 arm A 와 arm C 모두
> **25/30** 으로 정확히 같았고, 셀 단위 순열검정은 **p=0.563** 으로 우연과 구별되지 않았다
> (`phase-11/AB-RESULTS.md` §6·§11). override 의 실제 근거는 정확도와 무관하다 —
> `providers.json` 부작용이 commit `017c65e` 로 봉쇄 가능해졌다는 사실이다
> (`phase-11/WRAPPER-DESIGN.md`). 현재 유효한 본문은 아래 §1 부터이고, 이 정정으로 대체된
> 원문은 이 문서 끝 §9(정정 전 원문을 보존하는 부록)에 그대로 보존한다. "이 정정이 바꾸는
> 것"은 §7, 아직 닫히지 않은 항목은 §8 참조.
>
> 이 계획은 설계 문서의 3층 구조 중 **L1(차단 해제)을 쓰지 않는다.** 아래 §1 참조.

## 1. 설계 변경 — 통과(pass-through)가 아니라 주입(injection)

설계 문서는 `allowed_openai_params` 로 Cline 의 `--thinking` 을 통과시키는 안이었다.
확인 결과 **더 단순한 길이 있다.**

```
❌ pass-through   Cline --thinking medium → litellm(400 차단) → 해제 필요 → 모델
✅ injection      Cline (아무 플래그 없음) → litellm 별칭이 주입 → 모델
```

별칭이 `reasoning_effort` 를 실어 보내면:
- Cline 은 `--thinking` 을 **쓰지 않는다** → 400 차단 자체를 만나지 않는다
- `allowed_openai_params` 도, `drop_params` 도 불필요
- Cline 은 무수정. 자동 업데이트 드리프트(CFG-05)에 영향받지 않는다
- 모델을 고를 수 있는 **모든 표면**(CLI·Kanban·Telegram·헤드리스)이 자동으로 따라온다

**Cline 이 무엇을 보내는지 캡처할 필요도 사라진다** — 아무것도 안 보내니까.
v1 이 이미 `flashnext` 로 정상 동작하므로 Cline 의 기본 요청 형태는 검증된 상태다.

## 2. Act 모드는 만들 것이 없다 (아마도)

`enable_thinking` 의 기본값이 `false` 다(`VALIDATED.md` §4). 즉 **현재 act 동작이
이미 요구 사항을 만족한다.** v1 전체가 이 상태로 돌았고 agent 성공률 93.3% 다.

그럼에도 `flashnext-act` 별칭을 만들지는 **T1 결과로 결정한다**:

| T1 결과 | 결정 |
| --- | --- |
| `enable_thinking: false` 가 litellm 을 통과한다 | 별칭 생성. *"기본값은 버전 간 움직일 수 있지만 고정된 플래그는 아니다"* — 01-02 가 `--compaction agentic` 에 쓴 것과 같은 논리 |
| 통과하지 못한다 (Qwen 전용 파라미터라 litellm 이 거부) | **별칭 만들지 않는다.** 기존 `flashnext` 를 act 용으로 쓴다. 통하지 않는 설정을 넣어 두는 것이 더 나쁘다 |

## 3. 작업 순서

```
T1  모델 계층 확인          무위험 (:8011 직결, 소형 요청)
T2  Gate ① 컨텍스트 누적    ← kill condition
T3  litellm 별칭 + 재기동   ← 유지보수 창 필요
T4  도달 증명               prompt_tokens 오라클
T5  래퍼 + 어서션
T6  Gate ② A/B             ← 개선 없으면 중단
T7  문서
```

---

### T1 — 모델 계층 확인 (무위험)

`:8011` 직결. litellm 을 거치지 않으므로 별칭 없이도 가능하다.

```bash
M=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4

# 1-a. reasoning_effort: medium 이 실제로 reasoning 필드를 만드는가
curl -s localhost:8011/v1/chat/completions -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"2+2는?\"}],
       \"max_tokens\":64,\"reasoning_effort\":\"medium\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['choices'][0]['message']; \
      print('content  :', (d.get('content') or '')[:60]); \
      print('reasoning:', (d.get('reasoning') or 'None')[:60])"

# 1-b. enable_thinking: false 가 받아지는가 (act 별칭 생성 여부를 결정)
curl -s -o /dev/null -w "enable_thinking:false → HTTP %{http_code}\n" \
  localhost:8011/v1/chat/completions -H 'Content-Type: application/json' \
  -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],
       \"max_tokens\":8,\"enable_thinking\":false}"

# 1-c. effort 별 prompt_tokens 오라클 재확인 (T4 에서 쓸 판정 기준)
#   기대: 미지정 23 / medium 21 / low 51 / xhigh 63  (VALIDATED.md §4)
```

**판정:**
- 1-a 에서 `reasoning` 이 비어 있으면 → `medium` 은 사고를 켜지 않는다는 뜻.
  그렇다면 plan 모드에 medium 을 넣는 의미가 없다. **`xhigh` 재검토 또는 중단.**
- 1-c 에서 medium(21) 과 미지정(23) 차이가 2 토큰뿐임을 확인. **T4 프로브는 `low` 나 `xhigh` 로.**

🔴 **1-a 가 이 계획에서 가장 먼저 답해야 할 질문이다.** `medium` 의 시스템 프롬프트가
미지정보다 *짧다*(21 < 23)는 VALIDATED 의 기록은 직관과 어긋난다. 사고가 실제로 켜지는지
확인하지 않고 진행하면 아무 일도 안 하는 설정을 배포하게 된다.

---

### T2 — Gate ①: 사고 트레이스가 컨텍스트로 돌아오는가 (kill condition)

**왜 kill condition 인가.** v1 이 실측했다 — 실제 에이전트 부하에서 압축이 프루닝하지 않는다
(`docs/32k-compaction-policy.md`). 컨텍스트는 단조 증가한다. 여기에 사고 트레이스까지
누적되면 32K 천장에 **더 빨리** 부딪히고, 압축은 여전히 줄이지 못한다.

**소스 조사 결과 — 2026-09-10 정정 (원 조사는 2026-09-01, tag `cli-v3.0.53`).**

> **인용 형식 — 필수.** `/Users/ohama/projs/cline-src` 는 현재 `cli-v3.0.61` 로 체크아웃되어
> 있다. 아래 줄 번호는 전부 `cli-v3.0.53` 태그에서 읽은 것이고, 그 태그는 이제 작업 트리가
> 아니라 `git show cli-v3.0.53:<path>` 로만 접근된다. 예를 들어:
> ```bash
> (cd /Users/ohama/projs/cline-src && git show cli-v3.0.53:sdk/packages/llms/src/providers/ai-sdk.ts | sed -n '280,295p')
> ```
> 현재 체크아웃된 작업 트리를 그냥 grep 해서 못 찾는 것은 이 인용이 틀렸다는 뜻이 아니다 —
> qanda/004(`qanda/004-does-cline-always-write-providers-json.md`)의 "이전 판이 틀렸습니다"
> 정정이 바로 이 실수(작업 트리 이동을 모르고 "없다"고
> 결론)였다. 다섯 경로 전부 `git show cli-v3.0.53:<path>` 로 이번 세션에 재확인됐다
> (`phase-12/SCOPE-DECISIONS.md` 항목 6).

`phase-09/PRB-04-FINDINGS.md` §3 의 재조사 결과를 그대로 인용한다(재도출하지 않음):

- Cline 은 **Cerebras 가 아닌 provider 에 대해 기본적으로 reasoning 히스토리를 재부착한다.**
  `shouldIncludeReasoningHistory`(`sdk/packages/llms/src/providers/ai-sdk.ts:284-289`, 재확인:
  `git show cli-v3.0.53:sdk/packages/llms/src/providers/ai-sdk.ts`)는
  `isCerebrasProvider`(`sdk/packages/llms/src/providers/model-facts.ts:449`, 재확인:
  `git show cli-v3.0.53:sdk/packages/llms/src/providers/model-facts.ts`)를 호출해 판단한다.
  우리 provider(`openai-compatible`/`flashnext`)는 Cerebras 가 아니므로 기본값은 재부착이다.
- `agentPartToContentBlock` 의 `case "reasoning"` 분기(정의:
  `sdk/packages/core/src/runtime/config/agent-message-codec.ts:231`, 분기 자체는 `:237`, 재확인:
  `git show cli-v3.0.53:sdk/packages/core/src/runtime/config/agent-message-codec.ts`)는 들어온
  reasoning part 를 `ThinkingContent` 블록으로 변환해 **Task 의 `Message[]` 히스토리에
  영속화**한다 — 버려지지도, 표시용으로만 쓰이지도 않는다.
- `sdk/packages/core/src/session/services/message-builder.ts:1213-1214`(재확인:
  `git show cli-v3.0.53:sdk/packages/core/src/session/services/message-builder.ts`)는
  `block.type === "thinking"` 바이트를 대화 텍스트 예산에 그대로 합산한다 — Cline 자신의 회계상
  1급 시민 콘텐츠다.
- 원래 인용됐던 두 함수(`agentic-compaction.ts` 의 `reasoningChars`, `compat.ts` 의
  `toGatewayRequestMessages()`)는 **재부착 경로 위에 있지 않다** — 전자는 압축 요약기 자신의
  reasoning 출력을 세는 텔레메트리(다른 LLM 호출의 자기계측)고, 후자는 `message.content` 배열만
  순회해 이 경로를 보지 못한다. 신중한 소스 읽기가 왜 틀린 답을 냈는지가 정확히 여기다 —
  살펴본 함수 자체가 재부착과 무관한 함수였다.
- **두 주장을 반드시 분리해서 유지한다.** *아키텍처* 주장("Cline 은 reasoning 을 컨텍스트에서
  뺀다")은 **틀렸다.** *토큰비용* 주장("이 스택에서는 비용이 0이다")은 **맞았고, 영향받지
  않는다** — PRB-04 의 재생(replay) 행렬이 16/16 회 `delta=0`(`prompt_tokens` 고정값 46, 두
  엔드포인트 `:8011`/`:4000`, 두 필드명 `reasoning`/`reasoning_content`, 합성 1,380자 트레이스와
  실제 캡처된 2,497자 트레이스 양쪽 모두, 길이 임계 효과 없음)을 확인했다
  (`phase-09/PRB-04-FINDINGS.md` §1a·§1b). **게이트가 통과한 이유는 재생된 reasoning 이 토큰
  비용을 만들지 않기 때문이며, reasoning 이 빠져 있어서가 아니다.** 이 둘을 섞는 것이 바로
  이번에 바로잡는 오류다.

**소스는 누적된다 쪽을 가리킨다 — 다만 실측이 확정한 것은 토큰 비용이 0이라는 사실이다(아래).**

```bash
# 동일 프롬프트로 3턴, thinking on/off 두 번 실행하고 prompt_tokens 증가폭 비교
# on:  flashnext-plan 별칭 (T3 이후) 또는 :8011 직결 수동 다중 턴
# off: flashnext
grep "Prefill started" ~/llm-system/services/logs/flashnext.err | tail -6
```

**판정:**
- 증가폭이 유의하게 크다 → **이 계획을 폐기한다.** plan 모드에 사고를 넣는 것 자체가
  32K 스택에서 위험하다는 뜻이다
- 차이가 없다 → 진행

---

### T3 — litellm 별칭 추가 + 재기동 (유지보수 창 필요)

🔴 **제약:** litellm 1.86.1 에 설정 핫리로드가 없다(`/config/reload` → 404, 2026-09-01 확인).
설정 변경에는 **litellm 재기동이 필요하다.**

**영향 범위:**
- `com.ohama.litellm` 재기동 — 모델은 재적재되지 않으므로 수 초 수준
- 재기동 중 `com.ohama.kanban`, `kanban-proxy`, `telegram-connect` 의 요청이 실패한다
- `com.ohama.flashnext` 는 **건드리지 않는다** (104 GiB 재적재 회피)

**선행 조건:** 진행 중인 작업이 없어야 한다.

```bash
# 정지성 확인 — cline/kanban 을 호출하지 않는 읽기 전용 검사
pgrep -fl 'bin/\.cline|bin/cline'
tail -2 ~/llm-system/services/logs/flashnext.err   # Prefill/Decode 진행 중인지
```

**설정 (`~/local-llm-settings/config/litellm-config.yaml`):**

```yaml
  # ── Plan 모드 전용 ─────────────────────────────────────────────────────
  # Cline 은 --thinking 을 쓰지 않는다. 별칭이 reasoning_effort 를 주입한다.
  - model_name: flashnext-plan
    litellm_params:
      model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
      api_base: http://localhost:8011/v1
      api_key: dummy
      reasoning_effort: medium

  # ── Act 모드 전용 (T1-b 가 통과를 확인한 경우에만) ────────────────────
  - model_name: flashnext-act
    litellm_params:
      model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
      api_base: http://localhost:8011/v1
      api_key: dummy
      enable_thinking: false
```

`flashnext` 는 **손대지 않는다.** 회귀 판정의 기준선이다.

🔴 `drop_params: true` 를 넣지 말 것. 파라미터를 조용히 버려 200 을 만든다 —
`models[].contextWindow` 와 `maxTokens` 로 두 번 당한 실패 모드다.

**변경 후:** `~/local-llm-settings/sync.sh` 를 돌려 STATE.md 를 갱신한다.

---

### T4 — 파라미터 도달 증명

**200 응답은 적용의 증거가 아니다.** 서버 측 오라클로 증명한다.

```bash
# 동일 사용자 메시지, 별칭만 바꿔 보내고 prompt_tokens 를 비교
for m in flashnext flashnext-plan; do
  curl -s localhost:4000/v1/chat/completions -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer dummy' \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4}" >/dev/null
done
grep "Prefill started" ~/llm-system/services/logs/flashnext.err | tail -2
```

**판정:** 두 요청의 `prompt_tokens` 가 **달라야** 한다. 같으면 주입이 안 된 것이다.

⚠️ medium(21) vs 미지정(23) 은 2 토큰 차이다. 판정이 취약하면 임시로 `xhigh`(63) 별칭을
만들어 도달을 확인한 뒤 medium 으로 되돌린다.

---

### T5 — 래퍼와 어서션

별칭만으로는 `cline -p -m flashnext-act` 같은 불일치를 막지 못한다.

> **[superseded, 2026-09-10]** 아래는 최초 스케치였던 셸 함수 정의였다 — 원문은 이 문서 끝
> §9(정정 전 원문을 보존하는 부록)에 보존한다. **superseded, 단순히 낡은 것이 아니다:**
> `phase-11/WRAPPER-DESIGN.md` §2 가 이 정확한 스케치를 이름으로 지목해 안전하지 않다고
> 증명한다 — `"$@"` 가 호출자의 `--thinking high` 나 두 번째 `-m` 을 실제 바이너리로 그대로
> 전달하고, litellm 은 클라이언트 kwargs 를 `litellm_params` **뒤에** 병합하므로 호출자가
> 별칭의 주입을 조용히 이긴다 — 이것이 바로 Phase 11 `MUTANT-LEAKY` 테스트가 잡아내는 그
> 누출이고, 배포된 래퍼의 deny-by-default 파서가 막으려는 것이다. 셸 함수는 파일 경로가 없어
> `verify_config.sh` 가 정적으로 검사할 수도, 테스트 하네스가 서브프로세스로 실행할 수도
> 없다. 실제로 배포된 것은 `phase-11/WRAPPER-DESIGN.md` §2·§3·§4 의 계약을 따르는 실제
> 스크립트(`phase-11/cline-plan` / `phase-11/cline-act`, deny-by-default 파서)다.

`phase-01/config/verify_config.sh` 에 추가:
- 래퍼 정의에 plan↔plan, act↔act 짝이 유지되는지
- `--thinking high` 가 어디에도 없는지 (모델이 500 으로 거부)

**범위:** CLI 만. Kanban 은 카드별 모델 선택 수단이 없고, Telegram 커넥터는
`mode: "act"|"plan"` 옵션이 있으나(`shared/src/connectors/options.ts`) 별도 검토 대상이다.

---

### T6 — Gate ②: medium 이 실제로 개선하는가

기본 상태에서 이미 coding 95.0% / reasoning 100% / agent 93.3% 다.
개선이 측정 가능한 수준이 아니라면 지연만 늘리는 기능이다.

동일 과제를 `flashnext` 와 `flashnext-plan` 으로 각각 돌려 결과와 소요 시간을 비교한다.
**개선이 없으면 별칭을 남기되 래퍼 기본값을 `flashnext` 로 되돌린다.**

---

### T7 — 문서

- `docs/manual/01-cli.md` — `cline-plan` / `cline-act` 사용법
- `docs/plan-act-reasoning-design.md` — 설계 문서에 "구현됨" 표시와 실측 결과 반영
- `docs/cline-config-pins.md` — 별칭과 그 파라미터를 고정값 목록에 추가
- 🔴 `--thinking` 은 여전히 400 이라는 사실을 명시. 별칭이 대안이라는 것도

## 4. 위험과 완화

| 위험 | 완화 |
| --- | --- |
| litellm 재기동이 Kanban/Telegram 요청을 끊는다 | 정지성 확인 후 진행. 모델은 재적재되지 않아 수 초 |
| `enable_thinking` 이 litellm 을 통과 못 한다 | T1-b 가 먼저 답한다. 통과 못 하면 act 별칭을 만들지 않는다 |
| `medium` 이 사고를 켜지 않는다 | T1-a 가 먼저 답한다. `reasoning` 필드가 비면 중단 |
| 사고 트레이스가 컨텍스트에 누적된다 | T2 가 kill condition |
| 개선이 없는데 지연만 는다 | T6 이 판정. 래퍼 기본값 되돌림 |
| 모드/별칭 불일치 | T5 어서션 |
| cline 자동 업데이트 (CFG-05) | 이 계획은 Cline 을 수정하지 않으므로 영향 없음 |

## 5. 착수 조건

- [ ] 모델이 유휴 상태 (진행 중인 Prefill/Decode 없음)
- [ ] `~/local-llm-settings` 수정 승인 — v1 에서 이 디렉터리는 읽기 전용으로 취급했다
- [ ] litellm 재기동 승인 — 가동 중인 Kanban/Telegram 요청이 끊긴다

## 6. 중단 지점 요약

```
T1-a  reasoning 필드가 비어 있음     → medium 은 사고를 안 켠다. 중단 또는 xhigh 재검토
T2    사고 트레이스 누적 확인         → 계획 폐기
T4    prompt_tokens 차이 없음        → 주입 실패. T3 재검토
T6    개선 없음                      → 별칭 유지, 래퍼 기본값 되돌림
```

**T1-a 와 T2 는 T3(설정 변경) 이전에 끝난다.** 무위험 구간에서 답이 나오므로,
스택을 건드리기 전에 계획 폐기 여부가 결정된다.

## 7. 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| 상태 배지 | 계획, 미착수 | 구현됨(v1.1) — 배포 결정 keep(override), `phase-11/AB-RESULTS.md` §11 |
| §T2 소스 인용 | 소스 판독이 "누적 안 됨"을 시사한다고 결론 | 소스는 누적됨을 확인(`shouldIncludeReasoningHistory`); 그 위에서 토큰비용은 실측 0 |
| §T5 래퍼 스케치 | 셸 함수로 `"$@"` 를 그대로 전달하는 스케치 | 실제 스크립트(`phase-11/cline-plan`/`phase-11/cline-act`), deny-by-default 파서 — 셸 함수는 superseded |
| Gate① 판정과 이유 | 미판정(계획 단계) | 통과 — "누적이 없어서"가 아니라 "재부착돼도 토큰비용이 0이라서" |
| Gate② A/B 결과 | 미실행(계획 단계) | 실행됨(66/88 셀) — 개선 없음(동등 구간 25/30 대 25/30, p=0.563); keep 은 인간의 override, 근거는 `providers.json` 부작용 봉쇄(정확도와 무관) |

## 8. 여전히 미해결

- **CFG-05 — `CLINE_NO_AUTO_UPDATE=1` 은 cline 자동 업데이트를 막지 못한다.** 바이너리는
  Phase 10–11 동안 3.0.53 → 3.0.60 → 3.0.61 로 드리프트했고, 한 번은 실행 중간에 디스크에서
  **완전히 사라진 채** 발견됐다(`phase-11/OPEN-ITEMS.md`). 이 문서의 버전 의존적 주장은 전부
  잠정적이다.
- **실제 워크로드에서는 압축이 여전히 프루닝하지 않는다.** cline-bench 는 4번 시도 중 0번
  통과했고, 그중 3번이 `fail-context` 였다. reasoning 과는 무관한 결함이지만, A/B(§T6)가
  cline-bench 를 쓸 수 없었던 이유가 바로 이것이다.
- **`--compaction basic` 은 올바른 최상위 `contextWindow` 설정 위에서 여전히 한 번도
  테스트되지 않았다.**
- **봉쇄(containment)는 하루치 기록밖에 없다.** commit `017c65e`, 오늘(2026-09-10), 실
  운영 기록 없음. "고쳤다"/"해결됐다"라고 쓰지 않는다 — **2026-09-10 기준 봉쇄됨, 장기 노출
  대기 중**이라고 쓴다.
- **설명되지 않은 채로 남겨 둔 모순.** Phase 10 의 VRF-04 는 cline 3.0.60 에서, 소스가
  3.0.53/3.0.61 과 바이트 단위로 동일한데도 `model` 이 변하지 않는 것을 관측했다. Phase 11 은
  3.0.61 에서 같은 호출 패턴이 31/31 회 변경되는 것을 관측했다. `phase-11/PHASE-11-FINDINGS.md`
  §5.8 의 솔직한 결론은 Phase 10 의 단일 관측이 이상치(outlier)일 가능성이 더 높다는
  것이며 — **메커니즘은 제안되지 않았다.** 그렇게만 기록한다. 메커니즘을 지어내지 않는다.

## 9. 부록 — 정정 전 기록

아래는 위 정정으로 대체되기 전, 이 문서가 실제로 담고 있던 원문이다. 측정값의 오류가 아니라
**소스 판독의 거짓 음성(false negative)이 어떤 모습이었는지, 그리고 그런 판독에도 불구하고
게이트가 왜 그래도 통과했는지**의 증거로 원문 그대로 보존한다. 결론 문장만 위 §1·§7·§8 로
대체됐다.

<details>
<summary>원문 펼치기</summary>

원래 상태 배지 (문서 최상단, 2026-09-01 작성):

```
> **상태: 계획. 미착수.** 설계 근거는 `docs/plan-act-reasoning-design.md` 를 따른다.
> 작성 2026-09-01.
```

원래 §T2 "소스 조사 결과 (2026-09-01, tag `cli-v3.0.53`)":

```
- `agentic-compaction.ts:88` 의 `reasoningChars` 는 **압축 요약기 자신의** reasoning 출력을
  세는 텔레메트리다. 요약문 `text` 만 반환되고 reasoning 은 버려진다. **누적의 증거가 아니다.**
- `toGatewayRequestMessages()` (`compat.ts:306`) 는 `message.content` 배열만 순회한다.
  `reasoning` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.
- `runtime-event-adapter.ts:290` 의 `reasoning: reasoning.reasoning` 은 이벤트 구성(표시용)이다.
```

원래 전환 문장:

```
**소스는 "누적되지 않는다" 쪽을 가리키나 결정적이지 않다.** 실측으로 확정한다:
```

원래 §T5 래퍼 스케치:

```sh
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }
cline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }
```

</details>
