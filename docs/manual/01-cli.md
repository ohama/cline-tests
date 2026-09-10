# 01. CLI 사용법

근거 문서: docs/headless-wrapper.md §2·§3·§4·§6, docs/cline-config-pins.md §2,
docs/manual/04-32k-operations.md.

이 문서는 **사용법**이다 — 왜/어떻게 검증됐는지는 위 근거 문서들을 볼 것, 여기서는 반복하지
않는다. 헤드리스 CLI 로 태스크를 넣고 결과를 읽는 법만 다룬다.

## 1. 기동 — 보통은 아무것도 안 해도 된다

flashnext/litellm/role-shim/kanban/telegram-connect/kanban-proxy 는 전부 launchd 상시
에이전트(`RunAtLoad: true`)다. "오늘 아침 뭘 켜야 하나"의 정상적인 답은 **"아무것도"**다.

확인만 하면 된다:

```
bash phase-05/services/verify_services.sh
```

건강한 결과는 모든 `CHECK` 줄이 `PASS`이고 마지막 요약이 `CASES N/N`(전부 통과)으로 끝나는
것이다. 서비스 전체 그림(무엇이 어디서 도는지)은 `00-getting-started.md` 를 볼 것 —
여기서는 CLI 사용법만 다룬다.

## 2. 태스크 실행 — 실제 명령어

이 프로젝트가 실제로 제공하는 헤드리스 인터페이스는 정확히 하나다:

```
phase-04/run_headless.sh [--out-dir <dir>] [--timeout <secs>] [--] <prompt>
```

서브커맨드도, 다른 옵션도 없다.

**env 노브:**

| 변수 | 의미 | 기본값 |
|---|---|---|
| `HEADLESS_DRY=1` | 오프라인 모드: 실제 `cline` 호출 대신 fixture NDJSON 을 복사 | (미설정 = 라이브) |
| `DRY_FIXTURE=<path>` | `HEADLESS_DRY=1` 일 때 어떤 fixture 를 쓸지 | `phase-04/fixtures/success_no_tools.ndjson` |
| `RESULTS_ROOT=<dir>` | 타임스탬프 결과 디렉터리의 부모 | `phase-04/results` |
| `SKIP_SANDBOX_GATE=1` | Preflight B(`verify_sandbox.sh` 상시 게이트)를 건너뜀 | 미설정 — **오프라인 반복 개발 전용, 라이브 실행에는 절대 쓰지 말 것** |
| `WRAPPER_TIMEOUT=<s>` | `--timeout` 과 동일 효과 | `1800`(`--timeout` 이 있으면 그쪽이 우선) |

**stdout 은 NDJSON 전용이다.** 모든 진단/프리플라이트 출력은 stderr 로만 나간다 — 그래서 파서
뒤에 그대로 파이프해도 안전하다:

```
phase-04/run_headless.sh --timeout 180 "..." | your-parser
```

**결과 디렉터리에 남는 것** (`RESULTS_ROOT/<타임스탬프>-<pid>-headless/`, `--out-dir` 로 오버라이드
가능):

- `ndjson.log` — 실제 stdout 캡처
- `stderr.log` — 진단/프리플라이트 로그
- `cline_exit.txt` — 종료 코드
- `config_pre.txt`/`config_post.txt` — config guard 실행 로그
- `sandbox-gate/` — Preflight B 전체 산출물(`SKIP_SANDBOX_GATE=1` 이 아닌 한)
- `outcome.json`/`outcome.md` — 분류 결과
- `workdir.txt` — cwd 단언 기록

## 3. 결과를 읽는 법

매 실행은 다음 여섯 가지 결과 중 정확히 하나로 판정된다:

