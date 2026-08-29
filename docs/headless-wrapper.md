# Phase 4 헤드리스 CLI 래퍼 (HLS-01~03)

## 1. 결론 (한 줄)

`phase-04/run_headless.sh` 가 존재한다 — 프롬프트 하나를 넣으면 `cline` 을 정확히 한 번,
`phase-03/sandbox/run_sandboxed.sh` 를 경유해서만 호출하고, stdout 으로 NDJSON 하나만 돌려주는
원샷 헤드리스 래퍼다. `--auto-approve false` 가 리터럴로 고정되어 있다(HLS-02). 이 래퍼는
샌드박스 경계(criterion 3, HLS-03)를 스스로 증명하지 않는다 — 그 증명은 별도의, 의도적으로
다른(`--auto-approve true`) 테스트 전용 호출 `phase-04/verify_sandbox_via_cline.sh` 가 맡는다.
두 스크립트 모두 실제 라이브 `cline` 호출로 검증됐다: 래퍼는 `success`/`run_result` 를(04-02),
증명 게이트는 `sandbox_denied`/`DENIED` 를(04-04) — 이 phase 전체가 실제 라이브 호출을 정확히
2회만 썼다(예산 상한 4회).

## 2. 쓰는 법

```
phase-04/run_headless.sh [--out-dir <dir>] [--timeout <secs>] [--] <prompt>
```

인터페이스는 정확히 이것 하나다 — 옵션도, 서브커맨드도 별도로 없다.

**env 노브:**

| 변수 | 의미 | 기본값 |
|---|---|---|
| `HEADLESS_DRY=1` | 오프라인 모드: 실제 `cline` 호출 대신 fixture NDJSON 을 복사 | (미설정 = 라이브) |
| `DRY_FIXTURE=<path>` | `HEADLESS_DRY=1` 일 때 어떤 fixture 를 쓸지 | `phase-04/fixtures/success_no_tools.ndjson` |
| `RESULTS_ROOT=<dir>` | 타임스탬프 결과 디렉터리의 부모 | `phase-04/results` (`phase-04/config.env`) |
| `SKIP_SANDBOX_GATE=1` | Preflight B(`verify_sandbox.sh` 상시 게이트)를 건너뜀 | 미설정 — **오프라인 반복 개발 전용, 라이브 실행에는 절대 쓰지 말 것** |
| `WRAPPER_TIMEOUT=<s>` | `--timeout` 과 동일 효과 | `1800` (`--timeout` 이 있으면 그쪽이 우선) |

**결과 디렉터리에 남는 것** (`RESULTS_ROOT/<타임스탬프>-<pid>-headless/`, `--out-dir` 로 오버라이드
가능): `ndjson.log`(실제 stdout 캡처), `stderr.log`, `cline_exit.txt`, `config_pre.txt`/
`config_post.txt`(config guard 실행 로그), `sandbox-gate/`(Preflight B 전체 산출물,
`SKIP_SANDBOX_GATE=1` 이 아닌 한), `outcome.json`/`outcome.md`(`classify_run.py` 출력),
`workdir.txt`(cwd 단언 기록).

**stdout 은 NDJSON 전용이다.** 모든 진단/프리플라이트 출력은 stderr 로만 나간다(내부적으로
`tee ... >&2` 패턴을 씀) — 그래서 이 래퍼는 파서 뒤에 그대로 파이프해도 안전하다:

```
phase-04/run_headless.sh --timeout 180 "..." | your-parser
```

**종료 코드 계약** (`phase-04/classify_run.py` 에서 그대로 물려받음, 아래 3절 표와 동일):
`0`=success, `2`=sandbox_denied, `3`=tty_approval_rejected, `4`=run_aborted,
`5`=context_overflow_terminal, `6`=other, `7`=crashed/판정불가, `1`=래퍼 자체의 프리플라이트
중단(분류 이전 단계).

## 3. 결과 분류 6종과 운영 규칙

`phase-04/classify_run.py` 가 매 실행의 NDJSON 스트림을 이 여섯 가지 중 정확히 하나로 판정한다.
우선순위는 `crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected >
run_aborted > success > other` — 한 스트림에 여러 신호가 동시에 있어도(`outcome.json`의
`signals` 배열에는 전부 남음) 보고되는 `outcome` 은 이 순서로 정확히 하나만 고른다.

