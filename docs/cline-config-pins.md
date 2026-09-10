# Cline 설정 고정 (Phase 1: CFG-04·CFG-05·CFG-06 / v1.1: CFG-11..17)

이 문서는 Phase 1 이 고정한 네 가지 값 — `cline` 버전, `kanban` 버전, 압축(compaction) 모드,
모델 — 의 근거와 증거를 기록한다. 나중에 뭔가 어긋났을 때 제일 먼저 볼 문서다.

**2026-09-10 추가.** §7 은 v1.1(Phase 10/11)이 `flashnext` 위에 추가·삭제한 별칭 고정을 같은
형식으로 기록한다. §1–§6 은 Phase 1 문서 원문 그대로이며, 아래 §7 은 새 내용의 순수 추가다 —
기존 문장을 정정하는 것이 아니므로 이 파일 전체에 정정-전 기록 부록은 없다.

정본은 코드다: `phase-01/config/cline-invocation.env` (값 정의) 와
`phase-01/config/check_versions.sh` (드리프트 검증). 이 문서는 그 값들이 **왜** 그 값인지의
기록이다.

## 1. 무엇을 고정했는가

| 고정 | 값 | 요구사항 | 증거 명령 |
| --- | --- | --- | --- |
| `cline` 버전 | `3.0.53` | CFG-05 | `CLINE_NO_AUTO_UPDATE=1 cline --version` |
| `kanban` 버전 | `0.1.70` | CFG-06 | `CLINE_NO_AUTO_UPDATE=1 kanban --version` |
| 압축 모드 | `agentic` | CFG-04 | `--compaction agentic` — `CLINE_COMMON_FLAGS` 안에 항상 포함 |
| 모델 | `flashnext` | CFG-07 | `-m flashnext` — `flashnext-codex` alias 는 이 프로젝트의 어떤 호출에서도 도달 불가 |

네 값 모두 `phase-01/config/cline-invocation.env` 에서 export 되며, `phase-01/` 아래 모든
스크립트와 Phase 5 의 모든 launchd plist 가 이 파일 하나를 source 해서 값을 가져간다.

## 2. 검증된 CLI 플래그 표면 (3.0.53)

설치된 `cline@3.0.53` 바이너리에서 `CLINE_NO_AUTO_UPDATE=1 cline --help` 를 직접 실행해 얻은
실제 출력이다 (2026-08-29 실측):

```
  -c, --cwd <path>              Working directory
  --compaction <mode>           Context compaction mode: agentic|basic|off
                                (default: agentic)
  --auto-approve <boolean>      Set tool auto-approval for all tools (default:
                                true)
  -m, --model <model-id>        Model to use for the session with the selected
                                provider
  -P, --provider <id>           Provider id (default: cline)
  -t, --timeout <seconds>       Optional timeout in seconds (default: 0 for no
                                timeout)
  --id <session-id>             Resume an existing session by ID
  --config <path>               Configuration directory (default: ~/.cline)
  --data-dir <path>             Use isolated local state at this directory path
                                (default: ~/.cline/data)
```

이 출력에서 두 가지 결론이 직접 도출된다:

**(a) `--compaction agentic` 와 `--auto-approve true` 는 이제 "확인된 기본값"이지, 가정이 아니다.**
(`--compaction` default: agentic, `--auto-approve` default: true — 위 `--help` 출력에서 확인.)
그래도 두 플래그를 매 호출마다 명시적으로 넘긴다 — 기본값은 다음 버전에서 조용히 바뀔 수 있지만,
명시적으로 고정한 플래그는 바뀌지 않는다. `phase-01/config/cline-invocation.env` 의
`CLINE_COMMON_FLAGS` 가 이 두 값을 실제로 담아 내보내는 문자열이다:
```
CLINE_COMMON_FLAGS="-P openai-compatible -m flashnext --compaction agentic"
```

**(b) `-c` 는 config 격리가 아니라 작업 디렉터리(Working directory)다.** config 격리는
`--config <path>` (기본값 `~/.cline`) 와 `--data-dir <path>` (기본값 `~/.cline/data`) 가 담당한다.
Phase 1 은 이 두 플래그를 **의도적으로 절대 넘기지 않는다** — 이 페이즈 전체의 주장이 "진짜
`~/.cline/data/settings/providers.json` 이 실제로 적용되는가"이기 때문에, config 를 격리하면
검증 자체가 무의미해진다. `-c/--cwd` 는 `run_regression.sh` 가 실행마다 재현성을 위해 별도로
설정하는, 완전히 다른 축의 플래그다.