| outcome | exit | 운영자가 할 일 |
|---|---|---|
| `success` | `0` | 정상. 도구 실행 성공 여부와 무관하게 이 값이 뜬다 |
| `sandbox_denied` | `2` | 정상(의도된 경계 동작) |
| `tty_approval_rejected` | `3` | **정상, 크래시 아님** — `--auto-approve false` 헤드리스가 도구를 쓰는 프롬프트에 대해 보이는 예상된 동작(4절 참고) |
| `run_aborted` | `4` | 대개 `tty_approval_rejected` 반복 후 자기-중단. 재시도해도 같은 프롬프트라면 같은 결과 |
| `context_overflow_terminal` | `5` | **터미널 실패, 재시도 불가 — 작업을 다시 시작한다.** 자세한 내용은 `docs/manual/04-32k-operations.md` §5 |
| `other` | `6` | 원본 `ndjson.log` 를 직접 조사 |
| `crashed` | `7` | **판정 불가 — 절대 '차단 성공'으로 보고하지 말 것** |

래퍼 자체의 프리플라이트 중단(분류 이전 단계)은 exit `1`이다.

## 4. THE CWD RULE — 작업 디렉터리 규칙

프로세스의 실제 OS 작업 디렉터리(cwd)가 `workspace/ALLOWED_REPOS.json` 의 `repos[]` 안에
**이미** 있어야 샌드박스에 들어가기 전에 안전하다. 그렇지 않으면 Bun/Node 런타임이
부트스트랩 중에 경로 정보 없는 일반 오류로 죽는다 — 겉보기엔 샌드박스가 더 엄격해진 것처럼
보이지만 실제로는 아니다.

**`cline -c/--cwd` 는 별개의, 추가 플래그다 — 진짜 프로세스 cwd 를 대신하지 않는다.** 실제
`cd`(또는 그에 준하는 프로세스 cwd 변경)를 먼저 해야 한다.

## 5. ⚠️ [GAP-READONLY] 읽기·대화 전용이다

이 프로젝트가 실제로 제공하는 표면은 `--no-tools`(telegram)와 `--auto-approve false`(헤드리스
래퍼) 두 가지뿐이다. 3.0.53 헤드리스에서 `--auto-approve false` 는 도구를 쓰는 모든 호출을
거부한다(`tty_approval_rejected`, exit 3) — 이건 예상된 동작이지, 크래시가 아니다.

사용자에게 실질적으로 의미하는 바: **읽기·대화 전용이며, 원격에서 트리거된 에이전트는 파일을
수정할 수 없다.** 이 태세를 뒤집는 것은 사람이 명시적으로 내려야 하는 보안 결정이다
(`docs/headless-wrapper.md` §4·§8) — 이 매뉴얼은 누구에게도 플래그를 뒤집으라고 말하지 않는다.

## 6. Plan/Act

**두 플래그, 두 세대의 증거 — 어느 쪽이 이겼는지 적어 둔다.** Phase 8 은 3.0.53 바이너리를
`strings` 로 정적 스캔해서 `--mode <act|plan>`(기본값 `act`)을 찾았다 — 이 플래그를 **실제로
실행해서 확인한 적은 없다.** Phase 11 은 설치된 3.0.61 바이너리를 **실제로 실행해서** `-p`/
`--plan` 을 확인했고, 6a절의 `phase-11/cline-plan` 이 매 호출마다 쓰는 것도 바로 이 `-p` 다.

**라이브 실행이 정적 문자열 스캔을 이긴다 — 둘이 어긋나면 실제로 돌려본 쪽을 믿을 것.** 이건
이 플래그 하나에만 해당하는 얘기가 아니다 — 이 프로젝트는 난독화된 바이너리를 정적 스캔해서
내린 결론을 실측으로 뒤집은 적이 이미 있다(qanda/004 문서 자신의 자기정정). `--mode` 와 `-p`/
`--plan` 이 같은 기능의 다른 이름인지, 아니면 `--mode` 가 죽었거나 등록되지 않은 코드인지는
**확인되지 않았다** — 짐작하지 않고 그렇게 남긴다. 두 플래그 이름을 모두 여기 적어 두는 건,
나중에 Phase 8 의 인용과 이 매뉴얼을 대조하려는 사람이 실마리를 찾게 하기 위해서다. (`cline-src`
작업 트리는 이제 `cli-v3.0.61` 로 옮겨갔으므로, 3.0.53 시절 코드를 다시 보려면
`git show cli-v3.0.53:<path>` 형태로만 가능하다.)

