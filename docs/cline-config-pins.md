# Cline 설정 고정 (CFG-04, CFG-05, CFG-06)

이 문서는 Phase 1 이 고정한 네 가지 값 — `cline` 버전, `kanban` 버전, 압축(compaction) 모드,
모델 — 의 근거와 증거를 기록한다. 나중에 뭔가 어긋났을 때 제일 먼저 볼 문서다.

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
