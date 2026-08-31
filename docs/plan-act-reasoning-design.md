# Plan/Act 모드와 `reasoning_effort` 연결 설계 (제안)

> **상태: 제안. 아직 구현되지 않았다.** v1 마일스톤 범위 밖이며, 채택 전에 §5 의 두 게이트를
> 반드시 통과해야 한다. `~/local-llm-settings/config/litellm-config.yaml` 수정이 필요하다.
>
> 작성 2026-09-01 · 근거는 이 문서 안에 실측 출처를 명시한다.

## 0. 요약

Cline 의 Plan/Act 모드와 Qwen3.8 Flash-Next 의 `reasoning_effort` 사이에는
**네이티브 연결점이 없다.** 연결하려면 바깥에서 묶어야 하고, 그 전에 litellm 이
`reasoning_effort` 를 차단하는 문제부터 풀어야 한다.

그리고 **하는 게 옳은지부터 재야 한다** — 모델은 thinking 을 끈 기본 상태에서 이미
coding 95.0% / reasoning 100% / agent 93.3% 다(`~/local-llm-settings/VALIDATED.md` §3).

## 1. 현재 상태 (실측·소스 확인, 2026-09-01)

### 1-1. Plan/Act 는 도구 가드이지 사고 설정이 아니다

`cline/cline` tag `cli-v3.0.53` 소스 확인:

```
--plan     → createPlanModeCommandGuardExtension
             (sdk/packages/core/src/extensions/tools/command-guard-extension.ts:39)
             → beforeTool 에서 context.tool.name !== RUN_COMMANDS 면 그냥 통과
             → reasoning 관련 필드를 일절 건드리지 않는다

--thinking → settings.reasoning.effort
             (provider-settings.ts:211 → 268 reasoningEffort)
             → wire: reasoning: { enabled, effort, budgetTokens }
             (compat.ts:429-438)
```

두 경로는 코드상 만나지 않는다.

### 1-2. CLI 에 모드별 프로바이더 오버라이드가 없다

`providers.json` 에 cline 이 `"modes": {}` 를 쓰지만, `provider-settings.ts` 스키마에
대응 정의가 없다. `modeOverride` / `perMode` / `getSettingsForMode` 류도 소스에 없다.
VS Code 확장의 모드별 모델 설정에 해당하는 기능이 CLI 3.0.53 에는 없다.

### 1-3. litellm 이 `reasoning_effort` 를 차단한다 🔴

층마다 결과가 다르다:

| 경로 | 값 | 결과 |
| --- | --- | --- |
| litellm `:4000` (Cline 이 쓰는 경로) | `low`·`medium`·`xhigh`·`high` **전부** | **HTTP 400** |
| role-shim `:8011` 직결 | `medium` | HTTP 200 ✅ |
| role-shim `:8011` 직결 | `high` | HTTP 500 (모델이 거부) |

```
litellm.UnsupportedParamsError: openai does not support parameters: ['reasoning_effort'],
for model=.../Qwen3.8-Flash-Next-MLX-oQ4.
To drop these, set `litellm.drop_params=True`
```

원인: `litellm-config.yaml` 에 `drop_params` 도 `allowed_openai_params` 도 없다.

즉 **`cline --thinking <아무 값>` 은 현재 400 으로 실패한다.** `high` 만의 문제가 아니다.

VALIDATED.md 가 기록한 `low`/`medium`/`xhigh` 정상, `high` → 500 은 **`:8000` 직결 기준**이며
그 문서가 명시하고 있다. litellm 계층은 당시 측정 대상이 아니었다. 두 기록은 모순되지 않는다.

### 1-4. 사고 길이를 제한할 수 없다

`thinking_budget` 은 drafter 가 붙은 현재 구성에서 500 을 낸다(VALIDATED.md §4).
따라서 사고 트레이스 길이에 상한을 걸 수단이 없다. 32K 구간 생성 속도가 약 17 tok/s 이므로
1,000 토큰 사고 = 약 60초 추가다.

## 2. 설계 — 세 층

```
L3 ergonomics   cline-plan / cline-act 래퍼        모드와 별칭의 짝을 강제
L2 binding      litellm 별칭 flashnext-plan/-act   파라미터를 모델 정체성에 묶는다
L1 unblock      allowed_openai_params              reasoning_effort 가 실제로 통과
```

### L1 — litellm 차단 해제 (필수 선행)

```yaml
# ~/local-llm-settings/config/litellm-config.yaml
- model_name: flashnext-plan
  litellm_params:
    model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
    api_base: http://localhost:8011/v1
    api_key: dummy
    allowed_openai_params: ['reasoning_effort']
    reasoning_effort: medium

- model_name: flashnext-act
  litellm_params:
    model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
    api_base: http://localhost:8011/v1
    api_key: dummy
    # reasoning_effort 없음 = 기본 false = 가장 빠름
```

🔴 **`drop_params: true` 를 쓰지 말 것.** 그것은 파라미터를 **조용히 버려서** 400 을 없앨 뿐이다.
요청은 200 을 받지만 아무 일도 일어나지 않는다. 이 프로젝트가 `models[].contextWindow` 와
`maxTokens` 로 두 번 당한 실패 모드와 동일하다.

### L2 — 별칭이 파라미터를 운반한다

파라미터를 **모델 정체성에 묶으면** 모델을 선택할 수 있는 모든 표면이 자동으로 따라온다 —
CLI, Kanban, Telegram 커넥터, 헤드리스 래퍼. 커넥터는 `mode: "act" | "plan"` 옵션을 갖고 있어
(`sdk/packages/shared/src/connectors/options.ts`) 표면별 지정도 가능하다.