내부 5-모드 tool-permission 표는 act 와 plan 이 `enableEditor` 값 하나만 다르다.

**⚠️ [GAP-PLANMODE]** 이 프로젝트가 실제로 쓰는 헤드리스 원샷 커맨드가 `--mode` 를 그대로
지원하는지는 **미확인**이다 — 정적 분석(바이너리 `strings` 스캔)의 한계이며, 이걸 확인하려고
`cline` 을 직접 실행하지는 않았다. 이 프로젝트의 헤드리스 호출은 지금까지 `--mode` 를 한 번도
넘긴 적이 없으므로, 지금까지의 모든 실행은 기본값인 act 모드였다. **Plan 모드는 이 프로젝트에서
한 번도 실행된 적이 없다.** Plan 모드가 헤드리스에서 작동한다고도, 작동하지 않는다고도 쓰지
않는다 — 둘 다 확인된 적이 없다.

**이 GAP 은 6a절의 래퍼를 해소하지 않는다 — 둘은 다른 도구다.** GAP-PLANMODE 는
`phase-04/run_headless.sh`(이 프로젝트가 쓰는 헤드리스 원샷 경로) 에 대한 것이고, 그 경로는
지금도 act 모드 전용이며 `--mode` 질문은 그대로 미해결이다. 6a절의 `phase-11/cline-plan`/
`cline-act` 는 **대화형 모양**의 별개 래퍼로, `-p` + `-m <별칭>` 조합을 쓴다 — 이 둘을 같은
것으로 섞지 말 것.

## 6a. `cline-plan` / `cline-act` — 래퍼 사용법

지금 이 프로젝트가 실제로 갖고 있는 **두 번째** 헤드리스 표면이다. 위 2절의
`phase-04/run_headless.sh` 와는 **다른 도구** 다 — 바로 위 문단에서 밝힌 대로 섞지 말 것.

### 무엇이고 어떻게 부르나

`phase-11/cline-plan`, `phase-11/cline-act` 는 실제 `cline` 바이너리를 감싸는 셸 스크립트다.
**둘 다 `$PATH` 에 설치돼 있지 않고 심볼릭 링크도 없다** — 경로를 명시해서 불러야 한다:

```
phase-11/cline-plan [-t|--timeout <secs>] [-c|--cwd <path>] [--json] [--] <prompt...>
phase-11/cline-act  [-t|--timeout <secs>] [-c|--cwd <path>] [--json] [--] <prompt...>
```

`cline-plan` 은 항상 `-p -m flashnext-plan` 을 붙여 Plan 모드로 실행하고, `cline-act` 는
`-p` 없이 `-m flashnext-act` 를 붙여 Act 모드로 실행한다. 모드와 별칭은 단 하나의 construction
site 에서 짝지어지고 따로는 바꿀 수 없다 — 그 짝을 강제하는 것이 이 래퍼가 존재하는 이유다
(`phase-11/WRAPPER-DESIGN.md` §1).

### 받는 인자 — 화이트리스트, 차단 목록이 아니다

정확히 네 가지만 통과한다: `-t`/`--timeout`, `-c`/`--cwd`, `--json`, `--`. **`-` 로 시작하는
그 외 모든 인자는 실제 바이너리를 부르기도 전에 이름을 대며 stderr 에 거부되고 exit 2 로
끝난다.** 이건 차단 목록이 아니라 **기본 거부(deny-by-default)** 다 — 오늘 이 프로젝트가
모르는, 내일 cline 에 새로 생길 플래그도 자동으로 막힌다는 뜻이다(CFG-05: cline 자동
업데이트가 실제로는 막히지 않는다는 위험을 이렇게 상쇄한다).

`-m`, `-P`, `--thinking`, `-p` 네 개는 각각 이유가 적힌 전용 거부문을 받는다. 예를 들어
`--thinking` 을 치면(`phase-11/wrapper_common.sh` 원문 그대로, 바꿔 쓰지 않음):

