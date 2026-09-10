# Plan/Act 모드와 `reasoning_effort` 연결 설계 (제안)

> **2026-09-10 정정.** 아래 상태 배지는 2026-09-01 작성 당시의 것이며 더 이상 유효하지
> 않다. v1.1 마일스톤이 이 설계를 **채택하고 구현했다** — 별칭은 Phase 10, 래퍼는 Phase 11
> 에서 출하됐고, §5 의 두 게이트 모두 판정이 끝났다. 무엇이 바뀌는지는 §9
> "이 정정이 바꾸는 것"을, 아직 열려 있는 항목은 §10 "미해결"을 볼 것. 정정 전 원문은 §11
> 부록에 그대로 보존한다.
>
> **상태: 채택됨 (v1.1).** §5 의 두 게이트 판정, 이 문서 자신의 게이트 기준으로:
> - **게이트 ① (컨텍스트 누적)**: kill 아님. Cline 은 사고 이력을 실제로 다음 턴에 다시
>   붙인다(구조적으로는 누적된다) — 그러나 이 스택에서 재생된 사고는 토큰 비용이 **0**이다
>   (16/16 판정 전부 `delta=0`, `prompt_tokens` 46 고정). 게이트가 통과한 이유는 "안
>   붙여서"가 아니라 **"붙여도 0 토큰이라서"**다. 근거: `phase-09/GATE-VERDICT.md` §4.2,
>   `phase-09/PRB-04-FINDINGS.md` §3.
> - **게이트 ② (A/B)**: 정확도 개선을 **찾지 못했다**. 동일 반복수로 비교 가능한
>   과제(01–06)에서 arm A 25/30, arm C 25/30 — 순열검정 p=0.563, 우연과 구별 불가.
>   사전 등록된 판정 규칙의 기계적 출력은 `revert` 였다. **사람이 이를 override 해
>   `keep` 으로 확정했다** — 개선이 증명돼서가 아니라, 규칙의 두 번째 근거였던
>   `providers.json` 오염 부작용이 그날 격리(commit `017c65e`)로 해소되어 더 이상 되돌릴
>   수밖에 없는 확실한 부작용이 아니게 됐기 때문이다. task 08 전체, arm B 전체, task 07 의
>   arm C 5회 중 4회는 시도되지 않았다(66/88 셀). 근거: `phase-11/AB-RESULTS.md` §8·§11.
>
> `~/local-llm-settings/config/litellm-config.yaml` 수정은 이미 끝났다(Phase 10) — 더
> 이상 "필요하다"가 아니라 "됐다."
>
> 작성 2026-09-01 · 정정 2026-09-10 · 근거는 이 문서 안에 실측 출처를 명시한다.
>
> **구현 계획: `docs/plan-act-reasoning-implementation.md`.**
> 그 계획은 이 문서의 L1(`allowed_openai_params` 통과)을 쓰지 않는다 — litellm 별칭이
> 파라미터를 주입하면 Cline 이 `--thinking` 을 보낼 필요가 없어 400 차단을 아예 만나지 않는다.

## 0. 요약

Cline 의 Plan/Act 모드와 Qwen3.8 Flash-Next 의 `reasoning_effort` 사이에는
**네이티브 연결점이 없다.** 연결하려면 바깥에서 묶어야 하고, 그 전에 litellm 이
`reasoning_effort` 를 차단하는 문제부터 풀어야 한다.

그리고 **하는 게 옳은지부터 재야 한다** — 모델은 thinking 을 끈 기본 상태에서 이미
coding 95.0% / reasoning 100% / agent 93.3% 다(`~/local-llm-settings/VALIDATED.md` §3).

## 1. 현재 상태 (실측·소스 확인, 2026-09-01)

### 1-1. Plan/Act 는 도구 가드이지 사고 설정이 아니다