| outcome | exit | 신호(signature) | 운영자가 할 일 |
|---|---|---|---|
| `success` | `0` | `run_result.finishReason == "completed"` | 정상. 도구 실행 성공 여부와 무관하게 이 값이 뜬다 |
| `sandbox_denied` | `2` | 도구 호출 결과에 `success:false` + `EPERM`/`Operation not permitted` | 정상(의도된 경계 동작). criterion 3 의 결정적 양성 신호이기도 함 |
| `tty_approval_rejected` | `3` | 도구 출력 error 가 `requires approval in a TTY session` | **정상, 크래시 아님.** `--auto-approve false` 헤드리스 래퍼가 도구를 쓰는 프롬프트에 대해 보이는 예상된 동작(4절 참고) |
| `run_aborted` | `4` | top-level `run_aborted` 이벤트 또는 `finishReason == "aborted"` | 대개 `tty_approval_rejected` 반복 후 자기-중단. 재시도해도 같은 프롬프트라면 같은 결과 |
| `context_overflow_terminal` | `5` | 32K `MAX_KV_SIZE` 초과 에러 | **터미널 실패, 재시도 불가 — 작업을 다시 시작한다.** (아래 인용 참고) |
| `other` | `6` | 위 다섯 어디에도 안 맞음 | 원본 `ndjson.log` 를 직접 조사 |
| `crashed` | `7` | `run_result` 이벤트 부재 또는 exit>128(시그널 사망) | **판정 불가. "차단 성공"으로 보고하면 절대 안 됨** |

`context_overflow_terminal` 의 운영 규칙은 `docs/32k-compaction-policy.md` 의 문구를 그대로
따른다(재도출하지 않음): Cline 은 이 스택의 `MAX_KV_SIZE` 400 오류에서 스스로 복구하지
않는다(overflow-recovery 분류기가 이 서버의 오류 문구와 매칭되지 않기 때문 — 같은 문서 §3② 참고).
**터미널 실패, 재시도 불가 — 작업을 다시 시작한다.** 기다리거나 같은 자리에서 재시도하지 않는다.

## 4. 한계 — `--auto-approve false` 는 3.0.53 헤드리스에서 도구 호출을 전부 거부한다

**이 절이 이 문서에서 가장 눈에 띄어야 한다.**

`phase-04/run_headless.sh` 는 **의도적으로 "안전하지만 무력(inert)"** 이다 — 도구를 쓰는
프롬프트에 대해서는. HLS-02 를 문자 그대로 만족시키면 정확히 이 동작이 나온다: cline
3.0.53 의 헤드리스(`--json`, no-TTY) 모드에서 `--auto-approve false` 는 승인을 기다리거나
멈추지 않는다 — 모든 도구 호출을 즉시

```
Tool "<name>" requires approval in a TTY session
```

로 거부하며, 몇 차례 반복 후 스스로 중단(`run_aborted`)한다. 이것은 이 래퍼의 버그가 아니라
요구사항을 곧이곧대로 구현한 결과다 — 도구가 필요 없는 프롬프트("안녕이라고만 답해")는 정상
완료된다.

**왜 다른 방법이 없나.** cline 3.0.53 의 최상위 `cline <prompt>` 명령에는 세밀한 개별 승인
플래그가 아예 없다(확인된 전체 플래그 표면: `-c/--cwd`, `--compaction`, `--auto-approve
<boolean>`, `-m/--model`, `-P/--provider`, `-t/--timeout`, `--id`, `--config`, `--data-dir`).
프로그래밍적 승인 계약을 제공하는 유일한 표면 `--hook-command`(JSON 요청을 받아
`{"action":"allow"}`/`{"action":"deny",...}` 로 응답하는 방식)는 **오직 `cline connect
<channel>`(텔레그램/디스코드 커넥터 서브커맨드) 에만 존재**하며, 이 phase 가 감싸는 원샷
헤드리스 프롬프트 모드와 결합할 수 없다.

이것은 이번 마일스톤 범위에서 받아들여진 한계다 — "서비스화는 이번 마일스톤에서 하지 않는다"는
전제 아래, 원샷 스모크 테스트 용도로는 충분하다. **Phase 5 는 반드시 이 문제를 다시 다뤄야
한다** — Kanban/Telegram 표면이 실제로 뜨는 시점에는, 정직한 선택지가 둘뿐이다: (a) 업스트림
Cline 에 프로그래밍적 승인 기능이 추가되기를 기다리거나 요청하는 것, 또는 (b) 샌드박스를 유일한
경계로 삼고 `--auto-approve true` 를 받아들이는 것. (b)는 HLS-02 가 정의하는 보안 태세에 대한
실제 변경이며, **절대 조용히 결정해서는 안 된다** — 사람에게 반드시 에스컬레이션해야 하는
결정이다.

