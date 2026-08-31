# 구현 계획: Act = thinking off · Plan = `reasoning_effort: medium`

> **상태: 계획. 미착수.** 설계 근거는 `docs/plan-act-reasoning-design.md` 를 따른다.
> 작성 2026-09-01.
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

**소스 조사 결과 (2026-09-01, tag `cli-v3.0.53`):**
- `agentic-compaction.ts:88` 의 `reasoningChars` 는 **압축 요약기 자신의** reasoning 출력을
  세는 텔레메트리다. 요약문 `text` 만 반환되고 reasoning 은 버려진다. **누적의 증거가 아니다.**
- `toGatewayRequestMessages()` (`compat.ts:306`) 는 `message.content` 배열만 순회한다.
  `reasoning` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.
- `runtime-event-adapter.ts:290` 의 `reasoning: reasoning.reasoning` 은 이벤트 구성(표시용)이다.

**소스는 "누적되지 않는다" 쪽을 가리키나 결정적이지 않다.** 실측으로 확정한다:

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

```bash
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }
cline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }
```

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