## 3. CFG-04 재정의 기록

원래 CFG-04 는 "Compact Prompt 켜짐"을 검증하는 요구사항이었다. Phase 1 연구 단계에서 이
설정 자체가 CLI 에 **존재하지 않음**을 확인했다:

- 설치된 87 MB Bun 컴파일 바이너리(`/opt/homebrew/lib/node_modules/cline/bin/.cline`) 전체를
  `strings` 로 훑어 `compactPrompt`, `"Compact Prompt"`, `focusChain` 문자열을 검색 — **0건**.
  유일하게 나온 `compactPrompt` 문자열은 무관한 `@ai-sdk/google` 의존성 소속이었다.
- CLI 의 TUI 설정 메뉴는 바이너리 안에 리터럴 토글 목록으로 존재하며, 정확히 네 개뿐이다:
  `Compaction`, `Auto-approve all`, `Auto update`, `Verbose`. 다섯 번째 토글은 없다.
- 공개 문서가 말하는 "Use Compact Prompt"는 "Cline Settings → Features" 에 있다고 하는데,
  이는 VS Code 확장의 설정 화면이지 CLI 의 기능이 아니다. 이 프로젝트는 CLI(`cline kanban`,
  `cline connect telegram`, 헤드리스 래퍼) 만 쓰므로 VS Code 확장은 애초에 로드되지 않는다.

**따라서 CFG-04 는 다음과 같이 재정의되어 만족된다: "Compact Prompt" 토글이 아니라
`--compaction agentic` 명시 고정으로 압축 메커니즘을 켠다.** 디컴파일된 기본 파서가 이를
뒷받침한다 (변수명은 minifier 가 붙인 것, 로직은 그대로):

```js
// commander.js option handler for --compaction <mode>:
function parseCompactionFlag(value) {
  if (value === undefined) return { enabled: true };        // 플래그 없어도 기본 활성화
  if (value === "off")     return { enabled: false };
  return { enabled: true, strategy: value };                 // "agentic" | "basic"
}
```

## 4. Phase 5 가 복사해야 할 plist 조각

launchd 로 `cline`/`kanban` 을 띄우는 모든 plist 는 `EnvironmentVariables` 에 다음을 포함해야
한다:

```xml
<key>EnvironmentVariables</key>
<dict>
  <key>CLINE_NO_AUTO_UPDATE</key>
  <string>1</string>
</dict>
```

`phase-01/config/check_versions.sh` 의 Check C 가 `~/Library/LaunchAgents/*.plist` 를 스캔해서
`cline`/`kanban` 을 호출하는 plist 중 이 변수가 없는 것을 찾으면 FAIL 로 실패시킨다. 오늘은
이 스캔이 **공허하게 통과(vacuous pass)** 한다 — 실제 `~/Library/LaunchAgents/` 에 아직
cline/kanban plist 가 하나도 없기 때문이다 (2026-08-29 확인). Phase 5 가 plist 를 만드는 순간
이 검사가 실제로 작동하기 시작한다.

## 5. 드리프트가 나면 무엇이 무효가 되는가

압축 트리거 상수(**2026-08-30 정정**: `maxInputTokens × 0.9 = 26,100`, 최상위 `settings.contextWindow=29000` 기준. `×0.9×0.9` 는 `maxInputTokens` 부재 시 폴백), NDJSON 의 `notice` 이벤트 모양, 그리고
overflow-recovery 정규식 목록은 전부 **정확히 `cline@3.0.53` 바이너리를 디컴파일해서** 얻은
것이다. `cline --version` 이 3.0.53 이 아닌 다른 값을 보고하는 순간, 이 페이즈의 판정
(compaction 이 뜨는가/안 뜨는가) 은 재실행 전까지 신뢰할 수 없다 — 위 상수들이 새 버전에서도
같은 값이라는 보장이 없다.

## 6. `check_versions.sh` 실측 출력 (2026-08-29)