`cline/cline` tag `cli-v3.0.53` 소스 확인. ※ 2026-09-10: `cline-src` 작업 트리는 이후
`cli-v3.0.61` 로 이동했다 — 아래 인용을 재확인하려면 워킹 트리를 그렙하지 말고
`git show cli-v3.0.53:<path>` 형태로 조회할 것(예:
`git show cli-v3.0.53:sdk/packages/core/src/extensions/tools/command-guard-extension.ts`),
`phase-12/SCOPE-DECISIONS.md` 항목 6.

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

> **2026-09-10 정정 — 위 400 은 별칭에 따라 다르다.** 위 문장은 `flashnext`(`openai/`
> 접두사, 무수정)를 통해 값을 **직접** 보낼 때만 참이다. Phase 10 이 만든
> `flashnext-plan`/`flashnext-act`/`flashnext-reach-xhigh` 는 `hosted_vllm/` 접두사라 값이
> litellm 을 **통과한다** — 그 대신 **모델 서버 자신이 거부해 HTTP 500** 이 난다
> (`phase-11/OPEN-ITEMS.md` Open Item 1, case 1a: `Unexpected reasoning effort high.
> Supported types are xhigh (default), medium, and low.`). 래퍼 없이 맨손 `cline --thinking
> high` 로 이 별칭을 실제로 호출하면, 이 500 이 Cline 자신의 NDJSON 오류 이벤트로 그대로
> 나타나며 **exit 1** 로 끝난다 — 사용자는 이 경로에서 400 을 보지 않는다(case 1c). 세
> 케이스(1a/1b/1c) 모두 `Generation queued` 로그를 남기지 않았다 — 값 검증이 생성 큐 진입보다
> 먼저 실패하기 때문에 실제 모델 생성 비용은 0이다.
>
> 이 문제 전체를 무의미하게 만드는 사실 하나가 더 있다: **Phase 11 의 래퍼는 `--thinking`
> 을 파싱 단계에서 거부한다.** 화이트리스트 방식(deny-by-default)이라 실제 바이너리를
> 호출하기도 전에 막는다(`phase-11/WRAPPER-DESIGN.md` §4) — 래퍼(`phase-11/cline-plan`/
> `cline-act`)를 쓰는 사용자는 400 도 500 도 만나지 않는다. 이것은 버전에 따라 반대
> 방향으로도 어긋나 있었다: 3.0.53 에서는 `--thinking` 자체가 CLI 에 없다고 믿었으나,
> 3.0.60+ 에서는 실제 플래그(`none|low|medium|high|xhigh`)이고, 클라이언트가 보낸 값이
> litellm 이 `litellm_params` 뒤에 클라이언트 kwargs 를 병합하기 때문에 별칭의 주입값을
> **덮어쓴다** — 바로 이것이 래퍼가 통과시키지 않고 거부해야 하는 이유다.

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

> **2026-09-10 정정 — 이 절의 셸 함수 스케치는 폐기됐다(superseded), 삭제가 아니다.** 원문은
> §11 부록에 그대로 보존돼 있다. 문제는 세 가지였다: `"$@"` 가 호출자의 `--thinking high`
> 나 두 번째 `-m` 을 그대로 통과시켜 이 메커니즘 전체를 무력화한다(호출자가 주입값을
> 덮어쓸 수 있다는 뜻); 셸 함수는 파일 경로가 없어 `verify_config.sh` 가 정적으로 검사할
> 수 없다; 테스트 하네스가 서브프로세스로 경로 호출할 수도 없다. 출하된 대체물은
> **`phase-11/cline-plan` / `phase-11/cline-act`**, 화이트리스트 방식(deny-by-default) 파서다.
> 상세: `phase-11/WRAPPER-DESIGN.md` §2·§3·§4.

`phase-01/config/verify_config.sh` 에 어서션 추가: plan 모드 호출에 `-m flashnext-plan` 이
붙어 있는지. 짝이 어긋난 상태를 검사로 잡는다. (이 어서션은 실제로
`phase-11/verify_wrappers.sh` 로 구현됐다 — `phase-11/WRAPPER-DESIGN.md` §8.)

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