```
flashnext        기존. 무변경. 회귀 판정용 기준선으로 남긴다
flashnext-plan   reasoning_effort: medium
flashnext-act    reasoning_effort 없음
```

### L3 — 래퍼가 짝을 강제한다

L2 만으로는 `cline -p -m flashnext-act` 같은 불일치가 가능하고, 아무도 알려주지 않는다.

```bash
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }
cline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }
```

`phase-01/config/verify_config.sh` 에 어서션 추가: plan 모드 호출에 `-m flashnext-plan` 이
붙어 있는지. 짝이 어긋난 상태를 검사로 잡는다.

## 3. 파라미터 도달을 증명하는 방법

**200 응답은 설정 적용의 증거가 아니다.** 이 프로젝트의 핵심 교훈이다.
다행히 서버 측 오라클이 있다 — `reasoning_effort` 는 시스템 프롬프트 길이를 바꾼다
(VALIDATED.md §4, 같은 질문의 `prompt_tokens` 로 역산):

```
미지정 / false   23 토큰
medium           21
low              51
xhigh            63
```

동일한 사용자 메시지로 effort 만 바꿔 보내고 `~/llm-system/services/logs/flashnext.err` 의
`prompt_tokens` 를 비교하면 도달이 증명된다.

```bash
for e in "" low xhigh; do
  curl -s localhost:4000/v1/chat/completions -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer dummy' \
    -d "{\"model\":\"flashnext\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4${e:+,\"reasoning_effort\":\"$e\"}}" >/dev/null
done
grep "Prefill started" ~/llm-system/services/logs/flashnext.err | tail -3
```

⚠️ **`medium`(21) 을 검증 프로브로 쓰지 말 것.** 미지정(23)과 2 토큰 차이라 판정이 취약하다.
`low`(51) 나 `xhigh`(63) 로 도달을 확인한 뒤, 운영값은 medium 으로 둔다.

## 4. 값 선택

| effort | 판단 |
| --- | --- |
| `xhigh` | `enable_thinking: true` 와 동일. 사고 길이 **무제한**(§1-4). 32K 구간에서 plan 한 턴이 수 분이 될 수 있다 |
| **`medium`** | **권장 시작점.** 사고는 하되 정도가 낮다 |
| `low` | 시스템 프롬프트가 오히려 길다(51). 이득 불명 |
| `high` | 🔴 **금지.** 모델이 500 으로 거부 (`:8011` 직결 실측). 래퍼가 차단하는 것이 좋다 |

## 5. 채택 전 게이트 — 두 미지수

### 게이트 ① 사고 트레이스가 다음 턴 컨텍스트로 돌아오는가

VALIDATED.md 는 *"클라이언트가 `content` 만 읽으면 두 경우 모두 정상 동작한다"* 고만 적는다.
Cline 이 `reasoning` 필드를 대화 이력에 **다시 넣는지는 확인된 바 없다.**

만약 넣는다면 — v1 이 실측한 **"실제 부하에서 압축이 프루닝하지 않는다"**
(`docs/32k-compaction-policy.md`) 와 결합해 치명적이다. 컨텍스트가 사고 트레이스만큼
더 빨리 자라는데 압축은 줄이지 못한다.

**측정:** thinking 을 켠 상태로 3턴 이상 돌리고 `prompt_tokens` 증가폭을 thinking 끈 실행과
비교한다. 증가폭이 유의하게 크면 **이 설계를 폐기한다.**

### 게이트 ② medium 이 실제로 결과를 개선하는가

기본 상태에서 이미 agent 93.3% 다. 개선이 측정 가능한 수준이 아니라면 지연만 늘리는
기능을 넣는 셈이다.

**측정:** 동일 과제로 `flashnext` vs `flashnext-plan` A/B. 개선이 없으면 여기서 중단한다.

## 6. 하지 말아야 할 것

**❌ role_shim 에서 프롬프트를 보고 모드를 추론하기.**
Cline 의 내부 시스템 프롬프트 문자열에 결합하는 설계다. cline 이 자동 업데이트되는 환경
(CFG-05 미해결, `CLINE_NO_AUTO_UPDATE=1` 이 듣지 않음)에서 조용히 깨진다.

**❌ Cline 포크.**
2026-08-30 에 `contextWindow` 문제로 검토했다가 설정으로 해결됐다. 여기도 litellm 별칭으로 충분하다.

**❌ `drop_params: true`.** §L1 참조.

## 7. 권고 순서

```
1. 게이트 ① 컨텍스트 누적 측정        ← "누적됨"이면 설계 폐기
2. L1 allowed_openai_params 적용
3. §3 오라클로 파라미터 도달 증명
4. 게이트 ② medium vs 기본 A/B        ← 개선 없으면 중단
5. L2 별칭 + L3 래퍼
6. verify_config.sh 에 짝 어서션 추가
7. docs/manual/01-cli.md 에 기록
```

**1번과 4번이 게이트다.** 둘 중 하나라도 부정적이면 그 지점에서 멈추는 것이 맞다 —
v1 이 "설정했다"와 "작동한다"를 구분하지 못해 이틀을 쓴 뒤 얻은 규칙이다.

## 8. 관련 문서

| | |
| --- | --- |
| 압축·컨텍스트 실측과 정정 이력 | `docs/32k-compaction-policy.md` |
| 모델 쪽 thinking 제약 (원 측정) | `~/local-llm-settings/VALIDATED.md` §4 |
| litellm 라우팅 | `~/local-llm-settings/config/litellm-config.yaml` |
| CLI 사용법 | `docs/manual/01-cli.md` |
| 버전 고정 (CFG-05 미해결) | `docs/cline-config-pins.md` |