```
--- Check A: version pins (CFG-05, CFG-06) ---
OK: cline --version reports pinned 3.0.53
OK: kanban --version reports pinned 0.1.70
OK: cline npm package.json version matches pinned 3.0.53
OK: kanban npm package.json version matches pinned 0.1.70
--- Check B: no drift across invocations (the actual CFG-05 claim) ---
OK: cline --version still reports 3.0.53 after an intervening 'cline config --json' invocation
OK: kanban --version still reports 0.1.70 on a second invocation
--- Check C: plist EnvironmentVariables (CFG-05 for launchd surfaces) ---
OK: no cline/kanban launchd plists exist yet (Phase 5 creates them) — this check is armed for reuse
---
check_versions: PASS
```

Check C 의 스캐너는 fixture plist 로도 검증됨: `CLINE_NO_AUTO_UPDATE` 가 없는 fixture 는
FAIL + exit 1, 있는 fixture 는 PASS + exit 0 (실제 `~/Library/LaunchAgents/` 는 건드리지 않고
`LAUNCHAGENTS_DIR` 환경변수로 스캔 대상 디렉터리를 바꿔서 테스트).

## 7. v1.1 별칭 고정 (CFG-11..17)

Phase 10 이 litellm 설정(`~/local-llm-settings/config/litellm-config.yaml`)에 세 개의 별칭을
추가하고 여섯 개를 삭제했다. Phase 1 의 §1 표가 고정한 네 값(모델은 `flashnext` 그 자체)은
전혀 바뀌지 않았다 — 여기서 고정하는 것은 그 위에 얹힌 새 표면이다.

### 7.1 살아있는 다섯 개 별칭

읽기 전용으로 이 세션에 재확인한 실제 목록(`grep -c 'model_name: flashnext'
~/local-llm-settings/config/litellm-config.yaml` → 5, 아래 표의 순서와 정확히 일치):
`flashnext`, `flashnext-codex`, `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`.

| 별칭 | prefix | 주입 파라미터 | 상태 | 요구사항 |
| --- | --- | --- | --- | --- |
| `flashnext` | `openai/` | 없음 (control) | v1.1 로 변경 없음, 바이트 동일 | CFG-13 |
| `flashnext-codex` | `openai/` | 없음 | 변경 없음, **호출 금지 — 모델 서버가 죽는다** | — |
| `flashnext-plan` | `hosted_vllm/` | `enable_thinking:true` + `reasoning_effort:medium` | 출하된 Plan 모드 기본값 | CFG-11 |
| `flashnext-act` | `hosted_vllm/` | `enable_thinking:false` | 출하된 Act 모드 기본값 | CFG-12 |
| `flashnext-reach-xhigh` | `hosted_vllm/` | `reasoning_effort:xhigh` | **검증 전용, 사용 표면 아님** — §7.3 | — |

증거: `phase-10/ALIAS-DESIGN.md` §1–§2, `phase-10/CFG-13-EVIDENCE.md` Checks 1–4,
`phase-10/PHASE-10-FINDINGS.md` §1–§2.

**왜 새 별칭 세 개는 `openai/` 가 아니라 `hosted_vllm/` 인가.** `openai/` prefix 로
`reasoning_effort` 를 보내면 litellm 자체의 파라미터 검증(`UnsupportedParamsError`)이 게이트웨이를
떠나기도 전에 요청을 거부한다 — **HTTP 400**. 이 prefix 를 바꾸는 것은 새 별칭을 만드는
구현 디테일이 아니라, 그 자체로 이 400 문제를 다시 여는 행위다. 그래서 이 문서는 prefix 를
`고정`으로 취급한다 (§7.6). 자세한 메커니즘은 `phase-10/ALIAS-DESIGN.md` §3.

### 7.2 삭제된 여섯 개 `qwen-*` 별칭 (CFG-17)

`qwen-local`, `qwen-35b`, `qwen-122b`, `qwen-122b-claude`, `qwen-35b-claude`, `qwen-122b-codex` —
이 여섯은 CFG-17 에 따라 설정에서 완전히 삭제되었다. **역사적 존재이며 더 이상 도달 불가능**이다.
과거 문서가 이 이름들을 언급하는 것을 보게 되면, 오설정이 아니라 이 삭제 때문임을 알 수 있도록
여기 기록한다. 삭제 근거와 안전장치(`flashnext`/`flashnext-codex` 바이트 동일성 보존)는
`phase-10/ALIAS-DESIGN.md` §2.

### 7.3 `flashnext-reach-xhigh` — 결정 완료, 세 번째로 미루지 않음