## 9. 이 정정이 바꾸는 것

| 대상 | 이전 (2026-09-01) | 이후 (2026-09-10) |
| --- | --- | --- |
| 상태 배지 | 제안. 아직 구현되지 않음, v1 범위 밖 | 채택됨(v1.1) — 별칭 Phase 10, 래퍼 Phase 11 출하 |
| 게이트 ① 판정과 그 이유 | 미지수, "누적되면 폐기" | 통과 — 사고는 구조적으로 재첨부되지만(누적) 이 스택에서 토큰 비용이 0이라 무해. 통과 이유는 "안 붙여서"가 아니라 "붙여도 0 토큰이라서" |
| 게이트 ② 판정 | 미지수, "개선 없으면 중단" | 개선 없음(arm A 25/30 = arm C 25/30, p=0.563) — 그러나 `keep`. 사람이 사전 등록 규칙의 `revert` 출력을 override 했다. 이유는 개선 증명이 아니라 `providers.json` 오염 부작용의 격리(격리됨, 하루 미만) |
| §L3 셸 함수 스케치 | 현재 설계로 제시 | 폐기(superseded) — `phase-11/cline-plan`/`cline-act` deny-by-default 파서로 대체, 원문은 §11 부록에 보존 |
| `--thinking` 실패 모드 | "전부 400" (단일 수치) | 접두사별로 다르다: `openai/`(`flashnext`)=litellm 400, `hosted_vllm/`(`flashnext-plan` 등)=모델 서버 500, 맨손 `cline --thinking high`=exit 1. 래퍼는 파싱 단계에서 거부해 셋 다 만나지 않는다 |

## 10. 미해결

- **CFG-05 — 자동 업데이트를 막을 수 없다.** `CLINE_NO_AUTO_UPDATE=1` 이 듣지 않는다. 이
  마일스톤 동안 바이너리가 `3.0.53 → 3.0.60 → 3.0.61` 로 드리프트했고, 한 번은 `npm` 패키지
  자체가 실행 도중 디스크에서 완전히 사라진 채로 발견됐다(`phase-11/OPEN-ITEMS.md`
  "Unplanned finding").
- **실제 에이전트 워크로드에서 압축이 여전히 프루닝하지 않는다.** cline-bench 통과 0/4
  (`docs/32k-compaction-policy.md` §4a). 이 문서가 다루는 사고 주입과는 별개의 결함이지만,
  사고 트레이스가 실제로 누적되는 워크로드가 나타나면 같은 결함과 상호작용할 수 있다.
- **`--compaction basic` 은 미검증이다.** 근본 결함을 직접 겨냥할 유일한 후보였지만 올바른
  최상위 `contextWindow` 설정 위에서 한 번도 테스트된 적이 없다 — 별도의 라이브 실행 승인이
  필요하다.
- **`providers.json` 격리(containment)는 하루가 안 됐다.** commit `017c65e`, 검증은 오늘
  했지만 실사용 이력이 없다 — "고쳐졌다"가 아니라 **"2026-09-10 기준 격리됐다, 더 긴 노출을
  기다리는 중"**이다.

## 11. 부록 — 정정 전 기록

아래는 2026-09-01 작성 당시 이 문서가 실제로 적고 있던 원문이다. 삭제하지 않고 그대로
보존한다 — 결론(상태 배지, §L3 셸 함수 스케치)만 위 본문으로 대체됐다.

<details>
<summary>원문 펼치기</summary>

원래 상태 배지 (2026-09-01):

> **상태: 제안. 아직 구현되지 않았다.** v1 마일스톤 범위 밖이며, 채택 전에 §5 의 두 게이트를
> 반드시 통과해야 한다. `~/local-llm-settings/config/litellm-config.yaml` 수정이 필요하다.
>
> 작성 2026-09-01 · 근거는 이 문서 안에 실측 출처를 명시한다.

원래 §L3 셸 함수 스케치:

```bash
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }
cline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }
```

</details>