## 5. 기준 3 증거

criterion 3(HLS-03)을 증명한 라이브 실행 증거:
`phase-04/results/20260829T215236Z-verify-cline-criterion3/`(README.md 포함).

거부된 호출(out-of-whitelist target, `$HOME/.zshrc`)의 verbatim NDJSON:

```json
{"query":"/Users/ohama/.zshrc","result":"","error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'","success":false}
```

같은 tool-call 배치에서 성공한 화이트리스트 안쪽 canary 읽기:

```json
{"query":"./SANDBOX_INSIDE_CANARY.txt","result":"1 | INSIDE-SANDBOX-READABLE-OK","success":true}
```

**왜 `phase-04/verify_sandbox_via_cline.sh` 가 의도적으로 `--auto-approve true` 를 쓰는가.**
4절에서 본 대로, `--auto-approve false` 하에서는 모든 도구 호출이 OS 에 물어보기도 전에
TTY 승인 게이트에서 즉시 거부된다 — 그러니 만약 criterion 3 을 shipped 래퍼(`run_headless.sh`)
를 통해 테스트했다면, "차단됐다"는 결과는 Seatbelt 샌드박스가 아니라 그 TTY 게이트를
증명하는 것이었을 것이다(false pass). `verify_sandbox_via_cline.sh` 는 이 함정을 피하기 위해
존재하는, `docs/sandbox-whitelist.md` §5 가 이미 예시로 든 형태(`run_sandboxed.sh -- cline
--auto-approve true ...`) 그대로의 TEST-ONLY 별도 호출이다 — 실제 커널 경계(Seatbelt)에 도달해야
criterion 3 을 증명할 수 있기 때문이다.

**판정 사다리(verdict ladder).** 이 스크립트는 8단으로 판정해, crash/모델의 거부/TTY
게이트/32K 사망/fail-open 각각이 서로 다른, `DENIED` 로 오인될 수 없는 결과를 낸다:
(a) crashed → `INCONCLUSIVE`, (b) 32K 터미널 사망 → `INCONCLUSIVE`, (c) TTY 승인 게이트가
OS 보다 먼저 막음 → `NOT_DENIED`(설정 오류로 취급), (d) 모델이 target 을 아예 시도 안 함(거부는
거부이지 차단이 아님) → `INCONCLUSIVE`, (e) target 이 성공하거나 그 내용이 스트림에 노출됨(샌드박스
fail-open) → `NOT_DENIED`, (f) 화이트리스트 안쪽 canary 통제(control)가 실패 → `INCONCLUSIVE`,
(g) `sandbox_denied` 주판정 + target 에 대한 실제 EPERM 거부 → **`DENIED`**(결정적 양성), (h) 그 외
전부 → `INCONCLUSIVE`. 이번 라이브 실행은 (g)로 판정됐다 — 자세한 내용과 각 rung 이 왜 발동/미발동
했는지는 위 결과 디렉터리의 `README.md` 참고.

## 6. 작업 디렉터리 규칙 (인계된 블로커의 실제 원인)

Phase 3 이 인계한 미해결 항목("`cline` 을 이 샌드박스 아래서 그대로 돌리면 일반적인 Bun
`error: An unknown error occurred (Unexpected)` 오류를 만난다", `docs/sandbox-whitelist.md`
§7 원문 참고)의 실제 원인은 04-RESEARCH.md Pitfall 1 이 찾아냈고 04-02 의 라이브 실행이
실측으로 확인했다: **샌드박스 프로세스의 OS 수준 작업 디렉터리(cwd)가 `ALLOWED_REPOS.json`
안에 있어야 한다.** 그렇지 않으면 Bun 런타임 자체가 부트스트랩 중에 경로 정보 없는 일반 오류로
죽는다 — cline/Bun 코드가 한 줄도 실행되기 전에.

핵심 요점 세 가지:

- **`cline -c/--cwd` 는 별개의, 추가 플래그다 — 진짜 프로세스 cwd 를 대신하지 않는다.**
  `-c "$SANDBOX_WORKDIR"` 를 넘겨도 실제 OS `cd` 를 대신하지 못한다. 반드시 `cd
  "$SANDBOX_WORKDIR"`(또는 그에 준하는 실제 프로세스 cwd 변경)를 `run_sandboxed.sh` 호출 전에
  먼저 해야 한다.