이 별칭은 **검증 전용이며 사용 표면이 아니다.** `phase-12/SCOPE-DECISIONS.md` 3번 항목의 결정:
**남긴다.** 제거하려면 litellm 재시작이 한 번 더 필요하고, 그 재시작은 Kanban/Telegram 서비스의
또 한 번의 중단을 의미한다 — 남겨 두는 데는 비용이 없다. **v1.2 제거 후보**로 기록한다. 이
항목은 이미 두 번 다음으로 미뤄졌다(`phase-10/PHASE-10-FINDINGS.md` §5, 그리고
`flashnext-plan`/`flashnext-act` 의 keep-or-revert 판단을 다룬 Phase 11 결과 문서의 해당 절) —
**지금 결정되었고, 세 번째로 다음 페이즈에 넘기지 않는다.**

**이 별칭이 지고 있는 증명은 다르다 — 반드시 밝혀야 하는 마진 차이.** reach 는 **넓은 마진으로
증명되었다 — `flashnext-reach-xhigh` 에서, +40**, 그런데 이 별칭은 한 번도 출하된 적이 없다
(`phase-10/PHASE-10-FINDINGS.md` §4.1, `phase-11/PHASE-11-FINDINGS.md` §5.4). 실제로 출하된
`flashnext-plan` 자신의 마진은 **−2** 다 — 명시적으로, 더 약하고 보강적인 증명이다. 이것을
"출하된 별칭의 reach 가 넓은 마진으로 증명됐다"로 뭉뚱그리면 안 된다 — 그렇지 않았다. 두 델타
숫자(그리고 그 둘의 관계)의 원천 기록은 `phase-10/REACH-PROOF.md` §3 — 같은 표를 여기서 세 번째로
베끼지 않는다. `howto/thinking-and-reasoning-effort.md` 와 `howto/fast-and-deep-mode.md` 도 같은
숫자를 자체-검증(self-service verification)이라는 다른 목적으로 이미 싣고 있다.

### 7.4 `--thinking` 은 prefix 마다 다르게 실패한다 — 상태 코드 하나가 아니다

USE-04 와 ROADMAP Phase 12 criterion 2 는 모두 `--thinking` 이 "litellm 에서 400 이 된다"고
평평하게(단일 코드로) 말한다. 실측하면 이건 다섯 개 살아있는 별칭 중 **정확히 하나에만** 맞는
말이다:

- `flashnext` (`openai/` prefix): litellm 자신의 `UnsupportedParamsError` → **HTTP 400**.
- `flashnext-plan` / `flashnext-act` / `flashnext-reach-xhigh` (`hosted_vllm/` prefix): 값이
  litellm 검증은 통과하고, **모델 서버**가 그 값을 거부한다 → **HTTP 500**.
- 래퍼를 거치지 않고 바이너리를 직접 부르는 원시 `cline --thinking high` 는 그 모델 서버의
  500 을 Cline 자신의 오류 이벤트로 표면화하며 **exit 1** 로 끝난다 — 이 경로에서는 400 을
  절대 볼 수 없다.
- 셋 다 생성-큐 슬롯을 소비하지 않는다 — 값 검증이 큐잉보다 먼저 일어난다.

즉 요구사항의 "400" 은 다섯 개 살아있는 별칭 중 딱 하나에만 정확하다. prefix 별로 상태 코드를
따로 적어 두고, 이 부정확함 자체를 명시적으로 짚는다 — 지적되지 않은 부정확한 성공 기준은
바로 이런 식으로 거짓 주장이 마일스톤을 넘어 살아남는 경로다. 측정 원천:
`phase-11/OPEN-ITEMS.md` Open Item 1 (cases 1a/1c).

**CFG-11 전제 정정.** `cline@3.0.53` 시점엔 `--thinking` 이 CLI 에 없다고 믿었다. 지금 설치된
3.0.60+ 에서는 실재하는 플래그(`none|low|medium|high|xhigh`)이고, litellm 이 클라이언트 kwargs 를
`litellm_params` **뒤에** 병합하기 때문에 클라이언트가 보낸 값이 별칭이 주입한
`reasoning_effort` 를 **덮어쓴다**. 이게 정확히 `phase-11/cline-plan`/`cline-act` 가 이 플래그를
무조건 거부하는 이유다 — deny-by-default 근거는 `phase-11/WRAPPER-DESIGN.md` §3/§4.

### 7.5 고정 vs 측정값 — 이 절이 이 문서에서 가장 중요한 단락