```
REFUSED: cline-plan does not accept '--thinking'. Reasoning effort is injected server-side by
the litellm alias. litellm merges client kwargs AFTER the alias's litellm_params
(phase-10/ALIAS-DESIGN.md §3), so a client-sent reasoning_effort OVERRIDES the alias — using
--thinking silently bypasses this wrapper's guarantee. See .planning/REQUIREMENTS.md CFG-11,
2026-09-02 correction.
```

### 종료 코드 — 이 절이 제일 많이 오해된다

| 종료 코드 | 뜻 |
|---|---|
| `0..N` | `cline` 자신의 종료 코드, 그대로 전달 |
| `2` | 인자 거부. **실제 바이너리는 호출되지 않았다** |
| `3` | 실행 전 설정 가드 실패, 또는 `providers.json` 스크래치 복사본 격리 자체가 실패. **실제 바이너리는 호출되지 않았다** |
| `4` | 실행 후 설정 가드 실패. **`cline` 자신은 exit 0 이고 답도 맞을 수 있다** — 이 코드는 "설정이 오염됐다, `apply_provider_config.sh` 를 다시 돌려라" 는 신호일 뿐, 작업이 실패했다는 뜻이 아니다 |

🔴 **exit 4 를 작업 실패로 읽지 말 것.** `cline` 은 정상 종료(exit 0)했고 답도 맞았을 수
있다 — 4 는 설정 드리프트 신호일 뿐이다.

**2026-09-10 현재, 정상 사용에서는 exit 4 가 더 이상 나오지 않아야 한다** — 아래 격리
(containment) 가 쓰기 자체를 스크래치 복사본으로 돌리기 때문이다. 그렇다고 실행 후 가드를
지우지는 않았다 — 격리가 실제로 걸렸다는 것을 매 호출마다 재확인하는 assertion 으로 남겨
둔다.

### `providers.json` 격리 — 정확히 말하면

`cline -m` 호출은 **호출마다** `~/.cline/data/settings/providers.json` 의 `model` 필드를
덮어쓴다 — cline 자신의 시작 경로에 무조건 들어 있는 동작이고 최소 3.0.53 부터 그렇다. Phase
11 의 A/B 에서 31/31, 100% 로 측정됐다. 래퍼는 이 쓰기를 **격리한다**: 매 호출마다 실제
파일을 `mktemp` 로 복사하고 `CLINE_PROVIDER_SETTINGS_PATH` 를 그 복사본으로 맞춘 뒤 `EXIT`/
`INT`/`TERM` 에 삭제를 걸어, 쓰기가 복사본에만 떨어지고 Kanban·Telegram 이 함께 읽는 공유
파일은 건드리지 않게 한다. 스크래치 복사본을 만들 수 없으면 격리 없이 실행하는 대신 exit 3
으로 거부한다.

**"격리한다"라고만 쓴다 — 이 부작용이 없어졌다는 말은 쓰지 않는다.** 근본 쓰기 자체는
소스에서 사라지지 않았다 — 래퍼 밖에서 맨손 `cline -m` 을 부르면 지금도 공유 파일을 바꾼다.
이 격리는 커밋 `017c65e`(2026-09-10, 오늘) 로 들어왔고, 하루도 안 된 코드로 실사용 이력이
없다.

### 래퍼가 일부러 안 하는 것

`phase-11/WRAPPER-DESIGN.md` §7 이 정직하게 적어 둔 한계: `-` 로 시작하는 프롬프트는
무조건 거부된다(우회 수단 없음 — 다시 써야 한다); `--auto-approve`, `--hooks-dir`,
`-s/--system`, `--zen`, `--tui`, `--acp`, `--worktree`, `--retries`, `--kanban`, `--update`,
`--data-dir`, `--config`, `-k/--key`, `-v/--verbose` 등 실제 `cline` 플래그 약 15개는 이
래퍼로는 도달할 수 없게 설계돼 있다; 설정 가드는 **중단만 하고 스스로 고치지 않는다**
(자동 치유는 `phase-04/run_headless.sh` 의 무인 표면 정책이며, 이 대화형 래퍼의 정책은
아니다). 정확한 주장은 "넓고 확장 가능한 위험 인자 부류를 거부하고, 소스에서 막지 못하는
유일한 부작용을 격리한다" 이지, "오용이 불가능해졌다" 가 아니다.

