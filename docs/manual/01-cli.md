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

`--mode <act|plan>`(기본값 `act`)은 설치된 바이너리 안에 실재하는 CLI 옵션이며, 내부 5-모드
tool-permission 표는 act 와 plan 이 `enableEditor` 값 하나만 다르다.

**⚠️ [GAP-PLANMODE]** 이 프로젝트가 실제로 쓰는 헤드리스 원샷 커맨드가 `--mode` 를 그대로
지원하는지는 **미확인**이다 — 정적 분석(바이너리 `strings` 스캔)의 한계이며, 이걸 확인하려고
`cline` 을 직접 실행하지는 않았다. 이 프로젝트의 헤드리스 호출은 지금까지 `--mode` 를 한 번도
넘긴 적이 없으므로, 지금까지의 모든 실행은 기본값인 act 모드였다. **Plan 모드는 이 프로젝트에서
한 번도 실행된 적이 없다.** Plan 모드가 헤드리스에서 작동한다고도, 작동하지 않는다고도 쓰지
않는다 — 둘 다 확인된 적이 없다.

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