**고정** (조용히 드리프트하면 안 되는 값 — §1 의 고정/요구사항/증거 어휘를 그대로 확장):

- 별칭 이름과 그 주입 파라미터 값 — `flashnext-plan` 은 언제나
  `enable_thinking:true` + `reasoning_effort:medium` 을 주입한다.
- `hosted_vllm/` vs `openai/` prefix 선택 — 바꾸면 400 문제가 다시 열린다.
- `providers.json` 의 `model` 과 `contextWindow` — `verify_config.sh` 가 이미 이 둘을 단언한다.

**측정값, 고정 아님** (이미 드리프트했고, 이걸로 아무것도 판단하지 않는다):

- 절대 `prompt_tokens` 오라클 값 — **23/21/51/63 → 13/11/41/53** 로 원인 불명인 채 이동했다
  (`phase-09/PRB-03-ORACLE.md` §5).
- 와이어 `max_tokens` — 과거엔 고정 `2048` 로 기록됐으나, cline 3.0.60/3.0.61 에서 **20983** 으로
  실측됐고, 그 이후 아예 고정값이 아님이 밝혀졌다 — cline 이 요청마다
  `prompt_tokens + max_tokens` 가 `contextWindow × 0.9` 근처에 오도록 완료 예산을 동적으로
  산정한다. 산술 자체는 `docs/cline-max-tokens-findings.md` 와 `docs/32k-compaction-policy.md`
  (plan 12-06 이 동시에 정정 중)를 참조 — **여기서는 링크만 하고 그 산술을 다시 적지 않는다.**

**미래의 드리프트는 절대값이나 파일 해시가 아니라 델타로 판단한다.** `unspecified` 로부터의
델타 — `medium` −2, `low` +28, `xhigh` +40 — 는 서로 몇 주 떨어진 세 번의 독립 측정 라운드에서
비트 단위로 동일하게 유지됐다(`phase-09/PRB-03-ORACLE.md` §2/§5) — 그 사이 절대값은 전부
이동했다. `providers.json` 도 마찬가지로 `model` 과 `contextWindow` 로 판단하고, **sha256 으로
판단하지 않는다** — 그 제약은 이 마일스톤 안에서 이미 한 번 정정됐다, 타임스탬프만 바뀐 재작성이
해시를 바꿔놨을 뿐 정작 중요한 것은 아무것도 바뀌지 않았을 때.

### 7.6 `providers.json` 은 반복적으로 고쳐질 뿐 안정적이지 않다

지금은 `model=flashnext`, `contextWindow=29000` 을 읽는다 — 하지만 이건 **한 시점의
관측이지 고정이 아니다.** 격리되지 않은 `cline -m` 호출은 **호출마다** `model` 을 덮어쓴다
(31/31 실측, 100%) — 2026-09-10 시점에 래퍼들은 이 쓰기를 스크래치 사본으로 리다이렉트하지만,
래퍼 밖에서 실행되는 맨 `cline -m` 은 여전히 공유 파일을 매 호출 때마다 오염시킨다. 이 파일이
"유지된다"거나 "그대로 있다"는 함의를 어디에도 쓰지 않는다 — 이건 이 마일스톤에서 가장 안심되는
쪽으로 완화되어 거짓이 되기 쉬운 성질이라, 여기 명시적으로 못 박는다.

### 7.7 버전 고정과의 상호작용 — 참고, 새 절 아님

§5/§6 은 Phase 1 시절 `cline@3.0.53` 고정과, launchd plist 가 존재하지 않아 공허하게 통과한
`check_versions.sh` 스캔을 기술한다. `cline` 은 그 이후 3.0.53 → 3.0.60 → **3.0.61** 로
드리프트했고 CFG-05(자동 업데이트가 실제로 막혀 있는가)는 여전히 미해결이다. 3.0.53 고정이
지금 지켜지고 있다는 함의는 여기 추가하지 않는다 — "실제 버전을 확인하라"는 경고는 이미
`docs/manual/01-cli.md` §8 이 소유하고 있으므로, 거기를 참조하고 중복 서술하지 않는다.

### 7.8 래퍼 사용법은 여기가 아니다

래퍼 사용법(어떻게 부르는가)은 `docs/manual/01-cli.md` §6a 에 있고, 정확한 래퍼 계약은
`phase-11/WRAPPER-DESIGN.md` 에 있다. 이 문서는 고정값에만 범위를 좁힌다.