### `cline-plan` 이 가리키는 별칭, 그리고 왜 그대로인가

`cline-plan` 은 `flashnext-plan`(`enable_thinking:true` + `reasoning_effort:medium`)을
가리키고, 이번 마일스톤에서 **되돌리지 않고 그대로 유지(keep)** 됐다.

🔴 **이유를 정확히 읽을 것 — A/B 가 이 별칭을 더 낫다고 판정해서가 아니다.** 두 arm 모두
같은 반복수로 시도한 과제들에서 arm A(사고 끔) 25/30, arm C(`medium`) 25/30 — 정확도
차이가 전혀 없었다(permutation test p=0.563). 사전 등록된 규칙의 산출은 `revert` 였다.
사람이 그 산출을 **override** 해서 `keep` 으로 결정했다 — 근거는 정확도가 아니라, 위
`providers.json` 부작용이 마침 격리 가능해졌다는 안전 사유였다. 근거:
`phase-11/AB-RESULTS.md` §11.

### 더 볼 곳

- 실제 `cline` 버전 확인법은 이 문서 8절(GAP-CLINE-VERSION) 을 볼 것 — 여기서 되풀이하지
  않는다.
- 별칭이 주입하는 정확한 파라미터 값은 `docs/cline-config-pins.md` 를 볼 것.
- 위 계약의 전문은 `phase-11/WRAPPER-DESIGN.md` 를 볼 것 — 이 절은 그 계약을 인용할 뿐,
  다시 서술하지 않는다.

## 7. 체크포인트 — 두 가지가 있고 서로 다르다

**⚠️ [GAP-CHECKPOINT-CLINE]** cline 자신은 세션 단위 파일 체크포인팅을 갖고 있다
(`createCheckpoint`/`restoreCheckpoint`, `cline-checkpoint-` git-ref 접두사 — `--id` 세션
재개와 같은 레이어). 이 근거도 정적 문자열 스캔뿐이다 — 실제로 언제 발동하는지, 헤드리스에서도
켜지는지는 검증되지 않았다.

이것과는 **다른** 또 하나의 체크포인트가 있다: kanban 의 태스크 단위 working-tree 커밋
(`createWorkingTreeCheckpointCommit`)이다. 이건 02-kanban.md 의 소관이다 — 두 개념을 섞지
말 것.

## 8. ⚠️ [GAP-CLINE-VERSION] 버전을 반드시 확인할 것

호스트 `cline` 은 핀 `3.0.53` 에서 `3.0.60` 으로 드리프트됐다 — `CLINE_NO_AUTO_UPDATE=1` 이
있어도 막지 못했다. 이 문서의 버전 종속적인 내용(예: 6·7절의 CLI 플래그 표면)을 신뢰하기 전에
실제 버전을 확인할 것.

확인하는 법:

```
cat /opt/homebrew/lib/node_modules/cline/package.json | grep '"version"'
```

`cline --version` 으로 확인하지 말 것 — 바이너리를 호출하는 행위 자체가 드리프트를 유발하는
트리거다. `phase-01/config/check_versions.sh` 로도 확인하지 말 것 — 그 스크립트의 Check B 가
호스트 바이너리를 직접 호출한다. 이 문서 어디에도 핀(3.0.53)을 현재 사실로 적지 않는다 —
지금 실제 버전은 위 명령으로 매번 직접 확인해야 한다.

## 9. 긴 세션에서 무슨 일이 생기나

프리필 대기(~64초, 멈춤 아님), 자동 압축과 그때의 추가 지연, 그리고 복구 불가능한 서버 400
(터미널 실패, 재시도하지 말고 새로 시작)은 전부 `docs/manual/04-32k-operations.md` 에서
자세히 다룬다 — 여기서는 되풀이하지 않는다.

---
*근거: docs/headless-wrapper.md, docs/cline-config-pins.md, docs/manual/04-32k-operations.md*