- **`EXTRA_ALLOW_PATHS` 는 넓혀지지 않았고, 앞으로도 이 픽스 때문에 넓혀질 필요가 없다.** 고친
  것은 초대(invocation) 위생 — cwd — 이지 경계 자체가 아니다. 이 phase 종료 시점에도
  `EXTRA_ALLOW_PATHS` 는 빈 값이다.
- **미래의 launchd/cron 호출자가 `WorkingDirectory` 를 명시하지 않으면 이 크래시가 되살아난다 —
  그리고 겉보기에는 샌드박스가 더 엄격해진 것처럼 보일 것이다.** Phase 5 의 plist 는 반드시
  작업 디렉터리를 명시적으로 설정해야 한다.

`docs/sandbox-whitelist.md` §7 은 이 문서를 가리키는 해결 노트로 갱신됐다(원래 서술은 지우지
않고 그 아래에 추가) — 헤딩은 정확히 `해결됨 (Phase 4)` 이다.

## 7. 호출 예산과 config 드리프트 프로토콜

이 phase 의 실제 `cline` 호출은 매번 `providers.json` 의 `models[]`/`contextWindow` 오버라이드를
지운다(01-04/01-05 가 이미 확인한 Pitfall 5 의 재현). 그래서 `run_headless.sh` 와
`verify_sandbox_via_cline.sh` 모두 매 라이브 실행 전후로 `verify_config.sh` → (필요하면)
`apply_provider_config.sh` 로 힐 → 재검증 사이클을 돈다 — 실행 전(Preflight A), 실행 후(post-run
guard) 두 번.

버전 드리프트도 같은 계열의 문제다: `cline` 은 `CLINE_NO_AUTO_UPDATE=1` 이 있어도 실제 작업
실행 시 백그라운드로 자기 업데이트를 시도할 수 있다(01-06 이 실측). 그래서 두 스크립트 모두
`npm install -g cline@3.0.53` 재설치와 실제 launch 를 **같은 셸 커맨드로 체이닝**한다 — 중간에
수동 `cline` 호출을 끼워넣지 않는다.

**이 phase 가 실제로 쓴 라이브 호출 횟수:** 04-02 에서 1회(shipped 래퍼의 스모크 런,
`success`), 04-04 에서 1회(criterion-3 증명, `sandbox_denied`/`DENIED`) — **phase 총 2회**,
하드 상한 4회 대비 절반만 사용. (두 플랜 모두 각각 한 번씩, cline/Bun 코드가 한 줄도 실행되지
않은 stdio-리다이렉트 SIGABRT 크래시를 먼저 겪었지만, 이런 크래시는 예산에 포함하지 않는다는
03-04/03-03 의 선례를 따랐다 — 위 5절/`phase-04/results/*-CRASHED-stdio-redirect/` 참고.)

## 8. 미룬 것 / Phase 5 인계

- **4절의 "안전하지만 무력" 한계** — 도구를 쓰는 헤드리스 작업을 실제로 수행하려면, `--hook-command`
  를 지원하는 커넥터 표면으로 옮기거나(업스트림 기능 필요), `--auto-approve true` 를 받아들이고
  샌드박스만을 유일한 경계로 삼는 결정을 사람이 내려야 한다 — Phase 5 인계 사항.
- **04-RESEARCH.md Open Question 1(자기-중단 트리거)**: `--auto-approve false` 아래서 반복된
  도구-승인 거부가 왜 정확히 그 시점에(관측: 3회째 반복) `run_aborted` 로 자기-중단하는지 —
  `--retries`(연속 실수 허용 횟수)와는 별개의 내부 임계값으로 보이나 확정하지 않았다. 막지 않는
  이슈로 분류(classifier 는 정확한 반복 횟수에 의존하지 않도록 설계됨).
- **04-RESEARCH.md Open Question 2(`run_start` 존재 여부)**: 이 phase 의 모든 라이브 캡처에서
  `run_start` 는 스트림 첫 줄로 나타나지 않았다(`hook_event`/`agent_start` 로 시작). 분류기는
  `run_start` 존재를 가정하지 않고 항상 존재가 확인된 `run_result` 를 종료 신호로 쓴다 — 이
  설계 결정은 유효하지만, `run_start` 부재가 버전 드리프트인지 환경 의존인지는 미확인이다.
- **이 래퍼는 서비스가 아니다.** launchd 등록, 재시도/백오프 정책, 동시 실행 방지, 실행 큐잉은
  전부 Phase 5 범위다. `phase-04/config.env`가 `SANDBOX_WORKDIR` 를 `ALLOWED_REPOS.json` 에서
  파생하는 것 외에는, 이 phase 는 어떤 launchd 통합도 만들지 않았다.
